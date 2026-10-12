// projector — THE SEAM. A PURE function from a @561-group/computer settled section to a renderable
// terminal FRAME. This is arnold's analogue of shp (the HTML projector at computer/L8): shp maps a
// subject's valued cells to an RFC-7992 HTML document; `project` maps a settled section to a frame
// of styled lines a terminal can light up.
//
// IMPORTANT — PROMOTION BOUNDARY. This module depends on NOTHING in arnold's framework (no buffer,
// no widgets, no ansi I/O). It takes a section and returns a plain data frame: rows of
// { text, glyph, reading, style? } records. That keeps the seam clean so it can later be PROMOTED
// into computer/ as the terminal projector (the way shp lives in computer/), with arnold's widgets
// merely DRAWING the frame. Until then it lives here, app-side, but it is written to move.
//
// THE LAW (the acceptance test mirrored from the paraconsistent-web note): the projection renders
// the FOUR values honestly and never silently picks a winner —
//   t (affirmed)     -> asserted, glyph "t"
//   f (denied)       -> denied-not-absent (a counter-stated belief), glyph "f"
//   ⊤ (contradicted) -> CONTESTED: BOTH sides shown, both witnesses surfaced, glyph "⊤". The frame
//                       NEVER drops one face of a contradiction. This is the radical part.
//   ⊥ (pending)      -> pending/unknown (known-absent, not dropped), glyph "⊥"
//
// Input: a settled section { affirmed, denied, contradicted }, each a list of { predicate, object }
// (the OUTPUT of @561-group/computer's `section(fold(...))`). Optionally a `pending` list of the
// same shape for ⊥ cells (section() omits ⊥ as having no evidence; a caller that wants them shown
// passes them through, or hands the raw fold via projectFiber below). Optional `witnesses`: a map
// keyed by `${predicate} ${object}` -> { affirmed:[ids], denied:[ids] } to surface provenance.
//
// Output: a FRAME { subject?, rows: [{ text, glyph, reading, predicate, object, witnesses? }] }.
// `reading` is the value name: "affirmed" | "denied" | "contradicted" | "pending". The frame carries
// no terminal escapes; a renderer (arnold's widgets, or a future computer terminal projector)
// chooses styling from `reading`.

export const GLYPH = Object.freeze({
  affirmed: "t",
  denied: "f",
  contradicted: "⊤",
  pending: "⊥",
});

// The default styling table from reading -> a arnold/ansi style record. A renderer may override it;
// it is data, so the promotion boundary stays clean (the projector names readings, not colors).
export const DEFAULT_READING_STYLE = Object.freeze({
  affirmed: { fg: "green" },
  denied: { fg: "red" },
  contradicted: { fg: "yellow", bold: true },
  pending: { fg: "bright-black", dim: true },
});

const witnessKey = (predicate, object) => `${predicate} ${object}`;

// one cell -> one frame row. The text reads the predication; for a CONTESTED cell the text shows
// BOTH faces so a glance reads the disagreement, and the witnesses (if supplied) ride along so the
// row can be asked "why?". A denied cell is shown as an explicit counter-statement (NOT absence).
function cellRow(cell, reading, witnesses) {
  const { predicate, object } = cell;
  const hasObject = object !== undefined && object !== null && object !== "";
  const claim = hasObject ? `${predicate} ${object}` : `${predicate}`;
  const w = witnesses?.[witnessKey(predicate, object)];
  let text;
  switch (reading) {
    case "affirmed":
      text = claim;
      break;
    case "denied":
      // denied-not-absent: a struck/counter-stated fact, shown, never silently dropped.
      text = `NOT ${claim}`;
      break;
    case "contradicted":
      // THE LAW: both sides shown, the disagreement made visible, no winner picked.
      text = `${claim}  ✗⊢  NOT ${claim}`;
      break;
    case "pending":
      text = `${claim} ?`;
      break;
    default:
      text = claim;
  }
  return {
    predicate, object, reading,
    glyph: GLYPH[reading],
    text,
    ...(w ? { witnesses: w } : {}),
  };
}

// project(section, opts) — the seam. Maps a settled section to a frame. Order is honest about
// salience: CONTESTED first (the contradictions you must not miss), then affirmed, then denied,
// then pending — but every bucket present in the section reaches the frame; nothing is hidden.
export function project(section, opts = {}) {
  if (!section || typeof section !== "object") {
    throw new TypeError("project: section must be { affirmed, denied, contradicted }");
  }
  const witnesses = opts.witnesses;
  const affirmed = section.affirmed ?? [];
  const denied = section.denied ?? [];
  const contradicted = section.contradicted ?? [];
  const pending = section.pending ?? opts.pending ?? [];

  const rows = [];
  for (const c of contradicted) rows.push(cellRow(c, "contradicted", witnesses));
  for (const c of affirmed) rows.push(cellRow(c, "affirmed", witnesses));
  for (const c of denied) rows.push(cellRow(c, "denied", witnesses));
  for (const c of pending) rows.push(cellRow(c, "pending", witnesses));

  return {
    subject: opts.subject ?? section.subject,
    rows,
    // a small honest census so a status line can announce the four-value population at a glance
    census: {
      affirmed: affirmed.length,
      denied: denied.length,
      contradicted: contradicted.length,
      pending: pending.length,
    },
  };
}

// projectFiber(folded, opts) — convenience for callers holding a fold OUTPUT ({ entity, fiber })
// rather than a section. It derives the four buckets directly from each cell's reading bits, so ⊥
// cells (which section() omits) ARE surfaced as pending. The fiber cell shape is
// { predicate, object, value: { pos, neg, evidence:[posIds,negIds] } }. This keeps the projector
// able to honor ⊥ honestly even though the finite section drops it.
export function projectFiber(folded, opts = {}) {
  if (!folded || !Array.isArray(folded.fiber)) {
    throw new TypeError("projectFiber: expected a fold output { entity, fiber }");
  }
  const section = { affirmed: [], denied: [], contradicted: [], pending: [] };
  const witnesses = {};
  for (const c of folded.fiber) {
    const { pos, neg } = c.value;
    const cell = { predicate: c.predicate, object: c.object };
    if (pos && neg) section.contradicted.push(cell);
    else if (pos) section.affirmed.push(cell);
    else if (neg) section.denied.push(cell);
    else section.pending.push(cell);
    const ev = c.value.evidence;
    if (ev) witnesses[witnessKey(c.predicate, c.object)] = { affirmed: ev[0] ?? [], denied: ev[1] ?? [] };
  }
  return project(section, { subject: folded.entity, witnesses, ...opts });
}
