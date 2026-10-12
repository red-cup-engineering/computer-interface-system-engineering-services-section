#!/usr/bin/env node
// daleske demo — light up a SETTLED SECTION as a PIXEL scene over kitty/sixel (falling back to a
// text frame when neither is present). It folds a real trace through @red-cup-engineering/eavt-services-section's
// fold (the legacy opts.converse compatibility lane), projects the settled section to a raster via
// the projector SEAM, detects the terminal's raster capability, and blits the frame. A contradicted
// cell paints as a SPLIT band (both faces, no winner) — THE LAW, in pixels.
//
// Usage:  eavt-terminal-raster-demo            # project the demo section
//         eavt-terminal-raster-demo --pattern  # a color test pattern instead
//         DALESKE_ENCODER=sixel eavt-terminal-raster-demo  # force an encoder

import { foldEavtEvidence, sectionEavtEvidence } from "@red-cup-engineering/eavt-services-section";
import { project, GLYPH } from "../src/raster.mjs";
import { Framebuffer } from "@red-cup-engineering/daleske/framebuffer";
import { blitFull } from "@red-cup-engineering/daleske/blit";
import { probe, detectFromEnv } from "@red-cup-engineering/daleske/capability";

// probe() gates on a live TTY (so the screen never blits into a pipe). The demo, though, also wants
// to let a user CAPTURE an encoder's bytes through a pipe — so an explicit DALESKE_ENCODER override
// is honored even when stdout is redirected (detectFromEnv, the pure classification, decides it).
const cap = process.env.DALESKE_ENCODER ? detectFromEnv(process.env) : probe(process.stdout, process.env);
const encoder = cap.encoder;
const wantPattern = process.argv.includes("--pattern");

// a test pattern: horizontal RGB gradient + a white frame. Proves the encoder path with no section.
function testPattern(w = 256, h = 96) {
  const fb = new Framebuffer(w, h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      fb.setPixel(x, y, Math.floor((x / w) * 255), Math.floor((y / h) * 255), 128, 255);
    }
  }
  fb.fillRect(0, 0, w, 2, 255, 255, 255, 255);
  fb.fillRect(0, h - 2, w, 2, 255, 255, 255, 255);
  return { fb, rows: [] };
}

// the demo section: a door whose location is CONTRADICTED (told located-in hall AND its converse),
// material affirmed, locked denied, haunted left pending — one cell of each of the four values.
function demoFrame() {
  const rows = [
    { e: "door", a: "material", v: "oak", t: 1 },
    { e: "door", a: "located-in", v: "hall", t: 2 },
    { e: "door", a: "absent-from", v: "hall", t: 3 }, // converse => ⊤ with located-in hall
    { e: "door", a: "locked", v: "true", t: 4 },
    { e: "door", a: "unlocked", v: "true", t: 5 },    // converse of locked => denied face
  ];
  const folded = foldEavtEvidence({ subject: "door", rows,
    converse: { "absent-from": "located-in", "unlocked": "locked" },
  });
  const sec = sectionEavtEvidence({ folded });
  sec.pending = [{ predicate: "haunted", object: "true" }];
  return project(sec, { width: 256, bandH: 28 });
}

const { fb, rows } = wantPattern ? testPattern() : demoFrame();

// a text caption of the frame (always printed — the audit-on-demand surface), then the raster if the
// terminal can show one. When encoder === "none" the text IS the output (graceful fallback).
function caption() {
  const lines = [];
  lines.push(`daleske — encoder: ${encoder} (${cap.why})`);
  lines.push(`frame: ${fb.width}x${fb.height}px, ${rows.length} band(s)`);
  for (const r of rows) {
    const obj = r.object != null && r.object !== "" ? ` ${r.object}` : "";
    const faces = r.contested ? `  [${r.predicate}${obj}]  ⊢ / ⊬  [NOT ${r.predicate}${obj}]` : `  ${r.predicate}${obj}`;
    lines.push(`  ${GLYPH[r.reading]} ${r.reading.padEnd(13)}${faces}`);
  }
  return lines.join("\n") + "\n";
}

process.stdout.write(caption());

if (encoder === "none") {
  process.stdout.write("(no kitty/sixel terminal detected — text frame above is the fallback)\n");
} else {
  // place the raster below the caption (the cursor is already past the text).
  process.stdout.write(blitFull(fb, { encoder }));
  process.stdout.write("\n");
}
