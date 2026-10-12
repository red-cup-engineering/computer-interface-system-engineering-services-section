// math.test.mts — proves the vec2/rotation kernel's identities: rotation preserves length, a
// perpendicular dots to zero.

import { test } from "node:test";
import assert from "node:assert/strict";
import { v2, dir, clampInt, mix } from "./math.mjs";

test("v2.add/sub are inverses", () => {
  const a = [3, -2], b = [1.5, 4];
  assert.deepEqual(v2.add(v2.sub(a, b), b), a);
});

test("v2.scale distributes over add", () => {
  const a = [2, 3], b = [-1, 5];
  const lhs = v2.scale(v2.add(a, b), 2);
  const rhs = v2.add(v2.scale(a, 2), v2.scale(b, 2));
  assert.deepEqual(lhs, rhs);
});

test("v2.dot of a vector with itself equals length squared", () => {
  const a = [3, 4];
  assert.equal(v2.dot(a, a), v2.length(a) ** 2);
});

test("v2.length: a 3-4-5 triangle", () => {
  assert.equal(v2.length([3, 4]), 5);
});

test("v2.normalize: unit length, same direction as the original (positive dot)", () => {
  const a = [6, -8];
  const n = v2.normalize(a);
  assert.ok(Math.abs(v2.length(n) - 1) < 1e-12);
  assert.ok(v2.dot(a, n) > 0);
});

test("v2.normalize: the zero vector normalizes to the zero vector (no NaN)", () => {
  assert.deepEqual(v2.normalize([0, 0]), [0, 0]);
});

test("v2.perp: THE IDENTITY — dot(a, perp(a)) === 0 for arbitrary a", () => {
  for (const a of [[1, 0], [0, 1], [3, 4], [-2, 7], [5.5, -1.25]]) {
    assert.equal(v2.dot(a, v2.perp(a)), 0);
  }
});

test("v2.perp: is a 90 degree CCW rotation (perp(perp(a)) === -a)", () => {
  const a = [3, 4];
  const pp = v2.perp(v2.perp(a));
  assert.deepEqual(pp, [-a[0], -a[1]]);
});

test("v2.rotate: THE IDENTITY — rotation preserves length", () => {
  const a = [3, 4];
  for (const ang of [0, 0.1, Math.PI / 4, Math.PI / 2, Math.PI, 2.7, -1.3]) {
    const r = v2.rotate(a, ang);
    assert.ok(Math.abs(v2.length(r) - v2.length(a)) < 1e-9, `angle ${ang}`);
  }
});

test("v2.rotate: rotating by 0 is the identity transform", () => {
  const a = [3, -4];
  const r = v2.rotate(a, 0);
  assert.ok(Math.abs(r[0] - a[0]) < 1e-12 && Math.abs(r[1] - a[1]) < 1e-12);
});

test("v2.rotate: rotating by PI/2 matches perp (up to floating point)", () => {
  const a = [1, 0];
  const r = v2.rotate(a, Math.PI / 2);
  assert.ok(Math.abs(r[0] - 0) < 1e-9);
  assert.ok(Math.abs(r[1] - 1) < 1e-9);
});

test("v2.rotate: composing two rotations equals rotating by the sum of angles", () => {
  const a = [2, 5];
  const composed = v2.rotate(v2.rotate(a, 0.4), 0.9);
  const summed = v2.rotate(a, 1.3);
  assert.ok(Math.abs(composed[0] - summed[0]) < 1e-9);
  assert.ok(Math.abs(composed[1] - summed[1]) < 1e-9);
});

test("dir(angle): a unit vector, matching cos/sin", () => {
  const d = dir(Math.PI / 3);
  assert.ok(Math.abs(d[0] - Math.cos(Math.PI / 3)) < 1e-12);
  assert.ok(Math.abs(d[1] - Math.sin(Math.PI / 3)) < 1e-12);
  assert.ok(Math.abs(v2.length(d) - 1) < 1e-12);
});

test("dir(0) looks along +x", () => {
  assert.deepEqual(dir(0), [1, 0]);
});

test("clampInt: clamps below the low bound", () => {
  assert.equal(clampInt(-5, 0, 10), 0);
});

test("clampInt: clamps above the high bound", () => {
  assert.equal(clampInt(15, 0, 10), 10);
});

test("clampInt: passes an in-range value through, truncated to an integer", () => {
  assert.equal(clampInt(4.9, 0, 10), 4);
});

test("mix: linear interpolation endpoints and midpoint", () => {
  assert.equal(mix(0, 10, 0), 0);
  assert.equal(mix(0, 10, 1), 10);
  assert.equal(mix(0, 10, 0.5), 5);
});

test("mix: extrapolates outside [0,1] (no clamping — that's clampInt's job)", () => {
  assert.equal(mix(0, 10, 1.5), 15);
});
