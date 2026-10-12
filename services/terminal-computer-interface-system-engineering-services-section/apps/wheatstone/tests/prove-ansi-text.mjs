// prove-ansi-text — the MUD ANSI-color parse into arnold style segments.

import { ok, eq, done } from "./_harness.mjs";
import { parseAnsi, applySGR, hasAnsi } from "../src/ansi-text.mjs";

const ESC = "\x1b";

// plain text → one segment, default style
{
  const { segments } = parseAnsi("just text");
  eq(segments, [{ text: "just text", style: {} }], "plain text is one default-styled segment");
}

// a colored run → bold red segment then reset
{
  const { segments } = parseAnsi(`${ESC}[1;31mDanger${ESC}[0m safe`);
  eq(segments[0], { text: "Danger", style: { bold: true, fg: "red" } }, "1;31m → bold red segment");
  eq(segments[1], { text: " safe", style: {} }, "0m resets to default for the tail");
}

// bright fg (90-97)
{
  const { segments } = parseAnsi(`${ESC}[92mgo`);
  eq(segments[0].style, { fg: "bright-green" }, "92m → bright-green");
}

// background color
{
  const { segments } = parseAnsi(`${ESC}[44mblue-bg`);
  eq(segments[0].style, { bg: "blue" }, "44m → blue background");
}

// 256-color and truecolor
{
  eq(applySGR({}, [38, 5, 200]), { fg: 200 }, "38;5;200 → 256-color fg index 200");
  eq(applySGR({}, [48, 2, 10, 20, 30]), { bg: { r: 10, g: 20, b: 30 } }, "48;2;r;g;b → truecolor bg");
}

// pen threads across a parse via initialStyle + returned style
{
  const first = parseAnsi(`${ESC}[33mopen`); // yellow, never closed
  eq(first.style, { fg: "yellow" }, "the open pen is returned for threading");
  const second = parseAnsi("still yellow", first.style);
  eq(second.segments[0].style, { fg: "yellow" }, "the next line inherits the un-closed pen");
}

// reset-on-attribute-off codes
{
  eq(applySGR({ bold: true, fg: "red" }, [22]), { fg: "red" }, "22 clears bold but keeps fg");
  eq(applySGR({ fg: "red" }, [39]), {}, "39 clears fg to default");
}

// non-SGR escapes (cursor moves) are stripped from segment text
{
  const { segments } = parseAnsi(`${ESC}[2Kcleared`);
  eq(segments.map((s) => s.text).join(""), "cleared", "a non-SGR escape is stripped from the text");
}

// hasAnsi
ok(hasAnsi(`${ESC}[31mx`), "hasAnsi true on SGR");
ok(!hasAnsi("plain"), "hasAnsi false on plain text");

done("prove-ansi-text");
