// prove-framebuffer — the RGBA raster and its TILE diff (the pixel analogue of arnold's buffer diff).
// Proves: pixels round-trip, fillRect/blit compose, tilePixels packs an edge tile tightly, and the
// diff reports a full repaint on first paint / dimension change and ONLY the changed tiles otherwise.

import { Framebuffer, diff, tilesEqual } from "../src/framebuffer.mjs";
import { ok, eq, done } from "./_harness.mjs";

// === pixel round-trip + bounds ===============================================================
const fb = new Framebuffer(10, 8, 4);
fb.setPixel(3, 2, 10, 20, 30, 200);
eq(fb.getPixel(3, 2), [10, 20, 30, 200], "a written pixel reads back exactly");
eq(fb.getPixel(-1, 0), [0, 0, 0, 0], "an out-of-bounds read is transparent black");
fb.setPixel(99, 99, 1, 1, 1); // no-op, must not throw
ok(true, "an out-of-bounds write is a silent no-op");

// === tile grid + tight packing ===============================================================
eq([fb.cols, fb.rows], [3, 2], "a 10x8 raster at tile=4 has 3x2 tiles (ceil on the partial edge)");
eq(fb.tileRect(2, 1), { x: 8, y: 4, w: 2, h: 4 }, "the bottom-right tile is clipped to the 10x8 edge");
const tp = fb.tilePixels(2, 1);
eq(tp.length, 2 * 4 * 4, "tilePixels packs the edge tile tightly (w*h*4 bytes, not a full tile)");

// === fillRect + blit ==========================================================================
const a = new Framebuffer(8, 8, 4);
a.fillRect(0, 0, 4, 4, 255, 0, 0, 255);
eq(a.getPixel(1, 1), [255, 0, 0, 255], "fillRect paints inside the rect");
eq(a.getPixel(5, 5), [0, 0, 0, 0], "fillRect leaves pixels outside the rect untouched");
const small = new Framebuffer(2, 2, 4);
small.fillRect(0, 0, 2, 2, 0, 0, 255, 255);
a.blit(small, 6, 6);
eq(a.getPixel(6, 6), [0, 0, 255, 255], "blit copies a sub-framebuffer at the offset");

// === the TILE diff ============================================================================
// first paint: prev null => full, every tile changed.
const d0 = diff(null, a);
ok(d0.full, "first paint (prev=null) is a full repaint");
eq(d0.tiles.length, a.cols * a.rows, "a full repaint changes every tile");

// no change: a copy of `a` diffs to zero tiles.
const aCopy = new Framebuffer(8, 8, 4);
aCopy.data.set(a.data);
const dSame = diff(a, aCopy);
ok(!dSame.full, "an identical next frame is not a full repaint");
eq(dSame.tiles.length, 0, "an identical next frame changes NO tiles (the diff is the savings)");

// one pixel changes => exactly its tile is reported, others spared.
const aMut = new Framebuffer(8, 8, 4);
aMut.data.set(a.data);
aMut.setPixel(5, 5, 1, 2, 3, 255); // tile (1,1) at tile=4
const dOne = diff(a, aMut);
eq(dOne.tiles, [{ col: 1, row: 1 }], "changing one pixel reports ONLY its tile — the rest are spared");
ok(tilesEqual(a, aMut, 0, 0), "an untouched tile compares equal across the two frames");
ok(!tilesEqual(a, aMut, 1, 1), "the touched tile compares unequal");

// dimension change => full repaint.
const dDim = diff(a, new Framebuffer(16, 8, 4));
ok(dDim.full, "a dimension change forces a full repaint");

done("prove-framebuffer");
