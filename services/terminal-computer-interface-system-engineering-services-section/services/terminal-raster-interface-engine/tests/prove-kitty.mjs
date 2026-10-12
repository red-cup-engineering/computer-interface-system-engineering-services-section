// prove-kitty — the kitty graphics protocol encoder. Proves: a well-formed APC envelope (ESC _ G ...
// ; payload ESC \), 32-bit RGBA format with explicit pixel size, base64 payload that round-trips to
// the original bytes, correct CHUNKING of a large image across multiple m=1.../m=0 APCs, and a length
// guard.

import { encodeImage, deleteImage, deleteAll, chunkCount } from "../src/kitty.mjs";
import { ok, eq, includes, done } from "./_harness.mjs";

const ESC = "\x1b";

// === envelope + control keys ==================================================================
const px = Uint8ClampedArray.from([1, 2, 3, 255, 4, 5, 6, 255]); // 2x1 RGBA
const out = encodeImage(px, 2, 1);
includes(out, `${ESC}_G`, "the encoding opens an APC graphics sequence (ESC _ G)");
includes(out, `${ESC}\\`, "the encoding closes the APC sequence (ESC \\)");
includes(out, "f=32", "the format is 32-bit RGBA (f=32)");
includes(out, "s=2", "the explicit pixel width is carried (s=2)");
includes(out, "v=1", "the explicit pixel height is carried (v=1)");
includes(out, "a=T", "the default action is transmit-and-display (a=T)");

// === base64 payload round-trips to the original bytes =========================================
// extract the payload between the first ';' and the closing ESC\ of the (single) APC.
const semi = out.indexOf(";");
const close = out.indexOf(`${ESC}\\`);
const b64 = out.slice(semi + 1, close);
const back = Buffer.from(b64, "base64");
eq([...back], [...px], "the base64 payload round-trips back to the original RGBA bytes");

// === length guard =============================================================================
let threw = false;
try { encodeImage(px, 3, 3); } catch { threw = true; }
ok(threw, "encodeImage rejects a pixel length inconsistent with width*height");

// === chunking a large image ===================================================================
// >4096 base64 chars forces >1 APC. 4096 b64 chars == 3072 bytes == 768 RGBA pixels; use more.
const big = new Uint8ClampedArray(2000 * 4); // 2000 px => ~10666 b64 chars => 3 chunks
for (let i = 0; i < big.length; i++) big[i] = i & 255;
const n = chunkCount(big);
ok(n >= 2, "a large image chunks into multiple APC sequences");
const bigOut = encodeImage(big, 2000, 1);
const apcCount = bigOut.split(`${ESC}_G`).length - 1;
eq(apcCount, n, "the encoded stream contains exactly chunkCount APC sequences");
includes(bigOut, "m=1", "non-final chunks are marked more (m=1)");
includes(bigOut, "m=0", "the final chunk is marked last (m=0)");
// continuation chunks must NOT repeat the control keys (only the first carries f=/s=/v=).
eq(bigOut.split("f=32").length - 1, 1, "only the first chunk carries the control keys (f=32 appears once)");

// === delete escapes ===========================================================================
includes(deleteImage(7), "a=d,i=7", "deleteImage(7) emits a delete-by-id escape");
includes(deleteAll(), "a=d", "deleteAll emits a delete escape");

done("prove-kitty");
