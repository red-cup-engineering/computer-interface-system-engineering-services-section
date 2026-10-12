// world — the engine's WORLD substrate: a federated append-only trace where a "place" is a subject
// whose state is the FOLD of every predication filed about it. This is the engine-level lift of the
// Okaga/Tsander design note's §4–§6: a star system (or any unit) is `e`; its facts are the rows
// `(e, a, v)`; the section you experience is the per-observer fold of the federated union of every
// trace that reaches `e`.
//
// It re-derives NOTHING about federation or the bilattice fold — it composes the computer's own
// pieces by name:
//   - @561-group/computer/distribution/federate : the tensor ∥ (G-Set union, no coordinator,
//       no clock, no last-write-wins) + the per-observer read-lens (frontier/sectionOf/disagreements).
//   - @561-group/computer/substrate             : the read→fold→settle spine + relate/relateFrom.
// The engine adds only its DOMAIN reading on top: a place is a subject; its charge over a
// predicate/object cell is the bilattice value; unvisited = ⊥ (no evidence); disagreement = ⊤ (held,
// both witnesses). Those four readings are what the renderer paints and what the tick loop advances.
//
// THE LAW, restated for this file: state is an append-only trace of {e,a,v,t} rows; identity is
// content; ⊤ is HELD (never collapsed), evidence is linear (no witness dropped). Pure over the
// substrate — bytes on disk are the caller's concern (bin/ reads/writes the .jsonl seed).

import {
  emptyWorld, federate, mergeWorlds, admitLog, migrate,
  subjects, logFor, allRows, frontier, sectionOf,
  disagreements as federateDisagreements,
} from "@561-group/computer/distribution/federate";
import { rowId, assertRow, relate, relateFrom } from "@561-group/computer/posix-holography/eavt-substrate";

// re-export the federation surface the engine builds on, so a consumer imports one module.
export {
  emptyWorld, federate, mergeWorlds, admitLog, migrate,
  subjects, logFor, allRows, frontier, sectionOf,
  rowId, assertRow, relate, relateFrom,
};

// ── building a world ──────────────────────────────────────────────────────────────────────────
// A row is exactly {e,a,v,t}. `predicate(s,p,o,t)` builds one positive predication; `deny(s,p,o,t)`
// builds the CONVERSE predication that charges the negative face (the design note: "negative evidence
// is the converse predication, never a polarity field"). The default converse map (`CONVERSE`) names
// `not-<p>` as the converse of `<p>`, so two traces that disagree — A asserts `controlled-by federation`,
// B asserts the converse — fold to ⊤ on the same cell.
export const CONVERSE = Object.freeze({
  "not-controlled-by": "controlled-by",
  "not-has-station": "has-station",
  "not-at-position": "at-position",
  "not-hull": "hull",
  "not-hazard": "hazard",
});

export const predicate = (s, p, o, t = 0) => ({ e: s, a: p, v: o, t });
export const deny = (s, p, o, t = 0) => ({ e: s, a: `not-${p}`, v: o, t });

// worldFromRows(rows) — admit a flat list of {e,a,v,t} rows into a fresh world, filing each under its
// own subject `e` (each row's physical home is its subject). The seed `.jsonl` loads this way.
export function worldFromRows(rows) {
  let w = emptyWorld();
  for (const r of rows ?? []) {
    assertRow(r);
    w = admitLog(w, r.e, [r]).world;
  }
  return w;
}

// ── the engine's per-observer place read ────────────────────────────────────────────────────
// settleOpts() — the domain knowledge the fold needs: the converse map, plus the functional predicates
// (single-valued over time; the latest-t row wins the read). `at-position` is functional — a unit has
// one current position — but `controlled-by`/`hazard` are NOT (a contested star is owned by BOTH, held).
export function settleOpts(opts = {}) {
  return {
    converse: { ...CONVERSE, ...(opts.converse ?? {}) },
    functional: opts.functional ?? new Set(["at-position"]),
    ...(opts.retract !== undefined ? { retract: opts.retract } : {}),
  };
}

// disagreements(world, opts) — every ⊤ cell across the federated world, read with the ENGINE's domain
// knowledge (the converse map + functional set), so `controlled-by` vs `not-controlled-by` is seen as
// one contested cell. A "void-trader" career (the design note) is mining this list: each entry carries
// both witnesses, so disagreement is an enumerable VALUE, never an error.
export function disagreements(world, opts = {}) {
  return federateDisagreements(world, settleOpts(opts));
}

// FOUR — the four engine charges a place's cell can carry, named for the renderer and the tick loop.
export const FOUR = Object.freeze({ T: "t", F: "f", BOT: "bot", TOP: "top" });

// chargeOf(value) — read a fold cell's {pos,neg} into one of the four engine charges. ⊥ is the unvisited
// reading (no evidence at all); ⊤ is the contested reading (both faces witnessed, HELD).
export function chargeOf(value) {
  const pos = value?.pos, neg = value?.neg;
  if (pos && neg) return FOUR.TOP;
  if (pos) return FOUR.T;
  if (neg) return FOUR.F;
  return FOUR.BOT;
}

// place(world, subject, opts) — the engine's central read: fold the federated trace at `subject` and
// return the place's settled state — its fiber of charged cells, the finite section, whether it has
// been VISITED at all (any evidence => not ⊥), and its contested cells (⊤). This is what one tick of
// the cockpit settles and what the projector renders.
export function place(world, subject, opts = {}) {
  const o = settleOpts(opts);
  const folded = frontier(world, subject, o);
  const section = sectionOf(world, subject, o);
  const contested = folded.fiber
    .filter((c) => c.value.pos && c.value.neg)
    .map((c) => ({ predicate: c.predicate, object: c.object, evidence: c.value.evidence }));
  const visited = folded.fiber.length > 0;
  return {
    subject,
    folded,
    section,            // { affirmed, denied, contradicted }
    contested,          // the ⊤ cells, both witnesses kept
    visited,            // false => the place is ⊥ fog (unvisited, pure potential)
    charge: visited ? (contested.length ? FOUR.TOP : FOUR.T) : FOUR.BOT,
  };
}

// positionOf(world, subject, opts) — the unit's current position as a vec3, read from its functional
// `at-position` cell (latest-t wins). Returns null if the place has no position evidence (⊥). The value
// is stored as an [x,y,z] array object in the row's `v`.
export function positionOf(world, subject, opts = {}) {
  const o = settleOpts(opts);
  const vs = relateFrom(logFor(world, subject), subject, "at-position");
  // supersede already handled by frontier's functional set; here we want the settled one:
  const folded = frontier(world, subject, o);
  const cell = folded.fiber.find((c) => c.predicate === "at-position" && c.value.pos);
  const v = cell ? cell.object : (vs.length ? vs[vs.length - 1] : null);
  return Array.isArray(v) && v.length === 3 ? v.map(Number) : null;
}

// renderables(world, opts) — every subject that has an `at-position`, projected to a renderable record
// the wireframe projector consumes: { subject, position:[x,y,z], charge, shape, contested }. A subject
// with no position is not drawable (it is lore, not geometry). `shape` is the unit's `hull` cells, or a
// default unit cube if none is stated. This is the bridge from the WORLD to the RENDERER.
export function renderables(world, opts = {}) {
  const out = [];
  for (const subject of subjects(world)) {
    const pos = positionOf(world, subject, opts);
    if (!pos) continue;
    const p = place(world, subject, opts);
    const hull = relateFrom(logFor(world, subject), subject, "hull");
    out.push({
      subject,
      position: pos,
      charge: p.charge,
      contested: p.contested,
      shape: hull.length ? hull[hull.length - 1] : null, // a shape name or vertex list; projector defaults
    });
  }
  return out.sort((a, b) => a.subject.localeCompare(b.subject));
}
