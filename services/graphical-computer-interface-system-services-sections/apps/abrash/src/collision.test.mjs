// collision.test.mts — proves the four-valued blocking predicate (t/⊤ block, f/⊥ pass — the SAME
// predicate the raycaster uses to stop a ray, per collision.mjs's own header) and the per-axis
// slide-along-walls resolution.

import { test } from "node:test";
import assert from "node:assert/strict";
import { blocks, occupied, move, clearAhead } from "./collision.mjs";
import { FOUR } from "./world.mjs";

test("blocks: t (settled solid) blocks", () => {
  assert.equal(blocks(FOUR.T), true);
});

test("blocks: ⊤ (contested) blocks BY DEFAULT — the held contradiction is an obstacle, not a pass-through", () => {
  assert.equal(blocks(FOUR.TOP), true);
});

test("blocks: ⊤ passes when a game opts into passContested (the deathmatch phase-gate mechanic)", () => {
  assert.equal(blocks(FOUR.TOP, { passContested: true }), false);
});

test("blocks: f (carved/denied) passes", () => {
  assert.equal(blocks(FOUR.F), false);
});

test("blocks: ⊥ (un-scanned fog) passes", () => {
  assert.equal(blocks(FOUR.BOT), false);
});

function gridOf(solidCells) {
  return { at: (x, z) => ({ reading: solidCells.has(`${Math.floor(x)},${Math.floor(z)}`) ? FOUR.T : FOUR.BOT }) };
}

test("occupied: true when any voxel within radius of the point blocks", () => {
  const g = gridOf(new Set(["2,2"]));
  assert.equal(occupied(g, 2.5, 2.5, 0.2), true);
});

test("occupied: false in open fog", () => {
  const g = gridOf(new Set());
  assert.equal(occupied(g, 2.5, 2.5, 0.2), false);
});

test("move: an unobstructed move applies both axes in full", () => {
  const g = gridOf(new Set());
  const { body, hit } = move(g, { x: 1, z: 1, radius: 0.2 }, 0.3, 0.4);
  assert.ok(Math.abs(body.x - 1.3) < 1e-9);
  assert.ok(Math.abs(body.z - 1.4) < 1e-9);
  assert.equal(hit.x, false);
  assert.equal(hit.z, false);
});

test("move: SLIDE — a wall blocking only the x-axis still allows the z move through (grazing slide)", () => {
  // a wall at (2,1): moving from (1.5,1.5) by (+0.4,+0.2) would push x into the wall's cell; z alone is clear.
  const g = gridOf(new Set(["2,1"]));
  const { body, hit } = move(g, { x: 1.5, z: 1.5, radius: 0.2 }, 0.4, 0.2);
  assert.equal(hit.x, true);
  assert.equal(body.x, 1.5); // x canceled
  assert.ok(Math.abs(body.z - 1.7) < 1e-9); // z still applied — the slide
  assert.equal(hit.z, false);
});

test("move: a wall on both resolved axes blocks the body entirely (returns to input position)", () => {
  const g = gridOf(new Set(["2,2"]));
  const { body, hit } = move(g, { x: 1.9, z: 1.9, radius: 0.2 }, 0.3, 0.3);
  assert.equal(hit.x, true);
  assert.equal(hit.z, true);
  assert.equal(body.x, 1.9);
  assert.equal(body.z, 1.9);
});

test("move: never mutates the input body object", () => {
  const g = gridOf(new Set());
  const input = { x: 0, z: 0, radius: 0.2 };
  move(g, input, 1, 1);
  assert.deepEqual(input, { x: 0, z: 0, radius: 0.2 });
});

test("clearAhead: reports maxDist when the path is entirely clear", () => {
  const g = gridOf(new Set());
  const d = clearAhead(g, { x: 0, z: 0, radius: 0.2 }, 1, 0, 4);
  assert.equal(d, 4);
});

test("clearAhead: reports a distance shorter than maxDist when a wall blocks the feeler", () => {
  const g = gridOf(new Set(["3,0"]));
  const d = clearAhead(g, { x: 0, z: 0, radius: 0.2 }, 1, 0, 8);
  assert.ok(d < 8 && d > 0);
});
