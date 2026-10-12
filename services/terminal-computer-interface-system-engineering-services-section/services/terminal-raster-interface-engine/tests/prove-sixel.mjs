// prove-sixel — the SIXEL fallback encoder. Proves: a well-formed DCS..ST envelope, palette
// definitions in 0..100 percent space, a length guard, palette quantization that bounds the color
// count, run-length encoding of a solid region (the `!count` form), and that distinct colors yield
// distinct palette entries.

import { encodeImage, paletteSize } from "../src/sixel.mjs";
import { ok, eq, includes, done } from "./_harness.mjs";

const ESC = "\x1b";

// === envelope =================================================================================
const px = Uint8ClampedArray.from([255, 0, 0, 255]); // 1x1 red
const out = encodeImage(px, 1, 1);
includes(out, `${ESC}Pq`, "the encoding opens a sixel DCS (ESC P q)");
includes(out, `${ESC}\\`, "the encoding closes with ST (ESC \\)");
includes(out, "#0;2;100;0;0", "the red pixel defines palette 0 as 100% red in RGB space (;2;)");

// === length guard =============================================================================
let threw = false;
try { encodeImage(px, 2, 2); } catch { threw = true; }
ok(threw, "encodeImage rejects an inconsistent pixel length");

// === distinct colors -> distinct palette entries ==============================================
const two = Uint8ClampedArray.from([255, 0, 0, 255, 0, 0, 255, 255]); // red, blue
eq(paletteSize(two), 2, "two distinct colors yield a two-entry palette");

// === transparent pixels are unlit (not in the palette) ========================================
const withClear = Uint8ClampedArray.from([255, 0, 0, 255, 0, 0, 0, 0]); // red, transparent
eq(paletteSize(withClear), 1, "a fully-transparent pixel is unlit and adds no palette color");

// === quantization bounds the palette ==========================================================
// 300 random-ish colors, capped at 16 -> the palette must not exceed the cap.
const many = new Uint8ClampedArray(300 * 4);
for (let i = 0; i < 300; i++) {
  many[i * 4] = (i * 37) & 255; many[i * 4 + 1] = (i * 91) & 255;
  many[i * 4 + 2] = (i * 53) & 255; many[i * 4 + 3] = 255;
}
ok(paletteSize(many, { maxColors: 16 }) <= 16, "quantization caps the palette at maxColors");

// === run-length encoding of a solid band ======================================================
// a wide solid red strip should RLE its sixel run as `!<count>`.
const wide = new Uint8ClampedArray(20 * 4);
for (let i = 0; i < 20; i++) { wide[i * 4] = 255; wide[i * 4 + 3] = 255; }
const wideOut = encodeImage(wide, 20, 1);
includes(wideOut, "!", "a solid run is run-length encoded (the !count form)");

done("prove-sixel");
