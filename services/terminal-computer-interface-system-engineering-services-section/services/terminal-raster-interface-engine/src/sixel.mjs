// sixel — an encoder for the SIXEL graphics format, the GRACEFUL FALLBACK when a terminal speaks
// sixel but not the kitty protocol. Pure: (RGBA pixels, w, h, opts) -> the sixel escape string. No
// I/O. The second of daleske's two raster encoders; the blit picks between them by capability.
//
// Sixel encodes a band of SIX vertical pixels per character. The stream is:
//   DCS (ESC P) q  <palette defs>  <band data...>  ST (ESC \)
// A "sixel" character is `?`+bits where bit k (k=0..5) lights the pixel at this column, this band's
// row k. We quantize the RGBA raster to a small PALETTE (median-cut-lite: we collect the distinct
// opaque colors, capping at maxColors by coarse quantization), then for each 6-row band, for each
// palette color, emit the run of sixel chars that lights that color's pixels. Run-length encoding
// (`!count` repeats the next sixel) keeps solid regions cheap. Transparent pixels (a<128) are left
// unlit. This is a correct, compact sixel — not the densest possible, but a faithful fallback.

const ESC = "\x1b";
const DCS = `${ESC}P`;
const ST = `${ESC}\\`;

// quantize one 8-bit channel to a coarser step so distinct-color count stays bounded. step=51 maps
// 0..255 -> {0,51,...,255} (6 levels/channel => 216 max colors, the classic web-safe cube).
function q(v, step) { return Math.round(v / step) * step; }

// sixel palette values are 0..100 (percent), not 0..255.
const to100 = (v) => Math.round((v / 255) * 100);

// buildPalette(pixels, n, maxColors) — collect distinct quantized opaque colors, return
// { palette:[[r,g,b]...], indexOf:Uint16Array }. indexOf[p] is the palette slot of pixel p, or
// 0xffff for transparent (unlit). Caps the palette at maxColors by widening the quantization step
// until the color count fits.
function buildPalette(pixels, count, maxColors) {
  for (let step = 51; step <= 255; step += step) {
    const map = new Map();
    const indexOf = new Uint16Array(count).fill(0xffff);
    let overflow = false;
    for (let p = 0; p < count; p++) {
      const a = pixels[p * 4 + 3];
      if (a < 128) continue; // transparent => unlit
      const r = q(pixels[p * 4], step), g = q(pixels[p * 4 + 1], step), b = q(pixels[p * 4 + 2], step);
      const key = (r << 16) | (g << 8) | b;
      let idx = map.get(key);
      if (idx === undefined) {
        if (map.size >= maxColors) { overflow = true; break; }
        idx = map.size; map.set(key, idx);
      }
      indexOf[p] = idx;
    }
    if (!overflow) {
      const palette = new Array(map.size);
      for (const [key, idx] of map) palette[idx] = [(key >> 16) & 255, (key >> 8) & 255, key & 255];
      return { palette, indexOf };
    }
  }
  // step grew past 255 => everything collapses to one color; build the trivial palette.
  const indexOf = new Uint16Array(count).fill(0xffff);
  for (let p = 0; p < count; p++) if (pixels[p * 4 + 3] >= 128) indexOf[p] = 0;
  return { palette: [[128, 128, 128]], indexOf };
}

// encodeImage(pixels, width, height, opts) — the core. `pixels` is tightly-packed RGBA of length
// width*height*4. opts.maxColors caps the palette (default 256). Returns the full DCS..ST sixel
// string. Throws on inconsistent length.
export function encodeImage(pixels, width, height, opts = {}) {
  const w = width | 0, h = height | 0;
  if (pixels.length !== w * h * 4) {
    throw new RangeError(`sixel.encodeImage: expected ${w * h * 4} RGBA bytes, got ${pixels.length}`);
  }
  const maxColors = opts.maxColors ?? 256;
  const { palette, indexOf } = buildPalette(pixels, w * h, maxColors);

  let out = `${DCS}q`; // P q : sixel introducer (default aspect/grid)
  // palette definitions:  #<i>;2;<r%>;<g%>;<b%>   (2 = RGB color space)
  for (let i = 0; i < palette.length; i++) {
    const [r, g, b] = palette[i];
    out += `#${i};2;${to100(r)};${to100(g)};${to100(b)}`;
  }

  // each band is 6 rows. For each band, for each palette color present, emit a sixel run line.
  for (let band = 0; band < Math.ceil(h / 6); band++) {
    const y0 = band * 6;
    for (let ci = 0; ci < palette.length; ci++) {
      // build this color's sixel chars across the row
      const chars = new Array(w);
      let any = false;
      for (let x = 0; x < w; x++) {
        let bits = 0;
        for (let k = 0; k < 6; k++) {
          const y = y0 + k;
          if (y >= h) break;
          if (indexOf[y * w + x] === ci) bits |= (1 << k);
        }
        if (bits) any = true;
        chars[x] = String.fromCharCode(0x3f + bits); // '?'==0 .. '~'==63
      }
      if (!any) continue; // this color paints nothing in this band — skip its line
      out += `#${ci}` + rle(chars);
      out += "$"; // carriage return: next color overlays the same band
    }
    out += "-"; // line feed: advance to the next band
  }
  out += ST;
  return out;
}

// rle(chars) — run-length encode a sixel char array: `!<count><char>` for runs of >=4, else literal.
function rle(chars) {
  let out = "";
  let i = 0;
  while (i < chars.length) {
    let j = i + 1;
    while (j < chars.length && chars[j] === chars[i]) j++;
    const run = j - i;
    if (run >= 4) out += `!${run}${chars[i]}`;
    else out += chars[i].repeat(run);
    i = j;
  }
  return out;
}

// paletteSize(pixels, opts) — the number of distinct colors the encoder would emit. Exposed so a
// test can assert quantization without parsing the sixel stream.
export function paletteSize(pixels, opts = {}) {
  const count = pixels.length / 4;
  return buildPalette(pixels, count, opts.maxColors ?? 256).palette.length;
}
