// prove-render — the TUI render over a REAL arnold Buffer (no terminal). We build app state, draw a
// frame with view(state), and read the buffer cells back to prove the panes paint where they should.

import { ok, eq, includes, done } from "./_harness.mjs";
import { Buffer as ABuffer } from "@red-cup-engineering/arnold/buffer";
import { rect } from "@red-cup-engineering/arnold/layout";
import { view } from "../src/render.mjs";
import { Scrollback } from "../src/scrollback.mjs";
import { WorldState } from "../src/worldstate.mjs";

const ESC = "\x1b";

// read a whole buffer row as a plain string.
function rowText(buf, r) {
  let s = "";
  for (let c = 0; c < buf.width; c++) s += buf.get(r, c).ch;
  return s.replace(/\s+$/, "");
}
function allText(buf) { let s = ""; for (let r = 0; r < buf.height; r++) s += rowText(buf, r) + "\n"; return s; }

// a baseline state
function mkState(over = {}) {
  const scrollback = new Scrollback();
  const world = new WorldState();
  return {
    scrollback, world,
    input: { value: "say hi", cursor: 6 },
    status: { state: "connected" },
    showPanel: false, showAudit: false, prompt: "",
    target: "127.0.0.1:4000",
    ...over,
  };
}

// === the output pane shows scrollback lines ===
{
  const st = mkState();
  st.scrollback.push("You are standing in a field.");
  st.scrollback.push("A rabbit hops by.");
  const buf = new ABuffer(60, 12);
  view(st)(buf, rect(0, 0, 60, 12));
  const txt = allText(buf);
  includes(txt, "You are standing in a field.", "the output pane renders a scrollback line");
  includes(txt, "A rabbit hops by.", "the output pane renders a second line");
}

// === the input line renders with the prompt + the typed value ===
{
  const st = mkState();
  const buf = new ABuffer(60, 12);
  view(st)(buf, rect(0, 0, 60, 12));
  const last = rowText(buf, 11);
  includes(last, ">", "the input line shows the prompt");
  includes(last, "say hi", "the input line shows the typed value");
}

// === the status line shows the connection state + GMCP-fed vitals (CALM) ===
{
  const st = mkState();
  st.world.applyGMCP("Char.Vitals", { hp: 75, maxhp: 100 });
  st.world.applyGMCP("Char.Status", { name: "Gorin", level: 5 });
  const buf = new ABuffer(60, 12);
  view(st)(buf, rect(0, 0, 60, 12));
  const status = rowText(buf, 10);
  includes(status, "connected", "the status line shows the connection state");
  includes(status, "Gorin", "the status line shows the char name");
  includes(status, "HP 75/100", "the status line shows GMCP vitals plainly (CALM)");
}

// === ANSI color in a line becomes a styled cell (not raw escapes in the grid) ===
{
  const st = mkState();
  st.scrollback.push(`${ESC}[31mRED${ESC}[0m`);
  const buf = new ABuffer(60, 12);
  view(st)(buf, rect(0, 0, 60, 12));
  // find the 'R' cell of "RED" inside the box (row 1, col 1) and check its style.
  let found = null;
  for (let r = 0; r < buf.height && !found; r++) for (let c = 0; c < buf.width; c++) {
    if (buf.get(r, c).ch === "R" && buf.get(r, c).style.fg === "red") { found = buf.get(r, c); break; }
  }
  ok(found, "a red MUD word renders as a cell with style.fg red (color, not raw escape)");
  // and no ESC byte leaked into any cell
  let leaked = false;
  for (const cell of buf.cells) if (cell.ch === ESC) leaked = true;
  ok(!leaked, "no raw escape byte leaked into the cell grid");
}

// === the side panel appears when toggled and shows world state ===
{
  const st = mkState({ showPanel: true });
  st.world.applyGMCP("Room.Info", { name: "The Square", exits: ["north"] });
  const buf = new ABuffer(70, 12);
  view(st)(buf, rect(0, 0, 70, 12));
  const txt = allText(buf);
  includes(txt, "The Square", "the side panel shows the room name when toggled on");
  includes(txt, "world", "the panel is titled 'world'");
}

// === the audit panel title flips when audit is on ===
{
  const st = mkState({ showPanel: true, showAudit: true });
  const buf = new ABuffer(70, 12);
  view(st)(buf, rect(0, 0, 70, 12));
  includes(allText(buf), "audit", "the panel is titled 'audit' on demand");
}

// === a scrollback marker appears in the title when scrolled up ===
{
  const st = mkState();
  for (let i = 0; i < 30; i++) st.scrollback.push(`line ${i}`);
  st.scrollback.scrollUp(5);
  const buf = new ABuffer(70, 12);
  view(st)(buf, rect(0, 0, 70, 12));
  includes(allText(buf), "scrollback", "the title marks scrollback mode when paged up");
}

done("prove-render");
