// framebuffer — the RGBA raster surface abrash's raycaster paints into, and its two consumers: a
// headless buffer (pure data, used directly by tests and by any non-visual caller) and a canvas-target
// paint function (browser: hands the raster to a <canvas> 2D context via putImageData).
//
// The raster is a Uint8ClampedArray of width*height*4 bytes, row-major RGBA quadruples — exactly the
// byte layout a browser canvas's `putImageData` wants, so the raycaster does not need to know what
// displays its framebuffer.
//
// THE SURFACE CONTRACT: any code that wants to see an abrash-rendered frame reads `frame.fb.data`, a
// Uint8ClampedArray of RGBA bytes. The Framebuffer class below is implementation #1 (the HEADLESS
// target — pure data, no display, exactly what a test or a terminal ASCII downsample consumes).
// `paintToCanvas` is implementation #2 (the CANVAS target — a browser `<canvas>` 2D context). Nothing
// downstream of `render()` needs to know which target it is talking to.

// clamp a number to a byte
const b = (n) => (n < 0 ? 0 : n > 255 ? 255 : n | 0);

export class Framebuffer {
  // width/height in PIXELS. The raster is a flat Uint8ClampedArray of RGBA quadruples, row-major —
  // exactly the byte layout a browser's ImageData expects, and exactly what a headless test can read
  // pixel-by-pixel with getPixel().
  constructor(width, height, tile = 64) {
    this.width = Math.max(0, width | 0);
    this.height = Math.max(0, height | 0);
    this.tile = Math.max(1, tile | 0);
    this.data = new Uint8ClampedArray(this.width * this.height * 4);
  }

  inBounds(x, y) {
    return x >= 0 && y >= 0 && x < this.width && y < this.height;
  }

  // setPixel(x, y, r, g, b, a=255) — write one RGBA pixel. Out-of-bounds is a no-op so callers can draw
  // past the edge without guarding.
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

  // blit(src, x, y) — copy another framebuffer's pixels onto this one at (x,y), clipped.
  blit(src, x, y) {
    for (let sy = 0; sy < src.height; sy++) {
      for (let sx = 0; sx < src.width; sx++) {
        const [r, g, b8, a] = src.getPixel(sx, sy);
        this.setPixel(x + sx, y + sy, r, g, b8, a);
      }
    }
    return this;
  }
}

// paintToCanvas(ctx, fb) — implementation #2, the CANVAS target: hand an abrash frame's Framebuffer
// straight to a browser 2D context. No encoding, no diffing — `fb.data` already IS the byte layout
// `ImageData` wants, so this constructs one ImageData view over it and blits it in one call. `ImageData`
// is referenced only inside the function body (never at module load), so importing this module in a
// headless Node test never touches a DOM global — the same file serves both targets.
export function paintToCanvas(ctx, fb) {
  if (typeof ImageData === "undefined") {
    throw new Error("paintToCanvas: ImageData is not available in this environment (browser-only)");
  }
  // ImageData requires a Uint8ClampedArray it does not itself already own a detached buffer for in some
  // engines; constructing directly from fb.data is the documented fast path and works in every modern
  // browser (the array is copied by the engine, not aliased, so repeated frames are safe to reuse fb).
  const image = new ImageData(fb.data, fb.width, fb.height);
  ctx.putImageData(image, 0, 0);
}
