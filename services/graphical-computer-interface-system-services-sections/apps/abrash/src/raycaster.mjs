// raycaster — the engine's software 3D renderer: a pure pipeline from a settled voxel world to abrash's
// own RGBA framebuffer. It casts one ray per screen column through a voxel grid (the grid-DDA technique
// Michael Abrash documented for the software-3D lineage), finds the first solid voxel each ray hits, and
// paints a vertical wall slice whose height is the inverse of the perpendicular hit distance. The result
// is a first-person 3D view, computed in pure JS, written into a pixel framebuffer a canvas or a
// headless test can both read.
//
// THE BILATTICE READOUT (the whole point, in pixels): the voxel the ray hits carries a FOUR reading
// (from world.solidityAt), and the reading IS the wall's appearance — a direct readout of the bilattice,
// not decoration:
//   t   (affirmed)     : a clean, solid, distance-shaded wall slice (settled geometry).
//   ⊤   (contradicted) : a SHIVERING slice — the wall is drawn at an offset that oscillates with the
//                        tick PHASE (a parameter, never an RNG, so it is replay-identical), AND split-
//                        tinted (one witness's color on the top half, the other's on the bottom), so the
//                        contested wall shimmers between two faces. THE LAW: ⊤ is shown, never hidden —
//                        in a game it is a designed MECHANIC, the wall you cannot trust.
//   ⊥   (un-scanned)   : the ray PASSES (no solidity evidence to stop it), but if it reaches the far
//                        plane having only passed fog, the column dims toward the fog color — ⊥ shown
//                        faintly, not as a confident empty room.
//   f   (denied)       : a carved-open voxel — the ray passes (a denied wall is passable), drawn as
//                        floor, the negative face honored.
//
// Pure data in, pure data out: render(world, camera, opts) -> { fb, columns, census } where `fb` is an
// abrash Framebuffer. No node:tty, no Date.now, no Math.random.

import { Framebuffer } from "./framebuffer.mjs";
import { v2, dir, clampInt, mix } from "./math.mjs";
import { FOUR, gridReader } from "./grid.mjs";

// ── the palette: a reading -> wall color, the pixel readout of the bilattice (green t, red f, yellow ⊤
// seam, grey ⊥). A ⊤ wall paints BOTH faces (the affirm color and the deny color), split.
export const WALL_COLOR = Object.freeze({
  [FOUR.T]: [70, 190, 110],     // green — a settled, solid wall
  [FOUR.F]: [120, 60, 60],      // dark red — a carved/denied stub (rarely a wall; usually passed)
  [FOUR.TOP]: [225, 200, 40],   // yellow — contested (the seam color; the two faces are green/red)
  [FOUR.BOT]: [90, 90, 100],    // grey — fog (a wall guessed from no evidence)
});
const CONTESTED_AFFIRM = WALL_COLOR[FOUR.T];
const CONTESTED_DENY = [210, 60, 60]; // the deny face of a contested wall (brighter than the f stub)

const SKY = [18, 18, 28];
const FLOOR = [30, 26, 24];
const FOG = [60, 60, 72];

// ── the camera: position on the floor plane (x,z), a heading angle, a vertical FOV, and the screen
// extent. Pure; deterministic.
export function camera(opts = {}) {
  const x = opts.x ?? 0;
  const z = opts.z ?? 0;
  const angle = opts.angle ?? 0;        // radians; 0 looks along +x
  const fov = opts.fov ?? Math.PI / 3;  // horizontal field of view
  const width = opts.width ?? 256;
  const height = opts.height ?? 160;
  const maxDist = opts.maxDist ?? 32;   // far plane in grid cells
  return { x, z, angle, fov, width, height, maxDist };
}

// castRay(g, ox, oz, rdx, rdz, maxDist) — DDA grid traversal from origin (ox,oz) along unit ray
// (rdx,rdz). Steps cell-to-cell, asking the grid at each voxel. Stops at the FIRST voxel whose reading
// stops a ray: t (solid wall) or ⊤ (contested wall — both witnesses say solid, so the ray stops and the
// column will shiver). ⊥ fog and f carved voxels are PASSED. Returns { hit, reading, dist, side } where
// `dist` is the PERPENDICULAR distance (no fisheye — the caller divides out the ray's screen angle) and
// `side` is 0 (an x-face was crossed) or 1 (a z-face) for face shading. If the ray reaches maxDist with
// no stopping voxel, hit=false (open sky/fog out to the far plane).
export function castRay(g, ox, oz, rdx, rdz, maxDist) {
  let mapX = Math.floor(ox), mapZ = Math.floor(oz);
  // distance the ray travels in (x,z) to cross one full cell in that axis
  const deltaX = rdx === 0 ? Infinity : Math.abs(1 / rdx);
  const deltaZ = rdz === 0 ? Infinity : Math.abs(1 / rdz);
  let stepX, stepZ, sideDistX, sideDistZ;
  if (rdx < 0) { stepX = -1; sideDistX = (ox - mapX) * deltaX; }
  else { stepX = 1; sideDistX = (mapX + 1 - ox) * deltaX; }
  if (rdz < 0) { stepZ = -1; sideDistZ = (oz - mapZ) * deltaZ; }
  else { stepZ = 1; sideDistZ = (mapZ + 1 - oz) * deltaZ; }

  let side = 0;
  let dist = 0;
  // guard so a degenerate ray can't loop past the far plane
  for (let guard = 0; guard < maxDist * 4 + 8; guard++) {
    if (sideDistX < sideDistZ) { dist = sideDistX; sideDistX += deltaX; mapX += stepX; side = 0; }
    else { dist = sideDistZ; sideDistZ += deltaZ; mapZ += stepZ; side = 1; }
    if (dist > maxDist) return { hit: false, reading: FOUR.BOT, dist: maxDist, side };
    const cell = g.at(mapX, mapZ);
    // a ray STOPS only on a wall the world commits to: t (settled solid) or ⊤ (contested solid). ⊥/f pass.
    if (cell.reading === FOUR.T || cell.reading === FOUR.TOP) {
      return { hit: true, reading: cell.reading, dist, side, mapX, mapZ };
    }
  }
  return { hit: false, reading: FOUR.BOT, dist: maxDist, side };
}

// the ⊤ shiver: a deterministic per-phase pixel offset for a contested wall slice, driven by the tick
// PHASE (the tick count), NOT an RNG. Cycles through a tiny offset ring so the wall shimmers; the same
// phase gives the same offset — replay-identical.
function shiverOffset(phase) {
  const p = ((phase % 4) + 4) % 4;
  return [0, 1, 0, -1][p];
}

// shade(color, t) — darken a color toward black by distance fraction t∈[0,1] (0=near/bright, 1=far).
function shade(color, t) {
  const k = 1 - 0.75 * t;
  return [color[0] * k, color[1] * k, color[2] * k];
}

// ── billboards: the sprite pass ─────────────────────────────────────────────────────────────────
// A raycaster projects WALLS by casting one ray per column; it does not, by that same machinery, ever
// see a point object standing in open floor (nothing stops the ray there). A sprite is the classic
// second pass every software-3D engine of this lineage (Wolf3D, and the technique Abrash himself wrote
// up) adds on top: project each entity's world (x,z) into screen space by the SAME camera transform the
// wall rays use, and paint a billboard column-by-column, testing each column against the WALL DISTANCE
// that column's own ray already found (`columns[col].dist` — the depth buffer render() builds for free
// as a side effect of the wall pass) so a wall nearer than the sprite correctly occludes it, and a
// sprite nearer than the wall correctly draws over it. No new geometry, no new ray casts — one 2×2
// inverse-camera matrix per entity plus a per-column depth compare against work already done.
//
// invertCamera(cam) — the inverse of the [facing | plane] camera basis, so a world-space point can be
// projected into camera space (x = across the screen, y = depth along the view direction) without ever
// re-deriving the raycaster's own forward/plane vectors twice.
function invertCamera(cam) {
  const facing = dir(cam.angle);
  const plane = v2.scale(v2.perp(facing), Math.tan(cam.fov / 2));
  const det = plane[0] * facing[1] - facing[0] * plane[1];
  return { facing, plane, invDet: det === 0 ? 0 : 1 / det };
}

// projectEntity(inv, cam, ex, ez) — world (ex,ez) -> camera space { transformX, transformY }, where
// transformY is signed depth along the view direction (negative/zero = behind the camera, never drawn)
// and transformX/transformY is the entity's horizontal screen position in the same [-1,1]-ish space a
// wall ray's cameraX uses. Pure 2x2 linear algebra — the standard raycasting sprite transform.
function projectEntity(inv, cam, ex, ez) {
  const relX = ex - cam.x, relZ = ez - cam.z;
  const transformX = inv.invDet * (inv.facing[1] * relX - inv.facing[0] * relZ);
  const transformY = inv.invDet * (-inv.plane[1] * relX + inv.plane[0] * relZ);
  return { transformX, transformY };
}

// drawBillboard(fb, columns, cam, inv, entity) — paint one entity as a screen-facing billboard, column
// by column, depth-tested against `columns[col].dist` (the wall pass's own per-column depth buffer).
// Mutates `columns[col].entity = entity.id` for every column where a sprite pixel actually won the depth
// test (occluded columns are left untouched) — this is the buffer-level, assertable readout of "the
// sprite is actually visible here", not a side channel a test has to trust separately from the pixels.
const NEAR_PLANE = 0.05;
function drawBillboard(fb, columns, cam, inv, entity, wallColors) {
  const { transformX, transformY } = projectEntity(inv, cam, entity.x, entity.z);
  if (transformY <= NEAR_PLANE) return; // behind (or astride) the camera plane: never drawn
  const { width, height } = cam;
  const scale = entity.scale ?? 1;
  const spriteH = Math.abs(Math.round((height / transformY) * scale));
  const spriteW = spriteH; // square billboard: simplest silhouette, matches the wall slice's own scale
  if (spriteH <= 0) return;
  const screenX = Math.round((width / 2) * (1 + transformX / transformY));
  const drawStartY = Math.max(0, Math.round(height / 2 - spriteH / 2));
  const drawEndY = Math.min(height, Math.round(height / 2 + spriteH / 2));
  const drawStartX = Math.max(0, Math.round(screenX - spriteW / 2));
  const drawEndX = Math.min(width, Math.round(screenX + spriteW / 2));
  const [r, g, b] = entity.color ?? (entity.kind === 'portal' ? wallColors.portal : undefined) ?? [200, 40, 40];
  const distT = clampInt(Math.round((transformY / cam.maxDist) * 255), 0, 255) / 255;
  const [sr, sg, sb] = shade([r, g, b], distT * 0.5); // gentler falloff than a wall — a creature reads, not a smear
  for (let col = drawStartX; col < drawEndX; col++) {
    if (transformY >= columns[col].dist) continue; // a nearer wall (or an already-nearer sprite) wins
    // a round-ish silhouette: skip the corners of the square so it doesn't read as a floating box.
    const u = (col - screenX) / (spriteW / 2 || 1);
    for (let y = drawStartY; y < drawEndY; y++) {
      const v = (y - height / 2) / (spriteH / 2 || 1);
      if (u * u + v * v > 1) continue;
      fb.setPixel(col, y, sr, sg, sb, 255);
    }
    columns[col].entity = entity.id;
    columns[col].dist = Math.min(columns[col].dist, transformY); // a drawn sprite also occludes anything further behind it
  }
}

// render(world, cam, opts) — THE SEAM. Pure: a settled voxel world + a camera (+ a tick `phase` for the
// ⊤ shiver, + opts.entities for the sprite pass) → an abrash Framebuffer painting a first-person 3D
// view. `world` may be a pre-read grid (world.cells present) or a raw world — the raycaster accepts
// either. `opts.entities` is an array of { id, x, z, color:[r,g,b], scale } floor-plane point objects
// (durante's demons, e.g.) billboarded over the walls, depth-tested against each column's own wall hit —
// see drawBillboard above. Entities are painted FAR-TO-NEAR (painter's algorithm) so nearer entities
// correctly win over farther ones where two overlap on screen, matching how they'd occlude each other.
export function render(world, cam, opts = {}) {
  const phase = opts.phase ?? 0;
  const wallColors = { ...WALL_COLOR, ...(opts.wallColors ?? {}) };
  const g = gridReader(world, opts);
  const { width, height, fov, maxDist } = cam;
  const fb = new Framebuffer(width, height, opts.tile);

  // sky on the top half, floor on the bottom half — the calm ground the walls stand against.
  const horizon = height >> 1;
  fb.fillRect(0, 0, width, horizon, ...SKY, 255);
  fb.fillRect(0, horizon, width, height - horizon, ...FLOOR, 255);

  const facing = dir(cam.angle);          // forward unit vector
  const plane = v2.scale(v2.perp(facing), Math.tan(fov / 2)); // the camera plane (half-width at z=1)

  const census = { t: 0, f: 0, bot: 0, top: 0 };
  const columns = new Array(width);

  for (let col = 0; col < width; col++) {
    // cameraX in [-1, 1] across the screen; the ray direction is facing + plane*cameraX.
    const cameraX = (2 * col) / width - 1;
    const rdx = facing[0] + plane[0] * cameraX;
    const rdz = facing[1] + plane[1] * cameraX;
    const hit = castRay(g, cam.x, cam.z, rdx, rdz, maxDist);

    if (!hit.hit) {
      // no wall: leave sky/floor, but fog the far band so ⊥ reads as "unknown out there", not empty.
      columns[col] = { reading: FOUR.BOT, dist: hit.dist, drawn: false };
      census.bot++;
      // a faint fog line at the horizon so the open distance is shown, not silently void.
      fb.setPixel(col, horizon, ...FOG, 255);
      continue;
    }

    // wall slice height ∝ 1/distance (the inverse-distance projection). Clamp to the screen.
    const lineH = Math.min(height, Math.round(height / Math.max(hit.dist, 1e-3)));
    let top = (horizon - (lineH >> 1));
    let bot = top + lineH;
    const distT = clampInt(Math.round((hit.dist / maxDist) * 255), 0, 255) / 255;

    if (hit.reading === FOUR.TOP) {
      census.top++;
      // THE LAW IN PIXELS: a contested wall is drawn SHIVERING (phase-driven y offset) and SPLIT-tinted
      // — the affirm face on the top half, the deny face on the bottom half, both painted, no winner.
      const dy = shiverOffset(phase);
      top += dy; bot += dy;
      const mid = (top + bot) >> 1;
      const affirm = shade(CONTESTED_AFFIRM, distT * (hit.side ? 1 : 0.6));
      const deny = shade(CONTESTED_DENY, distT * (hit.side ? 1 : 0.6));
      drawSlice(fb, col, top, mid, affirm);
      drawSlice(fb, col, mid, bot, deny);
      // a one-pixel yellow seam at the split so the contested boundary reads at a glance.
      if (mid >= 0 && mid < height) fb.setPixel(col, mid, ...WALL_COLOR[FOUR.TOP], 255);
      columns[col] = { reading: FOUR.TOP, dist: hit.dist, drawn: true, top, bot, shiver: dy };
    } else {
      census.t++;
      // a settled wall: clean, distance-shaded, x-faces dimmer than z-faces so corners read.
      const base = shade(wallColors[FOUR.T], distT * (hit.side ? 1 : 0.65));
      drawSlice(fb, col, top, bot, base);
      columns[col] = { reading: FOUR.T, dist: hit.dist, drawn: true, top, bot };
    }
  }

  // ── the sprite pass: entities billboarded over the walls, depth-tested column by column against
  // the wall pass's own `columns[col].dist`. Painter's algorithm: farthest first, so a nearer entity
  // (or a nearer wall, via the depth test inside drawBillboard) always wins the pixels it should.
  const entities = opts.entities ?? [];
  if (entities.length) {
    const inv = invertCamera(cam);
    const withDepth = entities
      .map((e) => ({ e, y: projectEntity(inv, cam, e.x, e.z).transformY }))
      .filter(({ y }) => y > NEAR_PLANE)
      .sort((a, b) => b.y - a.y);
    for (const { e } of withDepth) drawBillboard(fb, columns, cam, inv, e, wallColors);
  }

  return { fb, columns, census, phase, width, height };
}

// drawSlice(fb, col, top, bot, color) — paint one vertical wall column from row `top` to `bot` (clipped).
function drawSlice(fb, col, top, bot, color) {
  const y0 = Math.max(0, top | 0), y1 = Math.min(fb.height, bot | 0);
  for (let y = y0; y < y1; y++) fb.setPixel(col, y, color[0], color[1], color[2], 255);
}
