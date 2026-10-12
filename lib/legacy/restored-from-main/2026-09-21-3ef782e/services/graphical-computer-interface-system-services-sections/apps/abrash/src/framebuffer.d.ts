// Type declarations for @red-cup-engineering/abrash/framebuffer.

export class Framebuffer {
  constructor(width: number, height: number, tile?: number);
  readonly width: number;
  readonly height: number;
  readonly tile: number;
  readonly data: Uint8ClampedArray;
  inBounds(x: number, y: number): boolean;
  setPixel(x: number, y: number, r: number, g: number, b: number, a?: number): this;
  getPixel(x: number, y: number): [number, number, number, number];
  clear(r?: number, g?: number, b?: number, a?: number): this;
  fillRect(x: number, y: number, w: number, h: number, r: number, g: number, b: number, a?: number): this;
  blit(src: Framebuffer, x: number, y: number): this;
}

export function paintToCanvas(ctx: CanvasRenderingContext2D, fb: Framebuffer): void;
