// distribution.test.mts — proves this package's consumption of @red-cup-engineering/computer's
// distribution algebra: the G-Set union semantics (order-independent, idempotent, content-deduped),
// the frontier/sectionOf read-lens against the published substrate's own fold/settle/section, that
// disagreements finds every ⊤ cell, and that migrate (aliasing that package's migrateSubjects) re-keys
// without losing evidence. Formerly federation.mts's own reimplementation of this algebra; the algebra
// itself now lives once, upstream, at @red-cup-engineering/computer/distribution — this file proves
// abrash's wiring against it, not a second copy of the algebra's own unit tests.

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  emptyWorld, admitLog, logFor, subjects, allRows,
  federate, mergeWorlds, frontier, sectionOf, disagreements,
  migrateSubjects as migrate,
} from "@red-cup-engineering/computer/distribution";

const P = (s, a, v, t) => ({ e: s, a, v, t });

test("emptyWorld: no subjects, no rows", () => {
  const w = emptyWorld();
  assert.deepEqual(subjects(w), []);
  assert.deepEqual(allRows(w), []);
});

test("admitLog: appends under the subject and is pure (does not mutate the input world)", () => {
  const w0 = emptyWorld();
  const { world: w1 } = admitLog(w0, "a", [P("a", "solid", "wall", 1)]);
  assert.deepEqual(subjects(w0), []); // w0 untouched
  assert.deepEqual(subjects(w1), ["a"]);
  assert.equal(logFor(w1, "a").length, 1);
});

test("admitLog: content-dedups — re-admitting the identical row is a no-op on the log length", () => {
  const w0 = emptyWorld();
  const { world: w1 } = admitLog(w0, "a", [P("a", "solid", "wall", 1)]);
  const { world: w2 } = admitLog(w1, "a", [P("a", "solid", "wall", 1)]);
  assert.equal(logFor(w2, "a").length, 1);
});

test("admitLog: validates rows via the substrate's assertRow (throws on a malformed row)", () => {
  const w0 = emptyWorld();
  assert.throws(() => admitLog(w0, "a", [{ e: "a", a: "solid" }]));
});

test("allRows: flattens every subject's log", () => {
  let w = emptyWorld();
  w = admitLog(w, "a", [P("a", "solid", "wall", 1)]).world;
  w = admitLog(w, "b", [P("b", "solid", "wall", 1)]).world;
  assert.equal(allRows(w).length, 2);
});

test("federate: G-Set union — a row present in only one side survives", () => {
  let a = emptyWorld();
  a = admitLog(a, "x", [P("x", "solid", "wall", 1)]).world;
  const b = emptyWorld();
  const merged = federate(a, b);
  assert.equal(logFor(merged, "x").length, 1);
});

test("federate: content-identical rows from both sides collapse to one (deduped by rowId)", () => {
  let a = emptyWorld();
  a = admitLog(a, "x", [P("x", "solid", "wall", 1)]).world;
  let b = emptyWorld();
  b = admitLog(b, "x", [P("x", "solid", "wall", 1)]).world;
  const merged = federate(a, b);
  assert.equal(logFor(merged, "x").length, 1);
});

test("federate: order-independent — federate(a,b) equals federate(b,a) (same rows per subject)", () => {
  let a = emptyWorld();
  a = admitLog(a, "x", [P("x", "solid", "wall", 1)]).world;
  let b = emptyWorld();
  b = admitLog(b, "x", [P("x", "not-solid", "wall", 2)]).world;
  const ab = federate(a, b);
  const ba = federate(b, a);
  assert.deepEqual(
    logFor(ab, "x").map((r) => JSON.stringify(r)).sort(),
    logFor(ba, "x").map((r) => JSON.stringify(r)).sort(),
  );
});

test("federate: idempotent — federating a world with itself changes nothing", () => {
  let a = emptyWorld();
  a = admitLog(a, "x", [P("x", "solid", "wall", 1)]).world;
  const merged = federate(a, a);
  assert.equal(logFor(merged, "x").length, 1);
});

test("federate: two DISAGREEING traces both survive as distinct witnesses (nothing dropped)", () => {
  let a = emptyWorld();
  a = admitLog(a, "x", [P("x", "solid", "wall", 1)]).world;
  let b = emptyWorld();
  b = admitLog(b, "x", [P("x", "not-solid", "wall", 1)]).world;
  const merged = federate(a, b);
  assert.equal(logFor(merged, "x").length, 2);
});

test("mergeWorlds: folds an arbitrary number of worlds left to right", () => {
  let a = emptyWorld(); a = admitLog(a, "x", [P("x", "solid", "wall", 1)]).world;
  let b = emptyWorld(); b = admitLog(b, "y", [P("y", "solid", "wall", 1)]).world;
  let c = emptyWorld(); c = admitLog(c, "z", [P("z", "solid", "wall", 1)]).world;
  const merged = mergeWorlds(a, b, c);
  assert.deepEqual(subjects(merged).sort(), ["x", "y", "z"]);
});

test("mergeWorlds: zero worlds gives an empty world", () => {
  assert.deepEqual(subjects(mergeWorlds()), []);
});

test("frontier: matches the published substrate directly — an affirm-only subject folds to pos:1,neg:0", () => {
  let w = emptyWorld();
  w = admitLog(w, "x", [P("x", "solid", "wall", 1)]).world;
  const folded = frontier(w, "x", { converse: { "not-solid": "solid" } });
  assert.equal(folded.fiber.length, 1);
  assert.equal(folded.fiber[0].value.pos, 1);
  assert.equal(folded.fiber[0].value.neg, 0);
});

test("frontier: an affirm + its converse fold to a HELD contradiction (pos:1, neg:1)", () => {
  let w = emptyWorld();
  w = admitLog(w, "x", [P("x", "solid", "wall", 1), P("x", "not-solid", "wall", 2)]).world;
  const folded = frontier(w, "x", { converse: { "not-solid": "solid" } });
  assert.equal(folded.fiber[0].value.pos, 1);
  assert.equal(folded.fiber[0].value.neg, 1);
});

test("frontier: an unadmitted subject folds to an empty fiber (⊥, no evidence)", () => {
  const w = emptyWorld();
  const folded = frontier(w, "never-admitted", {});
  assert.deepEqual(folded.fiber, []);
});

test("sectionOf: an affirm-only subject reads as affirmed, not denied or contradicted", () => {
  let w = emptyWorld();
  w = admitLog(w, "x", [P("x", "solid", "wall", 1)]).world;
  const s = sectionOf(w, "x", { converse: { "not-solid": "solid" } });
  assert.equal(s.affirmed.length, 1);
  assert.equal(s.denied.length, 0);
  assert.equal(s.contradicted.length, 0);
});

test("sectionOf: a contested subject reads as contradicted, not affirmed or denied", () => {
  let w = emptyWorld();
  w = admitLog(w, "x", [P("x", "solid", "wall", 1), P("x", "not-solid", "wall", 2)]).world;
  const s = sectionOf(w, "x", { converse: { "not-solid": "solid" } });
  assert.equal(s.contradicted.length, 1);
  assert.equal(s.affirmed.length, 0);
});

test("disagreements: finds the one contested subject in a world of otherwise-settled ones", () => {
  let w = emptyWorld();
  w = admitLog(w, "settled-a", [P("settled-a", "solid", "wall", 1)]).world;
  w = admitLog(w, "settled-b", [P("settled-b", "solid", "wall", 1)]).world;
  w = admitLog(w, "contested", [P("contested", "solid", "wall", 1), P("contested", "not-solid", "wall", 2)]).world;
  const ds = disagreements(w, { converse: { "not-solid": "solid" } });
  assert.equal(ds.length, 1);
  assert.equal(ds[0].subject, "contested");
  assert.equal(ds[0].predicate, "solid");
});

test("disagreements: empty when nothing is contested", () => {
  let w = emptyWorld();
  w = admitLog(w, "a", [P("a", "solid", "wall", 1)]).world;
  assert.deepEqual(disagreements(w, { converse: { "not-solid": "solid" } }), []);
});

test("disagreements: is exactly how federate() surfaces a merge conflict — the arena/durante pattern", () => {
  let alpha = emptyWorld();
  alpha = admitLog(alpha, "voxel:4,4", [P("voxel:4,4", "solid", "wall", 1)]).world;
  let beta = emptyWorld();
  beta = admitLog(beta, "voxel:4,4", [P("voxel:4,4", "not-solid", "wall", 1)]).world;
  const merged = federate(alpha, beta);
  const ds = disagreements(merged, { converse: { "not-solid": "solid" } });
  assert.equal(ds.length, 1);
  assert.equal(ds[0].subject, "voxel:4,4");
});

test("migrate: rebuilds a world with every row's subject renamed through the mapping function", () => {
  let w = emptyWorld();
  w = admitLog(w, "old:1", [P("old:1", "solid", "wall", 1)]).world;
  const moved = migrate(w, (s) => s.replace("old:", "new:"));
  assert.deepEqual(subjects(moved), ["new:1"]);
  assert.equal(logFor(moved, "new:1")[0].e, "new:1");
});

test("migrate: two subjects mapped to the same target UNION their rows (G-Set, nothing overwritten)", () => {
  let w = emptyWorld();
  w = admitLog(w, "a1", [P("a1", "solid", "wall", 1)]).world;
  w = admitLog(w, "a2", [P("a2", "solid", "wall", 2)]).world;
  const moved = migrate(w, () => "merged");
  assert.equal(logFor(moved, "merged").length, 2);
});
