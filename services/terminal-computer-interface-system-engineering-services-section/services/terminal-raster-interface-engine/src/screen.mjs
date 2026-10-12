// screen — Daleske's pixel/raster composition layer. Terminal ownership, raw input, lifecycle,
// resize events, and capability observation belong to terminal-user-interface-engine. PixelScreen
// owns the shown framebuffer and turns changed tiles into graphics bytes.

import { Framebuffer } from "./framebuffer.mjs";
import { blit } from "./blit.mjs";
import * as kitty from "./kitty.mjs";
import { TerminalSession } from "@red-cup-engineering/terminal-user-interface-engine";

// CELL_W / CELL_H — the assumed pixel size of one terminal cell, used to place tiles at a cursor cell
// (the protocols draw at the cursor, which addresses cells, not pixels). A typical cell is ~8×16 px.
const CELL_W = 8, CELL_H = 16;

export class PixelScreen {
  constructor(opts = {}) {
    const env = opts.env || process.env;
    this.terminal = opts.terminal || new TerminalSession({
      input: opts.in,
      output: opts.out,
      env,
      graphicsOverride: env.DALESKE_ENCODER,
      overrideName: "DALESKE_ENCODER",
    });
    this.out = this.terminal.output;
    this.keyboard = this.terminal.keyboard;
    this.cap = {
      encoder: this.terminal.capabilities.graphics,
      why: this.terminal.capabilities.why,
      tty: this.terminal.capabilities.tty,
    };
    this.encoder = opts.encoder || this.cap.encoder; // allow an explicit override
    this.cellW = opts.cellW ?? CELL_W;
    this.cellH = opts.cellH ?? CELL_H;
    this.tile = opts.tile;
    this.shown = null; // the framebuffer on screen; null forces a full first paint
    this.terminal.onResize(() => { this.shown = null; });
    this.terminal.beforeStop((terminal) => {
      if (this.encoder === "kitty") terminal.write(kitty.deleteAll());
    });
  }

  // pixel dimensions of the drawable area: terminal cells × cell pixel size.
  get width() { return this.terminal.columns * this.cellW; }
  get height() { return this.terminal.rows * this.cellH; }

  start() {
    this.terminal.start();
    return this;
  }

  stop() {
    this.terminal.stop();
    return this;
  }

  onKey(fn) { this.terminal.onKey(fn); return this; }
  onInterrupt(fn) { this.terminal.onInterrupt(fn); return this; }

  // render(draw) — build a fresh framebuffer at the current pixel size, let `draw(fb)` paint it,
  // diff it against the shown framebuffer, blit the minimal set of changed tiles, adopt as shown.
  render(draw) {
    const fb = new Framebuffer(this.width, this.height, this.tile);
    draw(fb);
    const { out } = blit(this.shown, fb, {
      encoder: this.encoder, cellW: this.cellW, cellH: this.cellH,
    });
    if (out) this.out.write(out);
    this.shown = fb;
    return this;
  }

  // paint(fb) — adopt and diff an already-drawn framebuffer.
  paint(fb) {
    const { out } = blit(this.shown, fb, {
      encoder: this.encoder, cellW: this.cellW, cellH: this.cellH,
    });
    if (out) this.out.write(out);
    this.shown = fb;
    return this;
  }
}
