#!/usr/bin/env node
// arnold (demo bin) — light up a SETTLED SECTION in the terminal, interactively. This is the
// terminal analogue of opening shp's HTML in a browser: we build a small append-only EAVT trace
// that includes a genuine CONTRADICTION (a claim AND its converse), settle it with
// @red-cup-engineering/eavt-services-section's fold (the legacy opts.converse compatibility lane), project the
// settled section to a frame, and render it — showing ⊤ as contested (both sides), ⊥ as pending,
// never silently picking a winner.
//
// Keys: ↑/↓ move the selection, w toggles the witness ("why?") panel, t cycles which subject is in
// view, q / ctrl-c quits. The demo drives the read -> settle -> PROJECT -> loop rhythm: a keypress
// changes the cut, the world re-settles, the frame re-projects, and only changed cells repaint.

import { foldEavtEvidence, sectionEavtEvidence } from "@red-cup-engineering/eavt-services-section";
import { Screen } from "@red-cup-engineering/arnold/app";
import { box, text, list, statusLine } from "@red-cup-engineering/arnold/widgets";
import { stack, inset, flex } from "@red-cup-engineering/arnold/layout";
import { projectFiber, DEFAULT_READING_STYLE } from "../src/cell.mjs";

// === a sample trace with a real contradiction ===============================================
// Rows are {e,a,v,t}. We declare a converse pair so a converse row readings the NEGATIVE face: told
// BOTH "door located-in hall" AND "door absent-from hall" => that cell settles to ⊤ (contested).
const T = (e, a, v, t) => ({ e, a, v, t });
const traces = {
  door: {
    converse: { "absent-from": "located-in" },
    rows: [
      T("door", "material", "oak", 1),
      T("door", "located-in", "hall", 2),     // a witness says: in the hall
      T("door", "absent-from", "hall", 3),     // another witness says: NOT in the hall  => ⊤
      T("door", "state", "locked", 4),
      T("door", "color", "red", 5),
      T("door", "color", "green", 6),          // told two colors; both held (relational) => both affirmed
    ],
  },
  arnold: {
    converse: { "unlit": "lit" },
    rows: [
      T("arnold", "material", "brass", 1),
      T("arnold", "lit", "true", 2),
      T("arnold", "located-in", "hall", 3),
      T("arnold", "fuel", "oil", 4),
    ],
  },
};

const subjects = Object.keys(traces);

function projectionFor(subject) {
  const { rows, converse } = traces[subject];
  const folded = foldEavtEvidence({ subject, rows, converse });
  const frame = projectFiber(folded);
  return { folded, frame, section: sectionEavtEvidence({ folded }) };
}

// === the interactive view ===================================================================
const screen = new Screen();
let subjectIndex = 0;
let selected = 0;
let showWitness = false;

function view(buf, root) {
  const subject = subjects[subjectIndex];
  const { frame } = projectionFor(subject);
  const rows = frame.rows;
  if (selected >= rows.length) selected = Math.max(0, rows.length - 1);

  const [titleR, bodyR, statusR] = stack(root, [1, null, 1]);
  text(buf, titleR, `arnold — projecting settled section of "${subject}"`, { style: { bold: true } });

  // body splits into the projection list and (optionally) a witness panel
  const cols = showWitness
    ? flex(bodyR, [{ grow: 2 }, { grow: 1 }], { direction: "row", gap: 1 })
    : [bodyR];
  const inner = box(buf, cols[0], { title: "section", style: { fg: "cyan" } });
  const items = rows.map((r) => ({
    text: ` ${r.glyph}  ${r.text}`,
    style: DEFAULT_READING_STYLE[r.reading],
  }));
  list(buf, inner, items, { selected, selectedStyle: { inverse: true } });

  if (showWitness && cols[1]) {
    const wInner = box(buf, cols[1], { title: "witnesses (why?)", style: { fg: "magenta" } });
    const cur = rows[selected];
    const lines = [];
    if (cur) {
      lines.push(`${cur.glyph} ${cur.reading}`, "");
      const w = cur.witnesses || { affirmed: [], denied: [] };
      lines.push(`affirmed by: ${w.affirmed.length}`);
      for (const id of w.affirmed) lines.push(`  + ${String(id).slice(0, 12)}`);
      lines.push(`denied by: ${w.denied.length}`);
      for (const id of w.denied) lines.push(`  - ${String(id).slice(0, 12)}`);
    }
    text(buf, wInner, lines, {});
  }

  const c = frame.census;
  statusLine(buf, statusR, {
    left: `t:${c.affirmed}  f:${c.denied}  ⊤:${c.contradicted}  ⊥:${c.pending}`,
    center: "↑/↓ move · w why · t subject · q quit",
    right: `${selected + 1}/${rows.length}`,
  });
}

screen.start();
screen.render(view);
screen.onKey((k) => {
  const subject = subjects[subjectIndex];
  const { frame } = projectionFor(subject);
  const n = frame.rows.length;
  if (k.name === "up") selected = (selected - 1 + n) % n;
  else if (k.name === "down") selected = (selected + 1) % n;
  else if (k.char === "w") showWitness = !showWitness;
  else if (k.char === "t") { subjectIndex = (subjectIndex + 1) % subjects.length; selected = 0; }
  else if (k.char === "q" || (k.ctrl && k.char === "c")) { screen.stop(); process.exit(0); }
  screen.render(view);
});
screen.onInterrupt(() => { screen.stop(); process.exit(0); });
