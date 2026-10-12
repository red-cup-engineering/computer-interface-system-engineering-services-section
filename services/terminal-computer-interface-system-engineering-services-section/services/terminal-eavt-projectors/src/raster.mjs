// projector — THE SEAM. A PURE function from a @561-group/computer settled section to a PIXEL frame.
// This is daleske's analogue of arnold's project (which maps a section to styled terminal lines):
// daleske maps the same settled section to a RASTER — a Framebuffer of colored swatches, one band
// per predication, that a kitty/sixel terminal can light up. Same LAW, different medium.
//
// PROMOTION BOUNDARY — this module depends on NOTHING in daleske's I/O (no blit, no encoder, no
// node:tty). It takes a section and returns a Framebuffer plus a plain `rows` descriptor. That keeps
// the seam clean so it can later be PROMOTED into computer/ as the PIXEL terminal projector, the
// pixel sibling of the cell projector (and of shp, the HTML projector at computer/L8).
//
// THE LAW (mirrored from arnold's projector and the paraconsistent-web note): the projection renders
// the FOUR values honestly and never silently picks a winner —
//   t (affirmed)     -> a solid GREEN band.
//   f (denied)       -> a solid RED band (denied-NOT-absent: a painted counter-belief, not blankness).
//   ⊤ (contradicted) -> CONTESTED: the band is SPLIT — left half affirmed-green, right half
//                       denied-red, with a yellow seam between. BOTH faces painted, no winner. The
//                       raster NEVER drops one face of a contradiction. This is the radical part.
//   ⊥ (pending)      -> a dim GREY band (known-absent, not dropped).
//
// Input: a settled section { affirmed, denied, contradicted } (+ optional pending), each a list of
// { predicate, object } — the OUTPUT of @561-group/computer's section(fold(...)). Output: a FRAME
// { fb, rows, census, width, height } where `fb` is a Framebuffer and `rows` describes each painted
// band ({ reading, predicate, object, y, h, contested? }) so a caption layer (text) can label it.

import { Framebuffer } from "@red-cup-engineering/daleske/framebuffer";

// reading -> RGB swatch. The same color semantics as arnold's DEFAULT_READING_STYLE, in pixels.
export const READING_COLOR = Object.freeze({
  affirmed: [60, 200, 90],      // green
  denied: [210, 60, 60],        // red
  contradicted: [225, 200, 40], // yellow (the seam between the two contested faces)
  pending: [110, 110, 110],     // grey
});

// the glyph alphabet, kept identical to arnold's so the two projectors name the four values alike.
export const GLYPH = Object.freeze({ affirmed: "t", denied: "f", contradicted: "⊤", pending: "⊥" });

const CONTESTED_AFFIRM = READING_COLOR.affirmed;
const CONTESTED_DENY = READING_COLOR.denied;

// project(section, opts) -> frame. opts:
//   width    — frame width in px (default 256)
//   bandH    — height of one predication band in px (default 24)
//   tile     — diff tile size for the framebuffer (default framebuffer default)
//   pending  — extra ⊥ cells to paint (section() omits ⊥; a caller may pass them through)
// Order is honest about salience: CONTESTED bands first (the ⊤ you must not miss), then affirmed,
// denied, pending — but EVERY bucket present reaches the raster; nothing is hidden.
export function project(section, opts = {}) {
  if (!section || typeof section !== "object") {
    throw new TypeError("project: section must be { affirmed, denied, contradicted }");
  }
  const width = opts.width ?? 256;
  const bandH = opts.bandH ?? 24;

  const affirmed = section.affirmed ?? [];
  const denied = section.denied ?? [];
  const contradicted = section.contradicted ?? [];
  const pending = section.pending ?? opts.pending ?? [];

  // build the band descriptors in salience order
  const order = [];
  for (const c of contradicted) order.push({ reading: "contradicted", ...c });
  for (const c of affirmed) order.push({ reading: "affirmed", ...c });
  for (const c of denied) order.push({ reading: "denied", ...c });
  for (const c of pending) order.push({ reading: "pending", ...c });

  const height = Math.max(bandH, order.length * bandH);
  const fb = new Framebuffer(width, height, opts.tile);
  fb.clear(20, 20, 24, 255); // a dark ground so swatches read

  const rows = [];
  let y = 0;
  for (const band of order) {
    const h = bandH;
    if (band.reading === "contradicted") {
      // THE LAW IN PIXELS: split the band — affirmed-green on the left, denied-red on the right,
      // a yellow seam down the middle. Both faces painted, no winner picked, the disagreement made
      // visible at a glance.
      const half = Math.floor(width / 2);
      fb.fillRect(0, y, half, h, ...CONTESTED_AFFIRM, 255);
      fb.fillRect(half + 2, y, width - half - 2, h, ...CONTESTED_DENY, 255);
      fb.fillRect(half - 1, y, 3, h, ...READING_COLOR.contradicted, 255); // the seam
    } else {
      const [r, g, b] = READING_COLOR[band.reading];
      const a = band.reading === "pending" ? 140 : 255; // ⊥ painted dim, still present
      fb.fillRect(0, y, width, h, r, g, b, a);
    }
    rows.push({
      reading: band.reading,
      glyph: GLYPH[band.reading],
      predicate: band.predicate,
      object: band.object,
      y, h,
      contested: band.reading === "contradicted",
    });
    y += h;
  }

  return {
    fb, rows, width, height,
    census: {
      affirmed: affirmed.length,
      denied: denied.length,
      contradicted: contradicted.length,
      pending: pending.length,
    },
  };
}

// projectFiber(folded, opts) -> frame — convenience for callers holding a fold OUTPUT
// ({ entity, fiber }) rather than a section. It derives the four buckets directly from each cell's
// reading bits, so ⊥ cells (which section() omits) ARE painted. The fiber cell shape is
// { predicate, object, value: { pos, neg, evidence } }. Mirrors arnold's projectFiber so the pixel
// projector honors ⊥ honestly even though the finite section drops it.
export function projectFiber(folded, opts = {}) {
  if (!folded || !Array.isArray(folded.fiber)) {
    throw new TypeError("projectFiber: expected a fold output { entity, fiber }");
  }
  const section = { affirmed: [], denied: [], contradicted: [], pending: [] };
  for (const c of folded.fiber) {
    const { pos, neg } = c.value;
    const cell = { predicate: c.predicate, object: c.object };
    if (pos && neg) section.contradicted.push(cell);
    else if (pos) section.affirmed.push(cell);
    else if (neg) section.denied.push(cell);
    else section.pending.push(cell);
  }
  return project(section, { subject: folded.entity, ...opts });
}
