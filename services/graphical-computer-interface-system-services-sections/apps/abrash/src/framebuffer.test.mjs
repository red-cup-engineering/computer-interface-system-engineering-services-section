// framebuffer.test.mts — proves the RGBA surface contract: the headless Framebuffer target (pure data)
// and paintToCanvas's environment guard (it refuses to run without a DOM; the actual putImageData call
// only runs in a browser).

import { test } from "node:test";
import assert from "node:assert/strict";
import { Framebuffer, paintToCanvas } from "./framebuffer.mjs";

test("Framebuffer: data length is exactly width*height*4 (the ImageData byte layout)", () => {
  const fb = new Framebuffer(10, 6);
  assert.equal(fb.data.length, 10 * 6 * 4);
  assert.ok(fb.data instanceof Uint8ClampedArray);
});

test("Framebuffer: setPixel/getPixel round-trip", () => {
  const fb = new Framebuffer(4, 4);
  fb.setPixel(1, 2, 10, 20, 30, 40);
  assert.deepEqual(fb.getPixel(1, 2), [10, 20, 30, 40]);
});

test("Framebuffer: setPixel defaults alpha to opaque (255)", () => {
  const fb = new Framebuffer(2, 2);
  fb.setPixel(0, 0, 1, 2, 3);
  assert.deepEqual(fb.getPixel(0, 0), [1, 2, 3, 255]);
});

test("Framebuffer: out-of-bounds setPixel is a no-op (never throws)", () => {
  const fb = new Framebuffer(2, 2);
  assert.doesNotThrow(() => fb.setPixel(-1, -1, 1, 1, 1));
  assert.doesNotThrow(() => fb.setPixel(99, 99, 1, 1, 1));
});

test("Framebuffer: out-of-bounds getPixel reads transparent black", () => {
  const fb = new Framebuffer(2, 2);
  assert.deepEqual(fb.getPixel(-1, 0), [0, 0, 0, 0]);
  assert.deepEqual(fb.getPixel(0, 99), [0, 0, 0, 0]);
});

test("Framebuffer: values clamp to a byte (over 255 and under 0)", () => {
  const fb = new Framebuffer(2, 2);
  fb.setPixel(0, 0, 999, -50, 128, 300);
  assert.deepEqual(fb.getPixel(0, 0), [255, 0, 128, 255]);
});

test("Framebuffer: clear fills the whole raster with one color", () => {
  const fb = new Framebuffer(3, 3);
  fb.clear(9, 8, 7, 6);
  for (let y = 0; y < 3; y++) {
    for (let x = 0; x < 3; x++) assert.deepEqual(fb.getPixel(x, y), [9, 8, 7, 6]);
  }
});

test("Framebuffer: fillRect paints only the rectangle, clipped to the raster", () => {
  const fb = new Framebuffer(5, 5);
  fb.fillRect(1, 1, 2, 2, 1, 1, 1, 255);
  assert.deepEqual(fb.getPixel(1, 1), [1, 1, 1, 255]);
  assert.deepEqual(fb.getPixel(2, 2), [1, 1, 1, 255]);
  assert.deepEqual(fb.getPixel(0, 0), [0, 0, 0, 0]); // untouched
  assert.deepEqual(fb.getPixel(3, 3), [0, 0, 0, 0]); // outside the rect
});

test("Framebuffer: fillRect clips a rectangle that overhangs the raster edge", () => {
  const fb = new Framebuffer(3, 3);
  assert.doesNotThrow(() => fb.fillRect(2, 2, 10, 10, 5, 5, 5, 255));
  assert.deepEqual(fb.getPixel(2, 2), [5, 5, 5, 255]);
});

test("Framebuffer: blit copies a source framebuffer's pixels at an offset", () => {
  const src = new Framebuffer(2, 2);
  src.fillRect(0, 0, 2, 2, 7, 7, 7, 255);
  const dst = new Framebuffer(4, 4);
  dst.blit(src, 1, 1);
  assert.deepEqual(dst.getPixel(1, 1), [7, 7, 7, 255]);
  assert.deepEqual(dst.getPixel(2, 2), [7, 7, 7, 255]);
  assert.deepEqual(dst.getPixel(0, 0), [0, 0, 0, 0]);
});

test("Framebuffer: two independently constructed buffers with identical draws produce byte-identical data (determinism)", () => {
  const draw = (fb) => { fb.fillRect(0, 0, 4, 4, 1, 2, 3, 255); fb.setPixel(1, 1, 9, 9, 9, 9); };
  const a = new Framebuffer(4, 4); draw(a);
  const b = new Framebuffer(4, 4); draw(b);
  assert.deepEqual([...a.data], [...b.data]);
});

test("paintToCanvas: refuses to run in a headless environment with no ImageData global", () => {
  const fb = new Framebuffer(2, 2);
  assert.throws(() => paintToCanvas({}, fb), /ImageData/);
});
