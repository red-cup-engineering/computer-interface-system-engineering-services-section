// blit — the DIFFED pixel paint: turn a framebuffer diff into the minimal raster escape stream,
// placing only the CHANGED tiles via the chosen encoder. This is the pixel analogue of arnold's
// render: arnold walks changed CELLS and emits the fewest ANSI escapes; daleske walks changed TILES
// and emits the fewest graphics-protocol IMAGES. It still does no terminal I/O — it returns the
// byte string the screen writes.
//
// Each changed tile is placed by: move the cursor to the tile's cell position, then transmit the
// tile's pixels as one image. Cursor positioning is in TERMINAL CELLS, so the blit needs the cell
// size in pixels (how many px wide/tall one text cell is) to map a pixel tile to a cursor cell. A
// graphics image is drawn AT the cursor; we therefore align tiles to the cell grid via cellW/cellH.

import { diff } from "./framebuffer.mjs";
import * as kitty from "./kitty.mjs";
import * as sixel from "./sixel.mjs";

const ESC = "\x1b";
const cursorTo = (rowCell, colCell) => `${ESC}[${(rowCell | 0) + 1};${(colCell | 0) + 1}H`; // 1-indexed out

// the encoder table: name -> { encode(pixels,w,h,opts) }. "none" yields no raster output (a text
// drawer handles the frame instead), so its encode returns "".
const ENCODERS = {
  kitty: (pixels, w, h, opts) => kitty.encodeImage(pixels, w, h, opts),
  sixel: (pixels, w, h, opts) => sixel.encodeImage(pixels, w, h, opts),
  none: () => "",
};

// blit(prev, next, opts) -> { out, full, tiles } — diff `prev`→`next` and serialize the changed
// tiles with opts.encoder ("kitty" | "sixel" | "none", default "kitty"). opts.cellW/cellH give the
// pixel size of one terminal cell (default 1, i.e. caller already works in cells) so a tile at pixel
// (x,y) is placed at cursor cell (x/cellW, y/cellH). `tiles` is the count placed (0 when nothing
// changed) so a status line can report the paint cost.
export function blit(prev, next, opts = {}) {
  const encoder = opts.encoder ?? "kitty";
  const encode = ENCODERS[encoder] ?? ENCODERS.kitty;
  const cellW = opts.cellW ?? 1;
  const cellH = opts.cellH ?? 1;
  const d = diff(prev, next);
  // stable row-major order: top-to-bottom, left-to-right, like arnold's render sort.
  d.tiles.sort((a, b) => (a.row - b.row) || (a.col - b.col));

  let out = "";
  for (const { col, row } of d.tiles) {
    const { x, y, w, h } = next.tileRect(col, row);
    if (w <= 0 || h <= 0) continue;
    const pixels = next.tilePixels(col, row);
    const colCell = Math.round(x / cellW);
    const rowCell = Math.round(y / cellH);
    const img = encode(pixels, w, h, opts);
    if (img) out += cursorTo(rowCell, colCell) + img;
  }
  return { out, full: d.full, tiles: d.tiles.length };
}

// blitFull(fb, opts) -> string — encode an ENTIRE framebuffer as one image (no diff), placed at the
// cursor home. Used by the demo and by a first paint when the caller wants a single transmission
// rather than per-tile. Honors opts.encoder.
export function blitFull(fb, opts = {}) {
  const encoder = opts.encoder ?? "kitty";
  const encode = ENCODERS[encoder] ?? ENCODERS.kitty;
  if (fb.width === 0 || fb.height === 0) return "";
  const pixels = Uint8ClampedArray.from(fb.data);
  return encode(pixels, fb.width, fb.height, opts);
}
