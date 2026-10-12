// world — the engine's WORLD substrate, the PIXEL/voxel sibling of tsander's. A federated append-only
// trace where a "place" is a subject whose state is the FOLD of every predication filed about it. Where
// tsander reads a STAR SYSTEM as a subject (a point in space-flight), abrash reads a VOXEL — a cell of
// the raycast grid — as a subject: its facts are rows (e,a,v), and the section you experience is the
// per-observer fold of the federated union of every trace that reaches it.
//
// It re-derives NOTHING about federation or the bilattice fold — it composes two pieces, both from the
// published @red-cup-engineering/computer:
//   - ./distribution        : the tensor ∥ (G-Set union — no coordinator, no clock, no last-write-wins)
//       + the per-observer read-lens (frontier/sectionOf/disagreements).
// The engine adds only its DOMAIN reading: a voxel is a subject; its reading over a predicate/object cell
// is the bilattice value; an un-scanned voxel is ⊥ (no evidence, fog you cannot see through); a voxel
// two traces DISAGREE about (one says `solid wall`, the other its converse) is ⊤ — HELD, both witnesses.
//
// THE LAW, restated for this file: state is an append-only trace of {e,a,v,t} rows; identity is content;
// ⊤ is HELD (never collapsed), evidence is linear (no witness dropped). Pure over the substrate — bytes
// on disk are a caller's concern (this package ships no bin/; a browser face reads a seed .jsonl
// directly).

import {
  emptyWorld, federate, mergeWorlds, admitLog,
  migrateSubjects as migrate,
  subjects, logFor, allRows, frontier, sectionOf,
  disagreements as federateDisagreements,
} from "@red-cup-engineering/computer/distribution";
// `migrate` here is @red-cup-engineering/computer's migrateSubjects — the bulk namespace re-key
// abrash needs (distinct from that package's own `migrate`, a single-entity crossing between two
// worlds); aliased to keep this module's own established public name and behavior.
import { eavtRow as assertRow } from "@red-cup-engineering/eavt-services-section/admit-row";
import { readingOfSides } from "@red-cup-engineering/computer-data-engineering-services-section/four";
import { FOUR, gridFromCells, registerWorldGridReader } from "./grid.mjs";

export { FOUR, gridFromCells } from "./grid.mjs";

// Each FOUR point, as four names it from its told sides, in the renderer's code.
const CODE_OF_POINT = new Map([[false, false, FOUR.BOT], [true, false, FOUR.T], [false, true, FOUR.F], [true, true, FOUR.TOP]]
  .map(([pos, neg, code]) => [readingOfSides("extremal", pos, neg), code]));

/** The point a folded cell value reads at (computer-data four `readingOfSides`), in the renderer's code. */
export const readingOf = (value) => CODE_OF_POINT.get(readingOfSides("extremal", Boolean(value?.pos), Boolean(value?.neg)));

// re-export the federation surface the engine builds on, so a consumer imports one module.
export {
  emptyWorld, federate, mergeWorlds, admitLog, migrate,
  subjects, logFor, allRows, frontier, sectionOf,
  assertRow,
};

// ── building a world ──────────────────────────────────────────────────────────────────────────
// A row is exactly {e,a,v,t}. `predicate(s,p,o,t)` builds one positive predication; `deny(s,p,o,t)`
// builds the CONVERSE predication that readings the negative face (negative evidence is the converse
// predication, never a polarity field). The default converse map names `not-<p>` as the converse of
// `<p>`, so two traces that disagree — A says `solid wall`, B says the converse — fold to ⊤ on the
// same cell, and the raycaster then renders that voxel DOUBLED and SHIVERING.
export const CONVERSE = Object.freeze({
  "not-solid": "solid",
  "not-at-cell": "at-cell",
  "not-tint": "tint",
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
// settleOpts() — the domain knowledge the fold needs: the converse map, plus the FUNCTIONAL predicates
// (single-valued over time; latest-t row wins the read). `at-cell` is functional — a unit occupies one
// cell — but `solid`/`hazard` are NOT (a contested voxel is solid in BOTH witnesses, held ⊤).
export function settleOpts(opts = {}) {
  return {
    converse: { ...CONVERSE, ...(opts.converse ?? {}) },
    functional: opts.functional ?? new Set(["at-cell"]),
    ...(opts.retract !== undefined ? { retract: opts.retract } : {}),
  };
}

// disagreements(world, opts) — every ⊤ cell across the federated world, read with the ENGINE's domain
// knowledge (converse map + functional set), so `solid` vs `not-solid` is seen as ONE contested cell.
// Each entry carries both witnesses, so disagreement is an enumerable VALUE, never an error.
export function disagreements(world, opts = {}) {
  return federateDisagreements(world, settleOpts(opts));
}

// place(world, subject, opts) — the engine's central read: fold the federated trace at `subject` and
// return the place's settled state — its fiber, the finite section, whether it has been SCANNED at all
// (any evidence => not ⊥), and its contested cells (⊤). This is what the raycaster paints per voxel.
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
    visited,            // false => the voxel is ⊥ fog (un-scanned, pure potential)
    reading: visited ? (contested.length ? FOUR.TOP : FOUR.T) : FOUR.BOT,
  };
}

// cellKey(x, z) — the canonical subject name for the voxel at grid (x,z) on the floor plane. The world
// trace keys solidity per voxel under this name, so two peers can disagree about ONE named cell. (The
// raycast grid is on the floor: x across, z into the scene; height is the wall, not a third grid axis.)
export const cellKey = (x, z) => `voxel:${x | 0},${z | 0}`;

// solidityAt(world, x, z, opts) — read the voxel at grid (x,z): its FOUR reading over the `solid`
// predicate. t => a solid wall (cast stops); f => carved-open (a denied wall, passable); ⊥ => un-scanned
// fog (NOT solid — you have no evidence, so the ray passes, but the renderer may fog it); ⊤ => contested
// (both peers witness a wall — the ray STOPS on it and the column is drawn shivering). Returns
// { reading, place }.
export function solidityAt(world, x, z, opts = {}) {
  const subject = cellKey(x, z);
  const o = settleOpts(opts);
  const folded = frontier(world, subject, o);
  const cell = folded.fiber.find((c) => c.predicate === "solid");
  const reading = cell ? readingOf(cell.value) : FOUR.BOT;
  return { reading, subject };
}

// grid(world, opts) — read the whole voxel field into a dense map keyed by "x,z" -> { reading, x, z }.
// Only voxels with `solid` evidence (any face) appear; everything else is implicit ⊥ fog. This is the
// bridge from the WORLD to the RAYCASTER: the caster walks the DDA and asks the grid per step.
export function grid(world, opts = {}) {
  const cells = new Map();
  for (const subject of subjects(world)) {
    const m = /^voxel:(-?\d+),(-?\d+)$/.exec(subject);
    if (!m) continue; // a non-voxel subject (a unit, lore) is not part of the grid
    const x = Number(m[1]), z = Number(m[2]);
    const { reading } = solidityAt(world, x, z, opts);
    if (reading === FOUR.BOT) continue; // no solidity evidence — leave it implicit fog
    cells.set(`${x},${z}`, { x, z, reading });
  }
  return gridFromCells(cells, FOUR.BOT);
}

registerWorldGridReader(grid);
