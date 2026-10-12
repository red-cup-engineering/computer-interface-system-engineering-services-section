// scrollback.d.ts — hand-written types for src/scrollback.mjs.

import type { Segment, AnsiStyle } from "./ansi-text.mjs";

export interface ScrollbackLine {
  segments: Segment[];
  raw: string;
}

export interface ScrollbackOpts {
  cap?: number;
}

export interface ScrollbackWindow {
  rows: ScrollbackLine[];
  atBottom: boolean;
}

export class Scrollback {
  cap: number;
  lines: ScrollbackLine[];
  offset: number;
  constructor(opts?: ScrollbackOpts);
  push(raw: string): this;
  pushLocal(raw: string, style?: AnsiStyle): this;
  window(height: number): ScrollbackWindow;
  scrollUp(n?: number): this;
  scrollDown(n?: number): this;
  scrollToBottom(): this;
  clear(): this;
}
