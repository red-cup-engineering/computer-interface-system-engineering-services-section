// app — the composition root: wire a pluggable WORLD (carrier) to the TUI state, run the arnold
// Screen, and translate keypresses into edits / scrolling / slash-commands / sends. This is the
// imperative shell; everything it composes (render.view, scrollback, worldstate, commands) is pure.
//
// The world is injected, so the SAME app runs over a telnet world today and a swarm world later —
// the app only ever calls world.connect / world.send / world.onLine / world.onGMCP / world.onMSDP.
//
//   const app = new Wheatstone({ world, target });
//   app.start();              // raw-mode screen up, wire the world, connect, paint
//   app.stop();               // restore the terminal
//
// Testable seam: pass a fake `screen` (anything with start/stop/onKey/onInterrupt/render) and a
// mock world; the smoke test drives connect → render → input with no real terminal or socket.

import { Screen } from "@red-cup-engineering/arnold/app";
import { editInput } from "@red-cup-engineering/arnold/widgets";
import { Scrollback } from "./scrollback.mjs";
import { WorldState } from "./worldstate.mjs";
import { History, expandAlias, matchTriggers, parseInput, SLASH_COMMANDS } from "./commands.mjs";
import { view } from "./render.mjs";
import { telnetWorld } from "./world.mjs";

export class Wheatstone {
  constructor(opts = {}) {
    this.screen = opts.screen || new Screen();
    this.world = opts.world || null;
    this.name = opts.name || "wheatstone";
    this.exit = opts.exit || ((code) => process.exit?.(code));
    this.target = opts.target || (this.world?.kind === "telnet" ? `${opts.host}:${opts.port}` : this.world?.kind || "");
    this.makeWorld = opts.makeWorld || ((o) => telnetWorld(o));  // for /connect host port
    this.connectOpts = { host: opts.host, port: opts.port, naws: opts.naws, ttype: opts.ttype };

    this.scrollback = new Scrollback({ cap: opts.scrollbackCap });
    this.worldstate = new WorldState();
    this.history = new History();
    this.input = { value: "", cursor: 0 };
    this.aliases = { ...(opts.aliases || {}) };
    this.triggers = [...(opts.triggers || [])];
    this.status = { state: "idle" };
    this.prompt = "";
    this.showPanel = opts.showPanel ?? false;
    this.showAudit = false;
    this._unsub = [];
  }

  state() {
    return {
      scrollback: this.scrollback, world: this.worldstate, input: this.input,
      status: this.status, showPanel: this.showPanel, showAudit: this.showAudit,
      prompt: this.prompt, target: this.target,
    };
  }
  paint() { this.screen.render(view(this.state())); }

  // wire a world's events into our state. Called on start and on /connect (after swapping world).
  wireWorld(world) {
    for (const off of this._unsub) { try { off(); } catch { /* */ } }
    this._unsub = [];
    if (!world) return;
    this._unsub.push(world.onLine((line) => {
      this.scrollback.push(line);
      // run triggers on the incoming line (may send back to the world)
      for (const f of matchTriggers(this.triggers, line)) {
        if (f.trigger.send) world.send(typeof f.trigger.send === "function" ? f.trigger.send(f) : f.trigger.send);
      }
      this.prompt = ""; // a full line clears any pending prompt
      this.paint();
    }));
    if (world.onPrompt) this._unsub.push(world.onPrompt((t) => { this.prompt = t; this.paint(); }));
    this._unsub.push(world.onGMCP((pkg, data) => { this.worldstate.applyGMCP(pkg, data); this.paint(); }));
    if (world.onMSDP) this._unsub.push(world.onMSDP((obj) => { this.worldstate.applyMSDP(obj); this.paint(); }));
    if (world.onStatus) this._unsub.push(world.onStatus((s) => {
      this.status = s;
      if (s.state === "connected") this.scrollback.pushLocal(`— connected to ${this.target} —`, { fg: "green" });
      else if (s.state === "error") this.scrollback.pushLocal(`— error: ${s.detail?.message || ""} —`, { fg: "red" });
      else if (s.state === "closed") this.scrollback.pushLocal(`— disconnected —`, { fg: "yellow" });
      this.paint();
    }));
  }

  start() {
    this.screen.start?.();
    this.screen.onKey?.((k) => this.onKey(k));
    this.screen.onInterrupt?.(() => this.stop());
    this.scrollback.pushLocal(`${this.name} — /help for local commands, /connect to begin`, { dim: true });
    if (this.world) { this.wireWorld(this.world); this.connect(); }
    this.paint();
    return this;
  }
  stop() {
    try { this.world?.close?.(); } catch { /* */ }
    this.screen.stop?.();
    if (this._exiting) return;
    this._exiting = true;
    this.exit(0);
  }

  connect() {
    if (!this.world) return;
    Promise.resolve(this.world.connect()).catch((err) => {
      this.scrollback.pushLocal(`— connect failed: ${err?.message || err} —`, { fg: "red" });
      this.paint();
    });
  }

  // === key handling =========================================================================
  onKey(k) {
    // scrollback paging
    if (k.name === "pageup") { this.scrollback.scrollUp(5); return this.paint(); }
    if (k.name === "pagedown") { this.scrollback.scrollDown(5); return this.paint(); }
    if (k.name === "char" && k.ctrl && k.char === "l") { this.scrollback.scrollToBottom(); return this.paint(); }
    if (k.name === "char" && k.ctrl && k.char === "b") { this.showPanel = !this.showPanel; return this.paint(); }
    // history recall
    if (k.name === "up") { this.input = withCursorEnd(this.history.recall(-1)); return this.paint(); }
    if (k.name === "down") { this.input = withCursorEnd(this.history.recall(+1)); return this.paint(); }
    // submit
    if (k.name === "enter") { this.submit(this.input.value); this.input = { value: "", cursor: 0 }; return this.paint(); }
    // everything else edits the input line
    this.input = editInput(this.input, k);
    this.paint();
  }

  // submit(line) — the Enter intent: expand alias, classify (slash vs send), act.
  submit(line) {
    this.history.submit(line);
    const expanded = expandAlias(this.aliases, line);
    const intent = parseInput(expanded);
    if (intent.kind === "command") return this.runCommand(intent.name, intent.args);
    // a world send: echo locally (CALM dim) unless server-echo is on, then send.
    if (this.world) {
      if (this.world.supports?.localEcho !== false) this.scrollback.pushLocal(expanded, { dim: true });
      this.world.send(intent.text);
    } else {
      this.scrollback.pushLocal("— not connected (/connect host port) —", { fg: "yellow" });
    }
    this.scrollback.scrollToBottom();
  }

  // runCommand(name, args) — the local slash-command dispatch.
  runCommand(name, args) {
    const a = args.trim();
    switch (name) {
      case "quit": return this.stop();
      case "clear": this.scrollback.clear(); break;
      case "help":
        for (const [n, c] of Object.entries(SLASH_COMMANDS)) this.scrollback.pushLocal(c.help, { dim: true });
        break;
      case "audit": this.showAudit = !this.showAudit; this.showPanel = true; break;
      case "connect": {
        const [host, port] = a.split(/\s+/);
        const opts = { ...this.connectOpts };
        if (host) opts.host = host;
        if (port) opts.port = Number(port);
        try { this.world?.close?.(); } catch { /* */ }
        this.world = this.makeWorld(opts);
        this.target = `${opts.host}:${opts.port}`;
        this.connectOpts = opts;
        this.wireWorld(this.world);
        this.connect();
        break;
      }
      case "alias": {
        if (!a) { for (const [k, v] of Object.entries(this.aliases)) this.scrollback.pushLocal(`${k} = ${v}`, { dim: true }); break; }
        const sp = a.indexOf(" ");
        if (sp === -1) { this.scrollback.pushLocal(`alias ${a} = ${this.aliases[a] ?? "(unset)"}`, { dim: true }); break; }
        const key = a.slice(0, sp), tmpl = a.slice(sp + 1);
        this.aliases[key] = tmpl;
        this.scrollback.pushLocal(`— alias ${key} → ${tmpl} —`, { fg: "cyan" });
        break;
      }
      case "unalias": delete this.aliases[a]; this.scrollback.pushLocal(`— unalias ${a} —`, { fg: "cyan" }); break;
      case "trigger": {
        const sp = a.indexOf(" ");
        if (sp === -1) { this.scrollback.pushLocal("usage: /trigger <pattern> <command>", { fg: "yellow" }); break; }
        const pattern = a.slice(0, sp), send = a.slice(sp + 1);
        this.triggers.push({ pattern, send });
        this.scrollback.pushLocal(`— trigger /${pattern}/ → ${send} —`, { fg: "cyan" });
        break;
      }
      default: this.scrollback.pushLocal(`— unknown command: /${name} (/help) —`, { fg: "yellow" });
    }
    this.scrollback.scrollToBottom();
  }
}

function withCursorEnd(value) { return { value: value || "", cursor: (value || "").length }; }

// run(opts) — convenience launcher: build a telnet world from host/port (unless one is injected),
// construct the app, start it. Returns the app.
export function run(opts = {}) {
  let world = opts.world;
  if (!world && opts.host != null && opts.port != null) {
    world = telnetWorld({ host: opts.host, port: opts.port, naws: opts.naws, ttype: opts.ttype });
  }
  const app = new Wheatstone({ ...opts, world });
  app.start();
  return app;
}
