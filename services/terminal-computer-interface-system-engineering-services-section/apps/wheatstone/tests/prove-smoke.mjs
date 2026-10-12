// prove-smoke — the connect → render → input loop, two ways:
//  (1) over a MOCK world (the pluggable carrier seam): input is sent, output lines + GMCP render.
//  (2) over a REAL TCP socket against a tiny in-process SCRIPTED fake server
//      (bin/lib/fake-mud-server.mjs — self-contained, no @561-group/tab dependency; see its header)
//      — proving the client carrier negotiates and exchanges data on a real wire. The GMCP push is
//      triggered by the server OBSERVING the client's DO GMCP answer on the wire, not a fixed
//      timer, so the assertion below does not race telnet negotiation regardless of what ran
//      earlier in the same process.

import { ok, eq, includes, done } from "./_harness.mjs";
import { Wheatstone } from "../src/app.mjs";
import { localWorld, telnetWorld } from "../src/world.mjs";
import { startFakeServer } from "../bin/lib/fake-mud-server.mjs";

// a mock Screen: records each rendered frame's drawn buffer text so we can assert on it without a
// terminal. It implements the surface app.mjs uses: start/stop/onKey/onInterrupt/render.
import { Buffer as ABuffer } from "@red-cup-engineering/arnold/buffer";
import { rect } from "@red-cup-engineering/arnold/layout";
class MockScreen {
  constructor(w = 80, h = 24) { this.w = w; this.h = h; this.keyHandler = null; this.frames = []; this.started = false; }
  start() { this.started = true; return this; }
  stop() { this.started = false; return this; }
  onKey(fn) { this.keyHandler = fn; return this; }
  onInterrupt() { return this; }
  render(draw) {
    const buf = new ABuffer(this.w, this.h);
    draw(buf, rect(0, 0, this.w, this.h));
    let s = ""; for (let r = 0; r < buf.height; r++) { for (let c = 0; c < buf.width; c++) s += buf.get(r, c).ch; s += "\n"; }
    this.frames.push(s);
    return this;
  }
  lastFrame() { return this.frames[this.frames.length - 1] || ""; }
  type(text) { for (const ch of text) this.keyHandler?.({ name: "char", char: ch }); }
  press(name, extra = {}) { this.keyHandler?.({ name, ...extra }); }
}

// === (1) the mock-world carrier: connect → render → input ===
{
  const sent = [];
  const world = localWorld({
    onConnect: (emit) => { emit.line("Welcome to the Mock MUD!"); emit.gmcp("Char.Vitals", { hp: 50, maxhp: 50 }); },
    onSend: (text, emit) => { sent.push(text); emit.line(`you said: ${text}`); },
  });
  const screen = new MockScreen();
  const app = new Wheatstone({ screen, world, target: "mock:0" });
  app.start();

  includes(screen.lastFrame(), "Welcome to the Mock MUD!", "the welcome line rendered after connect");
  includes(screen.lastFrame(), "HP 50/50", "GMCP vitals rendered in the status line after connect");

  // type a command and press Enter → it is sent and the echo renders
  screen.type("hello");
  screen.press("enter");
  eq(sent, ["hello"], "the typed command was sent to the world");
  includes(screen.lastFrame(), "you said: hello", "the world's reply rendered");
  includes(screen.lastFrame(), "hello", "the local echo of the input rendered");
}

// === (1b) a local slash-command is intercepted, NOT sent to the world ===
{
  const sent = [];
  const world = localWorld({ onSend: (text) => sent.push(text) });
  const screen = new MockScreen();
  const app = new Wheatstone({ screen, world, target: "mock:0" });
  app.start();
  screen.type("/help"); screen.press("enter");
  eq(sent, [], "/help was handled locally, not sent to the world");
  includes(screen.lastFrame(), "/connect", "the /help output listed local commands");

  // an alias defined locally, then used, expands before send
  screen.type("/alias k kill $*"); screen.press("enter");
  screen.type("k big rat"); screen.press("enter");
  eq(sent, ["kill big rat"], "an alias expands before the command is sent");
}

// === (1c) scrollback paging via PageUp ===
{
  const world = localWorld({ onConnect: (emit) => { for (let i = 0; i < 50; i++) emit.line(`line ${i}`); } });
  const screen = new MockScreen(80, 12);
  const app = new Wheatstone({ screen, world, target: "mock:0" });
  app.start();
  const tail = screen.lastFrame();
  includes(tail, "line 49", "the live tail shows the newest line");
  screen.press("pageup");
  ok(!screen.lastFrame().includes("line 49"), "PageUp scrolls the newest line out of view");
  screen.press("char", { ctrl: true, char: "l" });
  includes(screen.lastFrame(), "line 49", "Ctrl-L re-pins to the live tail");
}

// === (2) a REAL TCP round-trip against a scripted fake server (bin/lib/fake-mud-server.mjs) ===
{
  const { port, close } = await startFakeServer();
  const screen = new MockScreen();
  const world = telnetWorld({ host: "127.0.0.1", port, ttype: "WHEATSTONE" });
  const app = new Wheatstone({ screen, world, target: `127.0.0.1:${port}` });
  app.start();

  try {
    // wait for the greeting line to render
    await waitFor(() => screen.lastFrame().includes("Connected to the test server."), 1500);
    includes(screen.lastFrame(), "Connected to the test server.", "real socket: server greeting rendered");

    // send a command over the real wire and await the reply
    screen.type("look"); screen.press("enter");
    await waitFor(() => screen.lastFrame().includes("You see the test room."), 1500);
    includes(screen.lastFrame(), "You see the test room.", "real socket: command sent + reply rendered");

    // the GMCP vitals pushed by the server rendered into the status line. The server sends this
    // only once it OBSERVES the client's DO GMCP answer on the wire (see fake-mud-server.mjs) — no
    // fixed timer, so this is not a race regardless of what ran before this block in the process.
    await waitFor(() => screen.lastFrame().includes("HP 99/100"), 1500);
    includes(screen.lastFrame(), "HP 99/100", "real socket: server GMCP Char.Vitals rendered (CALM)");

    ok(world.supports.gmcp, "real socket: GMCP was negotiated up from the client side");
  } finally {
    try { world.close(); } catch { /* */ }
    await close();
  }
}

// waitFor — poll a predicate until true or timeout (the only async helper; no real timers in logic).
function waitFor(pred, ms) {
  return new Promise((resolve, reject) => {
    const t0 = Date.now();
    const tick = () => {
      if (pred()) return resolve();
      if (Date.now() - t0 > ms) return reject(new Error("waitFor timed out"));
      setTimeout(tick, 10);
    };
    tick();
  });
}

done("prove-smoke");
// the mock-world apps and the real-socket round-trip leave no work pending, but a freshly-closed
// TCP socket can emit a trailing reset after the server closes; exit cleanly on the passing run so
// the suite's exit code reflects the assertions, not a late socket event.
process.exit(0);
