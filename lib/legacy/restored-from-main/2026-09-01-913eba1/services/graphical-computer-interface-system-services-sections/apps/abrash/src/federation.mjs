// federation — the world-of-subjects algebra world.mjs composes on top of the published
// @561-group/computer substrate, using only what that package actually exports:
// `@561-group/computer/posix-holography/eavt-substrate`'s `settle`/`section`/`assertRow`/`dedupe`/
// `rowId`. It never re-derives the fold/settle/bilattice algebra those already provide.
//
// THE WORLD SHAPE: a world is `Map<subject, Row[]>` — plain data, a G-Set (grow-only set) per subject,
// unioned by `federate`. No coordinator, no clock, no last-write-wins: two worlds merge by unioning their
// per-subject row logs and deduping by content-address (`rowId`), so federating a world with itself, or
// merging A-then-B vs B-then-A, gives the same result (order-independent — proven in federation.test.mjs).

// Stays on @561-group/computer (re-confirmed 2026-08-31, eavt 0.4.0 attempted and reverted): TWO
// independent reasons now, not one. (1) settle (-> fold) is where this engine's CONVERSE map
// (world.mjs's CONVERSE, threaded through settleOpts) charges a denial onto its predicate's negative
// face — eavt 0.4.0 now ships that lane (opts.converse) so this reason alone would no longer block a
// move. (2) eavt's rowId/dedupe compose @red-cup-engineering/cbor-codec-service's RFC 8949
// core-deterministic CBOR encoder, which REFUSES a non-safe-integer number outright (it requires
// typed decimal strings for decimals — a deliberate, load-bearing canonicalization law, not a bug).
// This engine's rows carry raw floating-point player/unit positions straight out of continuous AABB
// collision physics (engine.mjs's tick -> admitLog), so `dedupe`/`rowId` on a real trace throws
// `CBOR codec numbers must be safe integers; decimals use typed decimal strings` the first time a
// unit moves off an integer coordinate (reproduced 2026-08-31: engine.test.mts's DETERMINISM test
// fails this way against eavt 0.4.0's rowId). @561-group/computer's own jcs-based rowId/dedupe
// tolerate bare floats, so this import stays there until this package's positions are re-typed for
// canonical CBOR (a numeric-representation migration this task does not attempt) or dedupe/rowId
// gain a float-tolerant path of their own.
import { assertRow, dedupe, settle, section } from "@561-group/computer/posix-holography/eavt-substrate";

// emptyWorld() — a fresh world with no subjects.
export function emptyWorld() {
  return new Map();
}

// logFor(world, subject) — the raw append-only row log filed under `subject` (empty if never admitted).
export function logFor(world, subject) {
  return world.get(subject) ?? [];
}

// subjects(world) — every subject with at least one row.
export function subjects(world) {
  return [...world.keys()];
}

// allRows(world) — every row across every subject, in no particular cross-subject order (subject-local
// order is preserved). Used by callers that scan the whole trace directly (e.g. counting witnesses).
export function allRows(world) {
  const out = [];
  for (const rows of world.values()) out.push(...rows);
  return out;
}

// admitLog(world, subject, rows) — append `rows` to `subject`'s log (G-Set union: content-deduped, nothing
// ever removed or overwritten) and return { world: <new world>, appended: <rows.length> }. Pure: the
// input world is never mutated. Every row is validated with the substrate's own `assertRow` before it is
// admitted, so a malformed {e,a,v,t} row fails loudly here rather than corrupting a later fold.
export function admitLog(world, subject, rows) {
  for (const r of rows) assertRow(r);
  const prior = world.get(subject) ?? [];
  const merged = dedupe([...prior, ...rows]);
  const next = new Map(world);
  next.set(subject, merged);
  return { world: next, appended: rows.length };
}

// federate(a, b) — THE G-SET UNION ∥: merge two worlds by unioning their per-subject logs, deduped by
// content-address. Order-independent and idempotent (federate(a,a) === a's rows, federate(a,b) ===
// federate(b,a) — both proven in federation.test.mjs). Where both worlds hold the SAME row it appears
// once; where they hold CONTRARY rows on the same subject (one predicate, one its converse) both survive
// as distinct rows, and the next `frontier`/`sectionOf` read folds them to ⊤ — a disagreement is an
// enumerable value, not a merge conflict to resolve here.
export function federate(a, b) {
  const subs = new Set([...subjects(a), ...subjects(b)]);
  const out = emptyWorld();
  for (const s of subs) {
    out.set(s, dedupe([...logFor(a, s), ...logFor(b, s)]));
  }
  return out;
}

// mergeWorlds(...worlds) — federate an arbitrary number of worlds left-to-right. federate's
// order-independence means the fold order doesn't affect the result.
export function mergeWorlds(...worlds) {
  return worlds.reduce((acc, w) => federate(acc, w), emptyWorld());
}

// frontier(world, subject, opts) — settle a subject's log into its folded section: exactly
// `settle(subject, logFor(world, subject), opts)` from the published substrate. Named `frontier` (not
// `settle`) to match the vocabulary the legacy `world.mjs` already speaks — the "frontier" is the
// settled edge of the append-only trace a reader currently sees.
export function frontier(world, subject, opts = {}) {
  return settle(subject, logFor(world, subject), opts);
}

// sectionOf(world, subject, opts) — the finite {affirmed, denied, contradicted} shadow of a subject's
// frontier: exactly `section(frontier(world, subject, opts))`.
export function sectionOf(world, subject, opts = {}) {
  return section(frontier(world, subject, opts));
}

// disagreements(world, opts) — every ⊤ (contested) cell across every subject in the federated world: a
// subject the trace holds BOTH an affirm and a converse-deny for, on the same (predicate, object).
// Returns a flat list of { subject, predicate, object, evidence }, one entry per contested cell (a
// subject with two contested predicates yields two entries). This is the general read `world.mjs`'s own
// `disagreements` and `arena.mjs`'s `contestedWalls` both build on.
export function disagreements(world, opts = {}) {
  const out = [];
  for (const subject of subjects(world)) {
    const folded = frontier(world, subject, opts);
    for (const c of folded.fiber) {
      if (c.value.pos && c.value.neg) {
        out.push({ subject, predicate: c.predicate, object: c.object, evidence: c.value.evidence });
      }
    }
  }
  return out;
}

// migrate(world, mapSubject) — rebuild a world with every row's subject renamed through `mapSubject`
// (e.g. re-keying a federated arena's voxel namespace when two peers' coordinate systems are joined
// under a shared prefix). Rows that migrate to the same target subject are unioned (G-Set semantics, same
// as `federate`) rather than one overwriting the other.
export function migrate(world, mapSubject) {
  const out = emptyWorld();
  for (const s of subjects(world)) {
    const to = mapSubject(s);
    const rows = logFor(world, s).map((r) => ({ ...r, e: to }));
    const prior = out.get(to) ?? [];
    out.set(to, dedupe([...prior, ...rows]));
  }
  return out;
}
