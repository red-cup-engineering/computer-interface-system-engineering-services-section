// framebuffer — the screen as a RASTER of RGBA pixels, and the DIFF between two rasters by TILE.
// This is the pixel analogue of arnold's cell Buffer: where arnold holds a width×height grid of
// { ch, style } cells and diffs cell-by-cell, daleske holds a width×height grid of RGBA pixels
// (4 bytes each) and diffs by TILE. A diffed pixel terminal cannot economically re-send one pixel
// (a graphics-protocol image is the unit of transfer), so the framebuffer is partitioned into a
// grid of fixed tiles and the diff reports which TILES changed. The blit then re-encodes only those
// tiles — the raster equivalent of "only the changed cells reach the terminal".
//
// Pure data + pure functions: no node:tty, no I/O, no encoder. A Framebuffer is constructed, drawn
// onto, and diffed. Encoding (kitty/sixel) lives in its own module and consumes a tile's pixels.

export const DEFAULT_TILE = 64; // px; a tile is the unit of re-transmission in the diff

// clamp a number to a byte
const b = (n) => (n < 0 ? 0 : n > 255 ? 255 : n | 0);

export class Framebuffer {
  // width/height in PIXELS. `tile` is the side length of a (square) diff tile. The raster is a flat
  // Uint8ClampedArray of RGBA quadruples in row-major order.
  constructor(width, height, tile = DEFAULT_TILE) {
    this.width = Math.max(0, width | 0);
    this.height = Math.max(0, height | 0);
    this.tile = Math.max(1, tile | 0);
    this.data = new Uint8ClampedArray(this.width * this.height * 4);
    // tile grid dimensions (ceil so a partial edge tile still counts)
    this.cols = Math.ceil(this.width / this.tile);
    this.rows = Math.ceil(this.height / this.tile);
  }

  inBounds(x, y) {
    return x >= 0 && y >= 0 && x < this.width && y < this.height;
  }

  // setPixel(x, y, [r,g,b,a]) — write one RGBA pixel (a defaults to opaque). Out-of-bounds is a
  // no-op so callers can draw past the edge without guarding.
  setPixel(x, y, r, g, b8, a = 255) {
    if (!this.inBounds(x, y)) return this;
    const i = (y * this.width + x) * 4;
    this.data[i] = b(r); this.data[i + 1] = b(g); this.data[i + 2] = b(b8); this.data[i + 3] = b(a);
    return this;
  }

  // getPixel(x, y) -> [r,g,b,a]. Out-of-bounds reads as transparent black.
  getPixel(x, y) {
    if (!this.inBounds(x, y)) return [0, 0, 0, 0];
    const i = (y * this.width + x) * 4;
    return [this.data[i], this.data[i + 1], this.data[i + 2], this.data[i + 3]];
  }

  // clear(rgba) — fill the whole raster with one color (default transparent black).
  clear(r = 0, g = 0, b8 = 0, a = 0) {
    for (let i = 0; i < this.data.length; i += 4) {
      this.data[i] = b(r); this.data[i + 1] = b(g); this.data[i + 2] = b(b8); this.data[i + 3] = b(a);
    }
    return this;
  }

  // fillRect(x, y, w, h, rgba) — paint a solid rectangle, clipped to the raster.
  fillRect(x, y, w, h, r, g, b8, a = 255) {
    const x1 = Math.max(0, x), y1 = Math.max(0, y);
    const x2 = Math.min(this.width, x + w), y2 = Math.min(this.height, y + h);
    for (let yy = y1; yy < y2; yy++) {
      for (let xx = x1; xx < x2; xx++) this.setPixel(xx, yy, r, g, b8, a);
    }
    return this;
  }

  // blit(src, x, y) — copy another framebuffer's pixels onto this one at (x,y), clipped. The pixel
  // analogue of arnold's cell blit: lets a region be composed into a parent without the region
  // knowing its absolute position.
  blit(src, x, y) {
    for (let sy = 0; sy < src.height; sy++) {
      for (let sx = 0; sx < src.width; sx++) {
        const [r, g, b8, a] = src.getPixel(sx, sy);
        this.setPixel(x + sx, y + sy, r, g, b8, a);
      }
    }
    return this;
  }

  // tileRect(col, row) -> { x, y, w, h } — the pixel extent of tile (col,row), clipped to the edge.
  tileRect(col, row) {
    const x = col * this.tile, y = row * this.tile;
    return { x, y, w: Math.min(this.tile, this.width - x), h: Math.min(this.tile, this.height - y) };
  }

  // tilePixels(col, row) -> Uint8ClampedArray — a TIGHTLY PACKED RGBA copy of tile (col,row), of
  // size w*h*4 (the edge tiles are narrower/shorter). This is what an encoder consumes.
  tilePixels(col, row) {
    const { x, y, w, h } = this.tileRect(col, row);
    const out = new Uint8ClampedArray(w * h * 4);
    let o = 0;
    for (let yy = 0; yy < h; yy++) {
      let i = ((y + yy) * this.width + x) * 4;
      for (let xx = 0; xx < w; xx++) {
        out[o++] = this.data[i++]; out[o++] = this.data[i++];
        out[o++] = this.data[i++]; out[o++] = this.data[i++];
      }
    }
    return out;
  }
}

// tilesEqual(a, b, col, row) — do two framebuffers carry identical pixels across one tile? The
// diff's atom (the raster analogue of cellsEqual).
export function tilesEqual(a, b, col, row) {
  const { x, y, w, h } = a.tileRect(col, row);
  for (let yy = 0; yy < h; yy++) {
    let ia = ((y + yy) * a.width + x) * 4;
    let ib = ((y + yy) * b.width + x) * 4;
    for (let xx = 0; xx < w * 4; xx++) {
      if (a.data[ia++] !== b.data[ib++]) return false;
    }
  }
  return true;
}

// diff(prev, next) -> { full, tiles } — the list of changed TILES going from `prev` to `next`. Each
// entry is { col, row } addressing a tile of `next`. If `prev` is null (first paint) or dimensions
// differ, EVERY tile is changed (a full repaint). The blit turns this into the minimal set of
// graphics-protocol image transmissions. The raster analogue of arnold's buffer.diff.
export function diff(prev, next) {
  const all = () => {
    const tiles = [];
    for (let row = 0; row < next.rows; row++) {
      for (let col = 0; col < next.cols; col++) tiles.push({ col, row });
    }
    return tiles;
  };
  if (!prev || prev.width !== next.width || prev.height !== next.height || prev.tile !== next.tile) {
    return { full: true, tiles: all() };
  }
  const tiles = [];
  for (let row = 0; row < next.rows; row++) {
    for (let col = 0; col < next.cols; col++) {
      if (!tilesEqual(prev, next, col, row)) tiles.push({ col, row });
    }
  }
  return { full: false, tiles };
}
