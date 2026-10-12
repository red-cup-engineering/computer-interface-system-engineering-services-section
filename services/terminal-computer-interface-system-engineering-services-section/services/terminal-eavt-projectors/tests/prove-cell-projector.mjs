// prove-projector — THE LAW for the terminal projector seam. The section -> frame projection renders
// the four values honestly: t asserted, f denied-NOT-absent, ⊤ CONTESTED with BOTH sides shown and
// both witnesses surfaced (never silently picking a winner), ⊥ pending. We prove it twice: against a
// hand-built section, and against a REAL settled section folded by @red-cup-engineering/eavt-services-section's
// fold/section (opts.converse — the legacy TAB-lineage compatibility lane), so the seam is proven
// against the actual { affirmed, denied, contradicted } shape it must promote to consume.

import { foldEavtEvidence, sectionEavtEvidence } from "@red-cup-engineering/eavt-services-section";
import { project, projectFiber, GLYPH } from "../src/cell.mjs";
import { ok, eq, includes, done } from "./_harness.mjs";

// === glyph alphabet matches the four values ==================================================
eq([GLYPH.affirmed, GLYPH.denied, GLYPH.contradicted, GLYPH.pending], ["t", "f", "⊤", "⊥"],
  "the glyph table is the four-value alphabet");

// === project on a hand-built section =========================================================
const sec = {
  affirmed: [{ predicate: "material", object: "oak" }],
  denied: [{ predicate: "locked", object: "true" }],
  contradicted: [{ predicate: "located-in", object: "hall" }],
  pending: [{ predicate: "haunted", object: "true" }],
};
const frame = project(sec, {
  subject: "door",
  witnesses: { "located-in hall": { affirmed: ["wA"], denied: ["wD"] } },
});

eq(frame.census, { affirmed: 1, denied: 1, contradicted: 1, pending: 1 }, "the census counts all four values");

const byReading = Object.fromEntries(frame.rows.map((r) => [r.reading, r]));

// t — asserted
eq(byReading.affirmed.glyph, "t", "an affirmed cell carries the t glyph");
eq(byReading.affirmed.text, "material oak", "an affirmed cell is shown as asserted");

// f — denied, NOT absent
eq(byReading.denied.glyph, "f", "a denied cell carries the f glyph");
includes(byReading.denied.text, "NOT", "a denied cell is shown as a counter-statement, not silently absent");

// ⊤ — CONTESTED: both sides shown, no winner picked
eq(byReading.contradicted.glyph, "⊤", "a contradicted cell carries the ⊤ glyph");
includes(byReading.contradicted.text, "located-in hall", "the contested cell shows the asserted side");
includes(byReading.contradicted.text, "NOT located-in hall", "the contested cell ALSO shows the denied side — both witnesses, no winner");
eq(byReading.contradicted.witnesses, { affirmed: ["wA"], denied: ["wD"] }, "the contested cell surfaces BOTH witnesses (the why?)");

// ⊥ — pending
eq(byReading.pending.glyph, "⊥", "a pending cell carries the ⊥ glyph");
includes(byReading.pending.text, "?", "a pending cell is shown as unknown, not dropped");

// THE LAW: contested rows lead (salience), and nothing is hidden — every bucket reaches the frame
eq(frame.rows[0].reading, "contradicted", "the contested cell leads the frame (most salient, not hidden)");
eq(frame.rows.length, 4, "every cell of the section reaches the frame — nothing is silently dropped");

// === against a REAL settled section from @red-cup-engineering/eavt-services-section ============================
// A trace told a claim AND its converse settles the cell to ⊤. This proves the seam consumes the
// substrate's actual fold/section output.
const rows = [
  { e: "door", a: "material", v: "oak", t: 1 },
  { e: "door", a: "located-in", v: "hall", t: 2 },   // asserted
  { e: "door", a: "absent-from", v: "hall", t: 3 },  // converse => denied face => ⊤ together
];
const folded = foldEavtEvidence({ subject: "door", rows, converse: { "absent-from": "located-in" } });
const realSection = sectionEavtEvidence({ folded });

// the substrate itself settles the cell to contradicted
eq(realSection.contradicted, [{ predicate: "located-in", object: "hall" }],
  "the substrate settles told-both to the contradicted bucket");

// project the substrate's section shape directly
const realFrame = project(realSection, { subject: "door" });
const realContested = realFrame.rows.find((r) => r.reading === "contradicted");
ok(realContested, "projecting a real settled section yields a contested row");
includes(realContested.text, "located-in hall", "the real contested row shows the asserted side");
includes(realContested.text, "NOT located-in hall", "the real contested row shows the denied side too");

// projectFiber surfaces ⊥ (which section() omits) AND carries the real witnesses
const fiberFrame = projectFiber(folded);
const fiberContested = fiberFrame.rows.find((r) => r.reading === "contradicted");
ok(fiberContested.witnesses.affirmed.length >= 1 && fiberContested.witnesses.denied.length >= 1,
  "projectFiber surfaces BOTH the affirmed and denied witnesses from the real fold");

// rejects a malformed section
let threw = false;
try { project(null); } catch { threw = true; }
ok(threw, "project rejects a non-section input");

done("prove-projector");
