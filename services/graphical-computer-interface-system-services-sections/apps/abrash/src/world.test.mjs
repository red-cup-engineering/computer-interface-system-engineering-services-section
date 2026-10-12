// world.test.mts — proves the domain read world.mjs adds on top of the published
// @red-cup-engineering/computer/distribution algebra it consumes: cellKey naming,
// readingOf's four-way readout, and solidityAt/grid/place/disagreements over the shipped proving-ground
// seed (world/proving-ground.jsonl: a 5x5 room with one contested wall at voxel:2,4).

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import {
  worldFromRows, place, grid, solidityAt, disagreements, readingOf, cellKey, predicate, deny, FOUR,
} from "./world.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const SEED = join(HERE, "..", "world", "proving-ground.jsonl");

function loadSeed() {
  const text = readFileSync(SEED, "utf8").trim();
  return text.split("\n").map((l) => JSON.parse(l));
}

test("cellKey: names a voxel subject from integer grid coordinates, truncating toward zero", () => {
  assert.equal(cellKey(2, 4), "voxel:2,4");
  assert.equal(cellKey(2.9, 4.1), "voxel:2,4");
  assert.equal(cellKey(-1, -1), "voxel:-1,-1");
});

test("readingOf: the four-way readout — bot/t/f/top from {pos,neg}", () => {
  assert.equal(readingOf(undefined), FOUR.BOT);
  assert.equal(readingOf({ pos: 0, neg: 0 }), FOUR.BOT);
  assert.equal(readingOf({ pos: 1, neg: 0 }), FOUR.T);
  assert.equal(readingOf({ pos: 0, neg: 1 }), FOUR.F);
  assert.equal(readingOf({ pos: 1, neg: 1 }), FOUR.TOP);
});

test("worldFromRows: the shipped seed loads to a world whose subjects are exactly its voxel rows' entities", () => {
  const rows = loadSeed();
  const w = worldFromRows(rows);
  const g = grid(w);
  assert.ok(g.cells.size > 0);
});

test("solidityAt: a plain settled wall from the seed reads t", () => {
  const w = worldFromRows(loadSeed());
  const s = solidityAt(w, 0, 0);
  assert.equal(s.reading, FOUR.T);
});

test("solidityAt: an un-admitted voxel reads bot (⊥, un-scanned fog)", () => {
  const w = worldFromRows(loadSeed());
  const s = solidityAt(w, 99, 99);
  assert.equal(s.reading, FOUR.BOT);
});

test("solidityAt: voxel:2,4 is contested (told solid, then not-solid) and reads top", () => {
  const w = worldFromRows(loadSeed());
  const s = solidityAt(w, 2, 4);
  assert.equal(s.reading, FOUR.TOP);
});

test("place: a contested voxel's `contested` list carries the cell, and `reading` reads top", () => {
  const w = worldFromRows(loadSeed());
  const p = place(w, "voxel:2,4");
  assert.equal(p.reading, FOUR.TOP);
  assert.equal(p.contested.length, 1);
  assert.equal(p.contested[0].predicate, "solid");
  assert.equal(p.visited, true);
});

test("place: an un-admitted subject is NOT visited (⊥, pure potential)", () => {
  const w = worldFromRows(loadSeed());
  const p = place(w, "voxel:99,99");
  assert.equal(p.visited, false);
  assert.equal(p.reading, FOUR.BOT);
});

test("grid: only voxels with solidity evidence appear; bounds cover the seed's room", () => {
  const w = worldFromRows(loadSeed());
  const g = grid(w);
  assert.ok(g.bounds.minX <= 0 && g.bounds.maxX >= 4);
  assert.ok(g.bounds.minZ <= 0 && g.bounds.maxZ >= 4);
  assert.equal(g.at(2, 4).reading, FOUR.TOP);
  assert.equal(g.at(50, 50).reading, FOUR.BOT); // outside the grid map, defaults to fog
});

test("disagreements: exactly one contested voxel in the seed, at voxel:2,4", () => {
  const w = worldFromRows(loadSeed());
  const ds = disagreements(w);
  const voxelDs = ds.filter((d) => /^voxel:/.test(d.subject));
  assert.equal(voxelDs.length, 1);
  assert.equal(voxelDs[0].subject, "voxel:2,4");
});

test("predicate/deny: deny's predicate name is exactly not-<p>, the converse the CONVERSE map expects", () => {
  const pos = predicate("voxel:0,0", "solid", "wall", 1);
  const neg = deny("voxel:0,0", "solid", "wall", 2);
  assert.equal(pos.a, "solid");
  assert.equal(neg.a, "not-solid");
  assert.equal(pos.e, neg.e);
  assert.equal(pos.v, neg.v);
});

test("a fresh world built from predicate+deny on the same cell reads top, mirroring the seed", () => {
  const w = worldFromRows([
    predicate("voxel:0,0", "solid", "wall", 1),
    deny("voxel:0,0", "solid", "wall", 2),
  ]);
  assert.equal(solidityAt(w, 0, 0).reading, FOUR.TOP);
});

test("a fresh world built from deny alone (no prior affirm) settles to f (denied)", () => {
  const w = worldFromRows([deny("voxel:0,0", "solid", "wall", 1)]);
  assert.equal(solidityAt(w, 0, 0).reading, FOUR.F);
});
