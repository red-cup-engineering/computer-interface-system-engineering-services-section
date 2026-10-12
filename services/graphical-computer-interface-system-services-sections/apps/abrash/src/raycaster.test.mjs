// raycaster.test.mts — proves castRay against known geometry (a ray into an adjacent wall returns the
// expected distance and face side) plus render()'s pixel-level bilattice readout: a settled wall paints,
// an un-scanned direction fogs, and a contested wall shivers (a phase-driven offset, deterministic — not
// sampled from any RNG).

import { test } from "node:test";
import assert from "node:assert/strict";
import { castRay, camera, render, WALL_COLOR } from "./raycaster.mjs";
import { FOUR, worldFromRows, predicate, deny } from "./world.mjs";

// a tiny hand-built grid mock: solid(x,z) reports which cells are walls, everything else is ⊥ fog.
function mockGrid(solidCells) {
  return { at: (x, z) => ({ x, z, reading: solidCells.has(`${x},${z}`) ? FOUR.T : FOUR.BOT }) };
}

test("castRay: a ray cast +x from a cell center into an adjacent solid wall hits at dist=0.5, side=0 (x-face)", () => {
  const g = mockGrid(new Set(["1,0"]));
  const hit = castRay(g, 0.5, 0.5, 1, 0, 16);
  assert.equal(hit.hit, true);
  assert.equal(hit.side, 0);
  assert.ok(Math.abs(hit.dist - 0.5) < 1e-9);
  assert.equal(hit.reading, FOUR.T);
});

test("castRay: a ray cast +z from a cell center into an adjacent solid wall hits at dist=0.5, side=1 (z-face)", () => {
  const g = mockGrid(new Set(["0,1"]));
  const hit = castRay(g, 0.5, 0.5, 0, 1, 16);
  assert.equal(hit.hit, true);
  assert.equal(hit.side, 1);
  assert.ok(Math.abs(hit.dist - 0.5) < 1e-9);
});

test("castRay: a ray cast -x hits a wall behind the origin's facing, side=0", () => {
  const g = mockGrid(new Set(["-1,0"]));
  const hit = castRay(g, 0.5, 0.5, -1, 0, 16);
  assert.equal(hit.hit, true);
  assert.equal(hit.side, 0);
  assert.ok(Math.abs(hit.dist - 0.5) < 1e-9);
});

test("castRay: an open direction with no wall within maxDist misses (hit:false, dist:maxDist)", () => {
  const g = mockGrid(new Set());
  const hit = castRay(g, 0.5, 0.5, 1, 0, 4);
  assert.equal(hit.hit, false);
  assert.equal(hit.dist, 4);
  assert.equal(hit.reading, FOUR.BOT);
});

test("castRay: distance grows linearly with a wall's distance along the ray", () => {
  const near = castRay(mockGrid(new Set(["1,0"])), 0.5, 0.5, 1, 0, 16);
  const far = castRay(mockGrid(new Set(["5,0"])), 0.5, 0.5, 1, 0, 16);
  assert.ok(far.dist > near.dist);
  assert.ok(Math.abs(far.dist - near.dist - 4) < 1e-9);
});

test("castRay: a ⊤ (contested) voxel stops the ray exactly like a settled t wall", () => {
  const g = { at: () => ({ reading: FOUR.TOP }) };
  const hit = castRay(g, 0.5, 0.5, 1, 0, 16);
  assert.equal(hit.hit, true);
  assert.equal(hit.reading, FOUR.TOP);
});

test("castRay: an f (denied/carved) voxel is PASSED, not stopped", () => {
  const g = { at: () => ({ reading: FOUR.F }) };
  const hit = castRay(g, 0.5, 0.5, 1, 0, 4);
  assert.equal(hit.hit, false); // never finds a stopping voxel within maxDist
});

test("render: dimensions match the camera, and a facing wall increases the settled (t) census", () => {
  const w = worldFromRows([predicate("voxel:2,0", "solid", "wall", 1)]);
  const cam = camera({ x: 0.5, z: 0.5, angle: 0, width: 32, height: 24, maxDist: 8 });
  const frame = render(w, cam, { phase: 0 });
  assert.equal(frame.fb.width, 32);
  assert.equal(frame.fb.height, 24);
  assert.ok(frame.census.t > 0);
});

test("render: no walls at all yields an all-fog census (every column bot)", () => {
  const w = worldFromRows([]);
  const cam = camera({ x: 0.5, z: 0.5, angle: 0, width: 16, height: 16, maxDist: 4 });
  const frame = render(w, cam, { phase: 0 });
  assert.equal(frame.census.t, 0);
  assert.equal(frame.census.top, 0);
  assert.equal(frame.census.bot, 16);
});

test("render: THE LAW IN PIXELS — a contested voxel is never hidden: census.top counts every column that hit it", () => {
  const w = worldFromRows([
    predicate("voxel:2,0", "solid", "wall", 1),
    deny("voxel:2,0", "solid", "wall", 2),
  ]);
  const cam = camera({ x: 0.5, z: 0.5, angle: 0, width: 16, height: 16, maxDist: 8 });
  const frame = render(w, cam, { phase: 0 });
  assert.ok(frame.census.top > 0);
  assert.equal(frame.census.t, 0); // every hit column reads contested, none reads plain-settled
});

test("render: a contested wall's column carries a `shiver` offset, and it changes with phase (deterministic, not random)", () => {
  const w = worldFromRows([
    predicate("voxel:2,0", "solid", "wall", 1),
    deny("voxel:2,0", "solid", "wall", 2),
  ]);
  const cam = camera({ x: 0.5, z: 0.5, angle: 0, width: 8, height: 16, maxDist: 8 });
  const f0 = render(w, cam, { phase: 0 });
  const f1 = render(w, cam, { phase: 1 });
  const f4 = render(w, cam, { phase: 4 }); // phase cycles mod 4, so phase 4 must equal phase 0
  const col0a = f0.columns.find((c) => c && c.reading === FOUR.TOP);
  const col0b = f1.columns.find((c) => c && c.reading === FOUR.TOP);
  const col0c = f4.columns.find((c) => c && c.reading === FOUR.TOP);
  assert.ok(col0a.shiver !== col0b.shiver, "phase 0 and phase 1 must differ (the shiver)");
  assert.equal(col0a.shiver, col0c.shiver, "the shiver ring cycles mod 4 — phase 4 replays phase 0");
});

test("render: rendering the identical world+camera+phase twice is byte-identical (replay-determinism, no Date.now/Math.random)", () => {
  const w = worldFromRows([predicate("voxel:2,0", "solid", "wall", 1)]);
  const cam = camera({ x: 0.5, z: 0.5, angle: 0.3, width: 20, height: 20, maxDist: 8 });
  const a = render(w, cam, { phase: 3 });
  const b = render(w, cam, { phase: 3 });
  assert.deepEqual([...a.fb.data], [...b.fb.data]);
});

test("WALL_COLOR: defines a color for all four readings", () => {
  for (const c of [FOUR.T, FOUR.F, FOUR.TOP, FOUR.BOT]) {
    assert.ok(Array.isArray(WALL_COLOR[c]) && WALL_COLOR[c].length === 3);
  }
});

// ── the sprite pass: an entity is a floor-plane point, never a wall — so every test below uses an open
// (wall-free) world and puts the camera's own view of a solid-color entity under test.
test("render: an entity dead ahead in open floor paints its color into the framebuffer and is recorded on its columns", () => {
  const w = worldFromRows([]); // no walls anywhere — an entity is the only thing that can paint here
  const cam = camera({ x: 0.5, z: 0.5, angle: 0, width: 40, height: 40, maxDist: 16 });
  const frame = render(w, cam, { phase: 0, entities: [{ id: "e1", x: 5.5, z: 0.5, color: [255, 0, 0] }] });
  const centerCol = frame.columns[20];
  assert.equal(centerCol.entity, "e1", "the center column, looking straight at the entity, is marked drawn by it");
  const [r, g, b, a] = frame.fb.getPixel(20, 20);
  assert.equal(a, 255);
  assert.ok(r > g && r > b, `center pixel should read red-dominant (got ${r},${g},${b})`);
});

test("render: an entity behind the camera is never drawn (no column references it)", () => {
  const w = worldFromRows([]);
  const cam = camera({ x: 5.5, z: 0.5, angle: 0, width: 20, height: 20, maxDist: 16 }); // facing +x
  const frame = render(w, cam, { phase: 0, entities: [{ id: "behind", x: 0.5, z: 0.5, color: [255, 0, 0] }] });
  assert.ok(frame.columns.every((c) => c.entity === undefined));
});

test("render: an entity BEHIND a nearer wall is occluded — no column marks it drawn, and the wall's own color still paints", () => {
  const w = worldFromRows([predicate("voxel:2,0", "solid", "wall", 1)]); // a wall at x=2, camera at x=0.5 facing +x
  const cam = camera({ x: 0.5, z: 0.5, angle: 0, width: 40, height: 40, maxDist: 16 });
  const frame = render(w, cam, {
    phase: 0,
    entities: [{ id: "hidden", x: 5.5, z: 0.5, color: [255, 0, 0] }], // past the wall — should not be seen
  });
  assert.ok(frame.columns.every((c) => c.entity === undefined), "the wall occludes the entity on every column");
  assert.ok(frame.census.t > 0, "the wall itself still rendered normally");
});

test("render: the SAME entity in open floor (no occluding wall) DOES draw — the occlusion test above is really testing the wall, not a bug that hides everything", () => {
  const w = worldFromRows([]); // identical entity position, no wall this time
  const cam = camera({ x: 0.5, z: 0.5, angle: 0, width: 40, height: 40, maxDist: 16 });
  const frame = render(w, cam, { phase: 0, entities: [{ id: "hidden", x: 5.5, z: 0.5, color: [255, 0, 0] }] });
  assert.ok(frame.columns.some((c) => c.entity === "hidden"), "with no wall in the way, the entity IS drawn");
});

test("render: a nearer entity occludes a farther entity on overlapping columns (painter's algorithm)", () => {
  const w = worldFromRows([]);
  const cam = camera({ x: 0.5, z: 0.5, angle: 0, width: 60, height: 60, maxDist: 16 });
  const frame = render(w, cam, {
    phase: 0,
    entities: [
      { id: "far", x: 8.5, z: 0.5, color: [0, 255, 0] },
      { id: "near", x: 3.5, z: 0.5, color: [255, 0, 0] },
    ],
  });
  const centerCol = frame.columns[30];
  assert.equal(centerCol.entity, "near", "the nearer entity wins the shared center column, not the farther one");
});

test("render: entity size on screen shrinks with distance (perspective, matching the wall slice's own 1/dist law)", () => {
  const w = worldFromRows([]);
  const cam = camera({ x: 0.5, z: 0.5, angle: 0, width: 60, height: 60, maxDist: 24 });
  const near = render(w, cam, { phase: 0, entities: [{ id: "e", x: 2.5, z: 0.5, color: [255, 0, 0] }] });
  const far = render(w, cam, { phase: 0, entities: [{ id: "e", x: 12.5, z: 0.5, color: [255, 0, 0] }] });
  const widthOf = (frame) => frame.columns.filter((c) => c.entity === "e").length;
  assert.ok(widthOf(near) > widthOf(far), `nearer entity should occupy more columns (near=${widthOf(near)}, far=${widthOf(far)})`);
});

test("render: with no opts.entities at all, behavior is byte-identical to before the sprite pass existed (no entities, no side effect)", () => {
  const w = worldFromRows([predicate("voxel:2,0", "solid", "wall", 1)]);
  const cam = camera({ x: 0.5, z: 0.5, angle: 0, width: 16, height: 16, maxDist: 8 });
  const withEmpty = render(w, cam, { phase: 0, entities: [] });
  const withoutOpt = render(w, cam, { phase: 0 });
  assert.deepEqual([...withEmpty.fb.data], [...withoutOpt.fb.data]);
});
