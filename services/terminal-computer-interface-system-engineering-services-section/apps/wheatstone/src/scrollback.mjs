// scrollback — the world-output pane's data model: an append-only ring of lines, each a list of
// styled segments (from ansi-text.parseAnsi), plus a scroll offset for paging back through history.
// Pure data + pure methods: no I/O, no drawing. The TUI's render reads this to paint the output
// pane; the carrier's onLine pushes into it.
//
// "Append-only ring": we keep at most `cap` lines (oldest dropped) so a long session does not grow
// unbounded — but within the cap the order is append-only and never rewritten (the journal's
// HELD-substrate spirit: we don't overwrite history, we age it out). The scroll offset counts
// lines UP from the bottom (0 = pinned to the newest line, the live tail).

import { parseAnsi } from "./ansi-text.mjs";

export class Scrollback {
  constructor(opts = {}) {
    this.cap = opts.cap ?? 5000;
    this.lines = [];        // each: { segments: [{text, style}], raw: string }
    this.offset = 0;        // lines scrolled up from the bottom
    this._pen = {};         // ANSI pen carried across lines (MUD color spans newlines)
  }

  // push(raw) — append one MUD output line, parsing its ANSI into styled segments. Threads the pen
  // across lines so a color opened on one line and closed on a later one renders correctly.
  push(raw) {
    const { segments, style } = parseAnsi(raw, this._pen);
    this._pen = style;
    this.lines.push({ segments, raw: String(raw) });
    if (this.lines.length > this.cap) this.lines.splice(0, this.lines.length - this.cap);
    // if pinned to the tail, stay pinned; if scrolled up, keep the same view by advancing offset
    if (this.offset > 0) this.offset = Math.min(this.offset + 1, Math.max(0, this.lines.length - 1));
    return this;
  }

  // pushLocal(raw, style) — append a client-local line (echo of typed input, slash-command output,
  // a status notice) in a fixed style, NOT threading or consuming the server pen.
  pushLocal(raw, style = { dim: true }) {
    this.lines.push({ segments: [{ text: String(raw), style }], raw: String(raw) });
    if (this.lines.length > this.cap) this.lines.splice(0, this.lines.length - this.cap);
    if (this.offset > 0) this.offset = Math.min(this.offset + 1, Math.max(0, this.lines.length - 1));
    return this;
  }

  // window(height) — the slice of lines visible in a pane `height` rows tall, given the current
  // scroll offset. Returns { rows: [...lines], atBottom }. rows is oldest→newest (draw top→bottom).
  window(height) {
    const total = this.lines.length;
    const end = total - this.offset;            // exclusive index of the last visible line + 1
    const start = Math.max(0, end - height);
    return { rows: this.lines.slice(start, end), atBottom: this.offset === 0 };
  }

  // scrolling: scrollUp pages back, scrollDown pages toward the live tail, scrollToBottom re-pins.
  scrollUp(n = 1) { this.offset = Math.min(this.offset + n, Math.max(0, this.lines.length - 1)); return this; }
  scrollDown(n = 1) { this.offset = Math.max(0, this.offset - n); return this; }
  scrollToBottom() { this.offset = 0; return this; }
  clear() { this.lines = []; this.offset = 0; this._pen = {}; return this; }
}
