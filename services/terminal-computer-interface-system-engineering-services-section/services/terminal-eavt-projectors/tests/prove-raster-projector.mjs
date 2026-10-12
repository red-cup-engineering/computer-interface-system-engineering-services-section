// prove-projector — THE LAW for the PIXEL projector seam. project(section) -> a Framebuffer that
// paints the four values honestly: t green, f red (denied-NOT-blank), ⊤ a SPLIT band (both faces,
// no winner), ⊥ dim grey. Proven against a hand-built section AND a REAL settled section folded by
// @red-cup-engineering/eavt-services-section's fold/section (opts.converse — the legacy TAB-lineage compatibility
// lane), so the seam is proven against the actual { affirmed, denied, contradicted } shape it must
// promote to consume. Also proves the diffed blit picks an encoder and re-paints only changed tiles.

import { foldEavtEvidence, sectionEavtEvidence } from "@red-cup-engineering/eavt-services-section";
import { project, projectFiber, READING_COLOR, GLYPH } from "../src/raster.mjs";
import { blit } from "@red-cup-engineering/daleske/blit";
import { ok, eq, includes, done } from "./_harness.mjs";

// === glyph alphabet matches arnold's four-value alphabet ======================================
eq([GLYPH.affirmed, GLYPH.denied, GLYPH.contradicted, GLYPH.pending], ["t", "f", "⊤", "⊥"],
  "the glyph table is the four-value alphabet (same as arnold)");

// === project a hand-built section =============================================================
const sec = {
  affirmed: [{ predicate: "material", object: "oak" }],
  denied: [{ predicate: "locked", object: "true" }],
  contradicted: [{ predicate: "located-in", object: "hall" }],
  pending: [{ predicate: "haunted", object: "true" }],
};
const frame = project(sec, { width: 200, bandH: 20 });

eq(frame.census, { affirmed: 1, denied: 1, contradicted: 1, pending: 1 }, "the census counts all four values");
eq(frame.rows.length, 4, "every cell of the section reaches the raster — nothing is silently dropped");
eq(frame.rows[0].reading, "contradicted", "the contested band leads the frame (most salient, not hidden)");

const byReading = Object.fromEntries(frame.rows.map((r) => [r.reading, r]));

// pixel-read helper: sample the center of a band's left and right halves.
const fb = frame.fb;
const sample = (row, frac) => fb.getPixel(Math.floor(frame.width * frac), row.y + Math.floor(row.h / 2));

// t — a green band
{
  const [r, g, b] = sample(byReading.affirmed, 0.5);
  eq([r, g, b], READING_COLOR.affirmed, "an affirmed band is painted the affirmed (green) color");
}
// f — a red band (denied-NOT-blank: the pixels are PAINTED, not left as ground)
{
  const [r, g, b, a] = sample(byReading.denied, 0.5);
  eq([r, g, b], READING_COLOR.denied, "a denied band is painted the denied (red) color, not left blank");
  ok(a === 255, "the denied band is opaque — a counter-belief shown, not absence");
}
// ⊤ — CONTESTED: left half affirmed-green, right half denied-red, BOTH faces, no winner
{
  const left = sample(byReading.contradicted, 0.25);
  const right = sample(byReading.contradicted, 0.75);
  eq([left[0], left[1], left[2]], READING_COLOR.affirmed, "the contested band paints the affirmed face on the LEFT");
  eq([right[0], right[1], right[2]], READING_COLOR.denied, "the contested band paints the denied face on the RIGHT — both faces, no winner");
  ok(byReading.contradicted.contested, "the contested row is flagged contested for a caption layer");
}
// ⊥ — a dim grey band (present, not dropped)
{
  const [r, g, b, a] = sample(byReading.pending, 0.5);
  eq([r, g, b], READING_COLOR.pending, "a pending band is painted the pending (grey) color");
  ok(a < 255, "the pending band is dim (known-absent, shown faintly, not dropped)");
}

// === against a REAL settled section from @561-group/computer ==================================
const rows = [
  { e: "door", a: "material", v: "oak", t: 1 },
  { e: "door", a: "located-in", v: "hall", t: 2 },
  { e: "door", a: "absent-from", v: "hall", t: 3 }, // converse => ⊤ with located-in hall
];
const folded = foldEavtEvidence({ subject: "door", rows, converse: { "absent-from": "located-in" } });
const realSection = sectionEavtEvidence({ folded });
eq(realSection.contradicted, [{ predicate: "located-in", object: "hall" }],
  "the substrate settles told-both to the contradicted bucket");

const realFrame = project(realSection, { width: 120, bandH: 16 });
const realContested = realFrame.rows.find((r) => r.reading === "contradicted");
ok(realContested, "projecting a real settled section yields a contested band");
{
  const fb2 = realFrame.fb;
  const yMid = realContested.y + Math.floor(realContested.h / 2);
  const left = fb2.getPixel(Math.floor(realFrame.width * 0.25), yMid);
  const right = fb2.getPixel(Math.floor(realFrame.width * 0.75), yMid);
  eq([left[0], left[1], left[2]], READING_COLOR.affirmed, "the real contested band shows the affirmed face (left)");
  eq([right[0], right[1], right[2]], READING_COLOR.denied, "the real contested band shows the denied face (right) — no winner picked");
}

// projectFiber surfaces ⊥ (which section() omits)
const fiberFrame = projectFiber(folded);
ok(fiberFrame.census.affirmed >= 1, "projectFiber yields the affirmed cells");
ok(fiberFrame.rows.length >= realFrame.rows.length, "projectFiber surfaces at least as many bands (incl. any ⊥)");

// === the diffed blit picks an encoder and re-paints only changed tiles ========================
// kitty: a changed frame emits APC graphics; an identical next frame emits nothing.
const k1 = blit(null, frame.fb, { encoder: "kitty" });
ok(k1.full && k1.tiles > 0, "first blit is a full paint over every tile");
includes(k1.out, "\x1b_G", "the kitty blit emits APC graphics escapes");

const same = project(sec, { width: 200, bandH: 20 });
const k2 = blit(frame.fb, same.fb, { encoder: "kitty" });
eq(k2.tiles, 0, "re-blitting an identical frame paints NO tiles (the diff is the savings)");
eq(k2.out, "", "an unchanged frame emits no bytes");

// sixel fallback: same frame, sixel encoder emits a DCS, not an APC.
const s1 = blit(null, frame.fb, { encoder: "sixel" });
includes(s1.out, "\x1bP", "the sixel blit falls back to DCS sixel escapes");

// none: the text-fallback encoder emits no raster.
const n1 = blit(null, frame.fb, { encoder: "none" });
eq(n1.out, "", "the 'none' encoder emits no raster (a text drawer handles the frame)");

// rejects a malformed section
let threw = false;
try { project(null); } catch { threw = true; }
ok(threw, "project rejects a non-section input");

done("prove-projector");
