// prove-scrollback — the output pane data model: append, parse, window, scroll, cap.

import { ok, eq, done } from "./_harness.mjs";
import { Scrollback } from "../src/scrollback.mjs";

const ESC = "\x1b";

// push parses ANSI into segments
{
  const sb = new Scrollback();
  sb.push(`${ESC}[31mred line${ESC}[0m`);
  eq(sb.lines.length, 1, "one line pushed");
  eq(sb.lines[0].segments[0].style, { fg: "red" }, "the pushed line is parsed into styled segments");
}

// window returns the last N lines, oldest→newest, pinned to the tail
{
  const sb = new Scrollback();
  for (let i = 0; i < 10; i++) sb.push(`line ${i}`);
  const { rows, atBottom } = sb.window(3);
  eq(rows.map((r) => r.raw), ["line 7", "line 8", "line 9"], "window(3) is the last 3 lines, oldest→newest");
  ok(atBottom, "atBottom true when pinned to the tail");
}

// scrolling up pages back; scrollToBottom re-pins
{
  const sb = new Scrollback();
  for (let i = 0; i < 10; i++) sb.push(`line ${i}`);
  sb.scrollUp(2);
  const { rows, atBottom } = sb.window(3);
  eq(rows.map((r) => r.raw), ["line 5", "line 6", "line 7"], "scrollUp(2) shifts the window back by 2");
  ok(!atBottom, "atBottom false while scrolled up");
  sb.scrollToBottom();
  eq(sb.window(3).rows[2].raw, "line 9", "scrollToBottom re-pins to the newest line");
}

// the cap ages out the oldest lines (append-only within the cap)
{
  const sb = new Scrollback({ cap: 5 });
  for (let i = 0; i < 8; i++) sb.push(`line ${i}`);
  eq(sb.lines.length, 5, "cap bounds the line count");
  eq(sb.lines[0].raw, "line 3", "the oldest lines aged out; the kept ones stay in order");
}

// the pen threads across pushed lines (color opened on one line, closed on a later one)
{
  const sb = new Scrollback();
  sb.push(`${ESC}[33mopen yellow`); // not closed
  sb.push(`still yellow`);          // should inherit the pen
  eq(sb.lines[1].segments[0].style, { fg: "yellow" }, "an unclosed color threads to the next line");
}

// pushLocal does not consume the server pen
{
  const sb = new Scrollback();
  sb.push(`${ESC}[33mopen`);
  sb.pushLocal("> my command", { dim: true });
  sb.push("next server line");
  eq(sb.lines[2].segments[0].style.fg, "yellow", "a local line does not break the server pen thread");
}

done("prove-scrollback");
