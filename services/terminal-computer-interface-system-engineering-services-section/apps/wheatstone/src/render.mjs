// render — the PURE view: draw the wheatstone TUI into an arnold Buffer at a Rect. No I/O, no
// sockets, no Screen. It takes the app state (scrollback, worldstate, input, flags) and the
// arnold drawing vocabulary (buffer + layout + widgets) and paints a frame. Keeping this pure is
// what lets the render test diff a frame against a mock buffer with no terminal.
//
// Layout (top to bottom):
//   ┌ output pane ───────────────┬ side panel ┐   (panel optional; toggled by /audit or a key)
//   │ scrolling ANSI-colored MUD │ map/who/   │
//   │ text, scrollback           │ GMCP/audit │
//   ├────────────────────────────┴────────────┤
//   │ status line (GMCP/MSDP vitals, CALM)     │
//   │ > command input (history, cursor)        │
//
// The output pane draws each scrollback line as its STYLED SEGMENTS (ansi-text parsed), so MUD
// color renders as real arnold cell styles, not raw escapes.

import { flex, stack, inset } from "@red-cup-engineering/arnold/layout";
import { box, text as drawText, input as drawInput, statusLine } from "@red-cup-engineering/arnold/widgets";

// drawSegments(buf, row, col, width, segments) — draw a line's styled segments left to right,
// clipped to width. Each segment carries its own arnold style. Returns nothing.
function drawSegments(buf, row, col, width, segments) {
  let c = col;
  const limit = col + width;
  for (const seg of segments) {
    if (c >= limit) break;
    const room = limit - c;
    const t = seg.text.length > room ? seg.text.slice(0, room) : seg.text;
    c = buf.drawText(row, c, t, seg.style || {});
  }
}

// view(state) — returns a draw(buf, rect) for arnold's Screen.render. state:
//   { scrollback, world (WorldState), input:{value,cursor}, status:{state,detail},
//     showPanel:bool, showAudit:bool, prompt:string }
export function view(state) {
  return function draw(buf, rect) {
    const showPanel = !!state.showPanel;
    // vertical split: a content region (grows) + a 1-row status bar + a 1-row input line.
    const [content, statusRow, inputRow] = stack(rect, [null, 1, 1]);

    // horizontal split of the content: output pane (grows) + optional side panel (fixed width).
    let outputRect = content, panelRect = null;
    if (showPanel) {
      const panelW = Math.min(Math.max(20, Math.floor(content.width * 0.3)), 40);
      const [op, pp] = flex(content, [{ grow: 1 }, { size: panelW }], { direction: "row", gap: 0 });
      outputRect = op; panelRect = pp;
    }

    // --- output pane ---------------------------------------------------------------------------
    const inner = box(buf, outputRect, { title: titleFor(state), style: borderStyle(state), titleStyle: { bold: true } });
    const { rows } = state.scrollback.window(inner.height - (state.prompt ? 1 : 0));
    let r = inner.row;
    for (const line of rows) {
      if (r >= inner.row + inner.height) break;
      drawSegments(buf, r, inner.col, inner.width, line.segments);
      r++;
    }
    // a live prompt (server GA/EOR mark) on the last output row, if present
    if (state.prompt && r <= inner.row + inner.height - 1) {
      drawSegments(buf, inner.row + inner.height - 1, inner.col, inner.width,
        [{ text: state.prompt, style: { fg: "bright-white" } }]);
    }

    // --- side panel ----------------------------------------------------------------------------
    if (panelRect) {
      const pin = box(buf, panelRect, { title: state.showAudit ? "audit" : "world", style: borderStyle(state), titleStyle: { bold: true } });
      const lines = state.world.panelLines({ audit: state.showAudit });
      let pr = pin.row;
      for (const ln of lines) {
        if (pr >= pin.row + pin.height) break;
        buf.drawText(pr, pin.col, String(ln.text).slice(0, pin.width), ln.style || {});
        pr++;
      }
    }

    // --- status line ---------------------------------------------------------------------------
    const slots = state.world.statusSlots();
    const conn = connLabel(state.status);
    // left slot carries the connection state then the char name; CALM — plain text, no spectacle.
    const left = [conn, slots.left].filter(Boolean).join("  ");
    statusLine(buf, statusRow, { left, center: slots.center, right: slots.right }, { style: { inverse: true } });

    // --- input line ----------------------------------------------------------------------------
    const promptStr = state.scrollback.offset > 0 ? "(scrolled) > " : "> ";
    drawInput(buf, inputRow, state.input, { prompt: promptStr, promptStyle: { fg: "green", bold: true } });
  };
}

function titleFor(state) {
  const k = state.world?.kind;
  const base = state.target ? `wheatstone — ${state.target}` : "wheatstone";
  return state.scrollback.offset > 0 ? `${base} [scrollback]` : base;
}
function borderStyle(state) {
  return state.status?.state === "connected" ? { fg: "green" }
    : state.status?.state === "error" ? { fg: "red" }
    : { dim: true };
}
function connLabel(status) {
  if (!status) return "○ idle";
  const s = status.state;
  if (s === "connected") return "● connected";
  if (s === "connecting") return "◐ connecting…";
  if (s === "error") return `✗ ${status.detail?.message || "error"}`;
  if (s === "closed") return "○ closed";
  return `○ ${s}`;
}
