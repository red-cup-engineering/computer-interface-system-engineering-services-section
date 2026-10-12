// collision — the engine's COLLISION against the voxel grid: a moving body (the player, a unit) is a
// point with a radius on the floor plane, and the world's solid voxels are unit cells. A move is tried
// per-axis (the classic slide-along-walls resolution) so a body grazing a wall slides instead of
// sticking. Pure: collision takes a grid + a body + a desired delta and returns the resolved position,
// appending nothing and reading no clock.
//
// THE BILATTICE, in collision: which voxels BLOCK is itself a four-valued reading, and the engine
// honors all four —
//   t   (solid wall)     : blocks. You cannot walk through a settled wall.
//   ⊤   (contested wall) : ALSO blocks — both witnesses say solid, so the body stops on it (and the
//                          raycaster draws it shivering). The contradiction is a designed obstacle, not
//                          a pass-through. (A game MAY override this — see `passContested` — to make a
//                          contested wall a phase-through mechanic; the default is HOLD: it blocks.)
//   f   (carved/denied)  : PASSES — a denied wall was opened; the body walks through.
//   ⊥   (un-scanned fog) : PASSES — no evidence of a wall, so nothing to collide with (you may walk into
//                          the unknown; the renderer fogs it, collision lets you through).
// So solidity for collision is exactly: t OR ⊤ blocks; f and ⊥ pass — the same predicate the raycaster
// uses to STOP a ray, kept in one place so render and walk agree.

import { FOUR } from "./grid.mjs";

// blocks(reading, opts) — does a voxel of this reading stop a body? t and ⊤ block (⊤ unless the game opts
// into pass-through); f and ⊥ pass.
export function blocks(reading, opts = {}) {
  if (reading === FOUR.T) return true;
  if (reading === FOUR.TOP) return opts.passContested ? false : true;
  return false; // f (carved) and ⊥ (fog) are passable
}

// solidAround(g, x, z, radius, opts) — is any voxel within `radius` of point (x,z) blocking? Tests the
// cells the body's bounding box overlaps. Used to validate a candidate position.
export function occupied(g, x, z, radius, opts = {}) {
  const minX = Math.floor(x - radius), maxX = Math.floor(x + radius);
  const minZ = Math.floor(z - radius), maxZ = Math.floor(z + radius);
  for (let cz = minZ; cz <= maxZ; cz++) {
    for (let cx = minX; cx <= maxX; cx++) {
      if (blocks(g.at(cx, cz).reading, opts)) return true;
    }
  }
  return false;
}

// move(g, body, dx, dz, opts) — try to move `body` ({ x, z, radius }) by (dx,dz) against grid `g`,
// resolving PER AXIS so the body slides along a wall it grazes. Returns a NEW body { x, z, radius } at
// the resolved position plus a `hit` summary { x, z } (which axes were blocked). Pure — never mutates
// the input body, appends nothing.
export function move(g, body, dx, dz, opts = {}) {
  const radius = body.radius ?? 0.2;
  let x = body.x, z = body.z;
  const hit = { x: false, z: false };

  // try the x move first; if the new x would overlap a blocking voxel, cancel just the x component.
  const nx = x + dx;
  if (!occupied(g, nx, z, radius, opts)) x = nx;
  else hit.x = true;

  // then the z move against the (possibly updated) x — this gives the slide.
  const nz = z + dz;
  if (!occupied(g, x, nz, radius, opts)) z = nz;
  else hit.z = true;

  return { body: { ...body, x, z, radius }, hit };
}

// raycastFloorHit(g, body, dirx, dirz, maxDist, opts) — march a body forward and report the distance to
// the first blocking voxel along a heading (a forward "feeler", e.g. for a unit's AI or a melee reach).
// A small sampling march, not the full DDA — collision wants "is the path ahead clear for d cells", not
// a rendered slice.
export function clearAhead(g, body, dirx, dirz, maxDist, opts = {}) {
  const radius = body.radius ?? 0.2;
  const stepLen = 0.25;
  let traveled = 0;
  let x = body.x, z = body.z;
  while (traveled < maxDist) {
    x += dirx * stepLen; z += dirz * stepLen; traveled += stepLen;
    if (occupied(g, x, z, radius, opts)) return traveled;
  }
  return maxDist;
}
