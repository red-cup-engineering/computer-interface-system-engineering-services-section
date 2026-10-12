// kitty — an encoder for the KITTY GRAPHICS PROTOCOL. Pure: (RGBA pixels, w, h, opts) -> the escape
// string a kitty-capable terminal consumes to show that image. No I/O, no node:tty. This is the
// pixel analogue of arnold/ansi: the one module that knows the byte grammar of a graphics escape,
// so the blit can reason about a frame as DATA (tiles of pixels) and serialize here once.
//
// The protocol carries an image inside an APC sequence:  ESC _ G <key=val,...> ; <base64 payload>
// ESC \  . We transmit f=32 (32-bit RGBA), give the explicit pixel size (s=width, v=height), and
// base64 the raw RGBA bytes, CHUNKED at 4096 base64 chars with m=1 (more) / m=0 (last) so a large
// image is split across several APC sequences as the protocol requires. Placement is at the cursor;
// the blit moves the cursor first (it owns layout), so this module is position-agnostic.

const ESC = "\x1b";
const APC_OPEN = `${ESC}_G`;
const APC_CLOSE = `${ESC}\\`;
const CHUNK = 4096; // max base64 chars per APC sequence (the protocol's transmission limit)

// base64 of a byte array, via node's Buffer (a node builtin — no dep).
function base64(bytes) {
  return Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength).toString("base64");
}

// encodeImage(pixels, width, height, opts) — the core. `pixels` is a tightly-packed RGBA
// Uint8(Clamped)Array of length width*height*4. opts:
//   id      — an image id (i=) so a later transmission can address/replace it (default omitted)
//   action  — "T" transmit-and-display (default), "t" transmit-only, "p" put a transmitted id
//   quiet   — suppress the terminal's response (q=2), default true (a renderer wants no chatter)
// Returns the full multi-APC escape string. Throws if the pixel length is inconsistent with w*h.
export function encodeImage(pixels, width, height, opts = {}) {
  const w = width | 0, h = height | 0;
  if (pixels.length !== w * h * 4) {
    throw new RangeError(`kitty.encodeImage: expected ${w * h * 4} RGBA bytes, got ${pixels.length}`);
  }
  const action = opts.action ?? "T";
  const payload = base64(pixels);

  // control keys carried on the FIRST chunk only: format 32-bit RGBA, explicit pixel size, action.
  const head = [`a=${action}`, "f=32", `s=${w}`, `v=${h}`];
  if (opts.id != null) head.push(`i=${opts.id | 0}`);
  if (opts.quiet ?? true) head.push("q=2");

  let out = "";
  if (payload.length === 0) {
    // a zero-pixel (empty edge) image: still a well-formed, single, terminal APC.
    return `${APC_OPEN}${head.join(",")},m=0;${APC_CLOSE}`;
  }
  for (let off = 0; off < payload.length; off += CHUNK) {
    const slice = payload.slice(off, off + CHUNK);
    const more = off + CHUNK < payload.length ? 1 : 0;
    if (off === 0) {
      out += `${APC_OPEN}${head.join(",")},m=${more};${slice}${APC_CLOSE}`;
    } else {
      // continuation chunks carry ONLY m= (the protocol forbids repeating the control keys)
      out += `${APC_OPEN}m=${more};${slice}${APC_CLOSE}`;
    }
  }
  return out;
}

// deleteImage(id) — the escape that removes a placed image by id (a=d,i=<id>). Used when a tile that
// previously held an image must be cleared rather than overdrawn.
export function deleteImage(id) {
  return `${APC_OPEN}a=d,i=${id | 0},q=2${APC_CLOSE}`;
}

// deleteAll() — clear all images (a=d, no id). The screen teardown uses it to leave a clean terminal.
export function deleteAll() {
  return `${APC_OPEN}a=d,q=2${APC_CLOSE}`;
}

// chunkCount(pixels) — how many APC sequences encodeImage will emit for this payload. Exposed so a
// test can prove the chunking math without parsing the escape stream.
export function chunkCount(pixels) {
  const len = base64(pixels).length;
  return len === 0 ? 1 : Math.ceil(len / CHUNK);
}
