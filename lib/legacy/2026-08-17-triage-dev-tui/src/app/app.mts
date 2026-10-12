import { History, expandAlias, matchTriggers, parseInput, SLASH_COMMANDS, type AliasMap, type Trigger } from "@emsenn/computing-with-cli";
import { Scrollback, type CellBuffer, type Rect } from "@emsenn/computing-with-terminal/buffer";
import { view, type TerminalViewState } from "@emsenn/computing-with-terminal/screen";
import { editInput, type InputState, type Keypress } from "@emsenn/computing-with-terminal/widgets";
import {
  localWorld,
  MemeticTerminalSession,
  telnetWorld,
  WorldState,
  type MemeticTerminalSessionOptions,
  type Unsubscribe,
  type World,
  type WorldStatus,
} from "@emsenn/computing-with-terminal/world";

export type ScreenLike = Readonly<{
  start?: () => unknown;
  stop?: () => unknown;
  onKey?: (cb: (key: Keypress) => void) => unknown;
  onInterrupt?: (cb: () => void) => unknown;
  render: (draw: (buf: CellBuffer, area: Rect) => void) => unknown;
}>;

export type TerminalInterfaceOptions = Readonly<{
  name?: string;
  screen?: ScreenLike;
  world?: World;
  target?: string;
  host?: string;
  port?: number;
  naws?: { width: number; height: number };
  ttype?: string;
  scrollbackCap?: number;
  aliases?: AliasMap;
  triggers?: readonly Trigger[];
  showPanel?: boolean;
  memeticfs?: string | MemeticTerminalSession | MemeticTerminalSessionOptions;
  makeWorld?: (options: { host?: string; port: number; naws?: { width: number; height: number }; ttype?: string }) => World;
  exit?: (code: number) => void;
}>;

export class TerminalInterface {
  readonly name: string;
  readonly screen: ScreenLike;
  readonly makeWorld: NonNullable<TerminalInterfaceOptions["makeWorld"]>;
  readonly exit: (code: number) => void;
  world: World | null;
  target: string;
  connectOpts: { host?: string; port?: number; naws?: { width: number; height: number }; ttype?: string };
  scrollback: Scrollback;
  worldstate = new WorldState();
  history = new History();
  input: InputState = { value: "", cursor: 0 };
  aliases: AliasMap;
  triggers: Trigger[];
  status: WorldStatus = { state: "idle" };
  prompt = "";
  showPanel: boolean;
  showAudit = false;
  memetic: MemeticTerminalSession | null;
  private unsub: Unsubscribe[] = [];
  private exiting = false;

  constructor(options: TerminalInterfaceOptions = {}) {
    this.name = options.name ?? "terminal-interface";
    this.screen = options.screen ?? { render: () => {} };
    this.world = options.world ?? null;
    this.target = options.target ?? (this.world ? this.world.kind : "");
    this.makeWorld = options.makeWorld ?? ((o) => telnetWorld({
      ...(o.host === undefined ? {} : { host: o.host }),
      port: o.port,
      ...(o.naws === undefined ? {} : { naws: o.naws }),
      ...(o.ttype === undefined ? {} : { ttype: o.ttype }),
    }));
    this.exit = options.exit ?? (() => {});
    this.connectOpts = {
      ...(options.host === undefined ? {} : { host: options.host }),
      ...(options.port === undefined ? {} : { port: options.port }),
      ...(options.naws === undefined ? {} : { naws: options.naws }),
      ...(options.ttype === undefined ? {} : { ttype: options.ttype }),
    };
    this.scrollback = new Scrollback(options.scrollbackCap === undefined ? {} : { cap: options.scrollbackCap });
    this.aliases = { ...(options.aliases ?? {}) };
    this.triggers = [...(options.triggers ?? [])];
    this.showPanel = options.showPanel ?? false;
    this.memetic = resolveMemeticSession(options.memeticfs);
  }

  state(): TerminalViewState {
    return {
      name: this.name,
      scrollback: this.scrollback,
      world: this.worldstate,
      input: this.input,
      status: this.status,
      showPanel: this.showPanel,
      showAudit: this.showAudit,
      prompt: this.prompt,
      ...(this.target ? { target: this.target } : {}),
    };
  }

  paint(): void {
    this.screen.render(view(this.state()));
  }

  start(): this {
    this.screen.start?.();
    this.screen.onKey?.((key) => this.onKey(key));
    this.screen.onInterrupt?.(() => this.stop());
    this.scrollback.pushLocal(`${this.name} - /help for local commands, /connect to begin`, { dim: true });
    this.recordMemetic("session.start", { name: this.name, target: this.target || null });
    if (this.world) {
      this.wireWorld(this.world);
      this.connect();
    }
    this.paint();
    return this;
  }

  stop(): void {
    this.recordMemetic("session.stop", { name: this.name, target: this.target || null, status: this.status.state });
    try { this.world?.close(); } catch { /* ignore */ }
    this.screen.stop?.();
    if (this.exiting) return;
    this.exiting = true;
    this.exit(0);
  }

  connect(): void {
    if (!this.world) return;
    Promise.resolve(this.world.connect()).catch((err: unknown) => {
      this.status = { state: "error", detail: { message: err instanceof Error ? err.message : String(err) } };
      this.scrollback.pushLocal(`connect failed: ${String(this.status.detail?.message ?? err)}`, { fg: "red" });
      this.paint();
    });
  }

  wireWorld(world: World): void {
    for (const off of this.unsub) {
      try { off(); } catch { /* ignore */ }
    }
    this.unsub = [
      world.onLine((line) => {
        this.scrollback.push(line);
        this.recordMemetic("output.line", { line, world: world.kind, target: this.target || null });
        for (const fired of matchTriggers(this.triggers, line)) {
          if (fired.trigger.send) world.send(typeof fired.trigger.send === "function" ? fired.trigger.send(fired) : fired.trigger.send);
        }
        this.prompt = "";
        this.paint();
      }),
      world.onPrompt((text) => {
        this.prompt = text;
        this.recordMemetic("output.prompt", { text, world: world.kind, target: this.target || null });
        this.paint();
      }),
      world.onGMCP((pkg, data) => {
        this.worldstate.applyGMCP(pkg, data);
        this.recordMemetic("world.gmcp", { pkg, data, world: world.kind, target: this.target || null });
        this.recordWorldEvidence();
        this.paint();
      }),
      world.onMSDP((obj) => {
        this.worldstate.applyMSDP(obj);
        this.recordMemetic("world.msdp", { obj, world: world.kind, target: this.target || null });
        this.recordWorldEvidence();
        this.paint();
      }),
      world.onStatus((status) => {
        this.status = status;
        this.recordMemetic("world.status", { status, world: world.kind, target: this.target || null });
        if (status.state === "connected") this.scrollback.pushLocal(`connected to ${this.target || world.kind}`, { fg: "green" });
        else if (status.state === "error") this.scrollback.pushLocal(`error: ${String(status.detail?.message ?? "")}`, { fg: "red" });
        else if (status.state === "closed") this.scrollback.pushLocal("disconnected", { fg: "yellow" });
        this.paint();
      }),
      world.onNegotiate((supports) => {
        this.recordMemetic("world.negotiation", { supports, world: world.kind, target: this.target || null });
      }),
    ];
  }

  onKey(key: Keypress): void {
    if (key.name === "pageup") { this.scrollback.scrollUp(5); this.paint(); return; }
    if (key.name === "pagedown") { this.scrollback.scrollDown(5); this.paint(); return; }
    if (key.name === "char" && key.ctrl && key.char === "l") { this.scrollback.scrollToBottom(); this.paint(); return; }
    if (key.name === "char" && key.ctrl && key.char === "b") { this.showPanel = !this.showPanel; this.paint(); return; }
    if (key.name === "up") { this.input = endCursor(this.history.recall(-1)); this.paint(); return; }
    if (key.name === "down") { this.input = endCursor(this.history.recall(1)); this.paint(); return; }
    if (key.name === "enter") {
      this.submit(this.input.value);
      this.input = { value: "", cursor: 0 };
      this.paint();
      return;
    }
    this.input = editInput(this.input, key);
    this.paint();
  }

  submit(line: string): void {
    this.history.submit(line);
    const expanded = expandAlias(this.aliases, line);
    const intent = parseInput(expanded);
    this.recordMemetic(intent.kind === "command" ? "command" : "input", {
      line,
      expanded,
      intent,
      target: this.target || null,
    });
    if (intent.kind === "command") {
      this.runCommand(intent.name, intent.args);
      return;
    }
    if (this.world) {
      if (this.world.supports.localEcho !== false) this.scrollback.pushLocal(expanded, { dim: true });
      this.world.send(intent.text);
    } else {
      this.scrollback.pushLocal("not connected (/connect host port)", { fg: "yellow" });
    }
    this.scrollback.scrollToBottom();
  }

  runCommand(name: string, args: string): void {
    const a = args.trim();
    switch (name) {
      case "quit":
        this.stop();
        return;
      case "clear":
        this.scrollback.clear();
        break;
      case "help":
        for (const command of Object.values(SLASH_COMMANDS)) this.scrollback.pushLocal(command.help, { dim: true });
        break;
      case "audit":
        this.showAudit = !this.showAudit;
        this.showPanel = true;
        break;
      case "connect": {
        const [host, port] = a.split(/\s+/);
        const nextPort = port ? Number(port) : this.connectOpts.port;
        if (!nextPort) {
          this.scrollback.pushLocal("usage: /connect host port", { fg: "yellow" });
          break;
        }
        const opts = {
          ...(this.connectOpts.host === undefined ? {} : { host: this.connectOpts.host }),
          ...(this.connectOpts.naws === undefined ? {} : { naws: this.connectOpts.naws }),
          ...(this.connectOpts.ttype === undefined ? {} : { ttype: this.connectOpts.ttype }),
          ...(host ? { host } : {}),
          port: nextPort,
        };
        try { this.world?.close(); } catch { /* ignore */ }
        this.world = this.makeWorld(opts);
        this.target = `${opts.host ?? "127.0.0.1"}:${opts.port}`;
        this.connectOpts = opts;
        this.wireWorld(this.world);
        this.connect();
        break;
      }
      case "alias": {
        if (!a) {
          for (const [key, value] of Object.entries(this.aliases)) this.scrollback.pushLocal(`${key} = ${value}`, { dim: true });
          break;
        }
        const sp = a.indexOf(" ");
        if (sp === -1) {
          this.scrollback.pushLocal(`alias ${a} = ${this.aliases[a] ?? "(unset)"}`, { dim: true });
          break;
        }
        const key = a.slice(0, sp);
        const template = a.slice(sp + 1);
        this.aliases[key] = template;
        this.scrollback.pushLocal(`alias ${key} = ${template}`, { fg: "cyan" });
        break;
      }
      case "unalias":
        delete this.aliases[a];
        this.scrollback.pushLocal(`unalias ${a}`, { fg: "cyan" });
        break;
      case "trigger": {
        const sp = a.indexOf(" ");
        if (sp === -1) {
          this.scrollback.pushLocal("usage: /trigger <pattern> <command>", { fg: "yellow" });
          break;
        }
        this.triggers.push({ pattern: a.slice(0, sp), send: a.slice(sp + 1) });
        this.scrollback.pushLocal(`trigger ${a.slice(0, sp)} -> ${a.slice(sp + 1)}`, { fg: "cyan" });
        break;
      }
      default:
        this.scrollback.pushLocal(`unknown command: /${name} (/help)`, { fg: "yellow" });
    }
    this.scrollback.scrollToBottom();
  }

  private recordMemetic(kind: Parameters<MemeticTerminalSession["record"]>[0], object: unknown): void {
    if (!this.memetic) return;
    this.memetic.record(kind, object).catch((error: unknown) => {
      this.memetic?.record("error", {
        during: kind,
        message: error instanceof Error ? error.message : String(error),
      }, { negative: true }).catch(() => {});
    });
  }

  private recordWorldEvidence(): void {
    if (!this.memetic) return;
    this.memetic.recordWorldState(this.worldstate, { includeRaw: false }).catch((error: unknown) => {
      this.memetic?.record("error", {
        during: "world.evidence",
        message: error instanceof Error ? error.message : String(error),
      }, { negative: true }).catch(() => {});
    });
  }
}

export const Wheatstone = TerminalInterface;

export function run(options: TerminalInterfaceOptions = {}): TerminalInterface {
  let world = options.world;
  if (!world && options.port !== undefined) {
    world = telnetWorld({
      ...(options.host === undefined ? {} : { host: options.host }),
      port: options.port,
      ...(options.naws === undefined ? {} : { naws: options.naws }),
      ...(options.ttype === undefined ? {} : { ttype: options.ttype }),
    });
  }
  return new TerminalInterface({ ...options, ...(world ? { world } : {}) }).start();
}

export function demoWorld(): World {
  return localWorld({
    kind: "demo",
    onConnect: (emit) => {
      emit.line("Welcome to the local terminal-interface demo.");
      emit.gmcp("Char.Vitals", { hp: 50, maxhp: 50 });
      emit.gmcp("Room.Info", { name: "Interface Lab", exits: ["out"] });
    },
    onSend: (text, emit) => { emit.line(`you said: ${text}`); },
  });
}

function endCursor(value: string): InputState {
  return { value, cursor: value.length };
}

function resolveMemeticSession(input: TerminalInterfaceOptions["memeticfs"]): MemeticTerminalSession | null {
  if (input === undefined) return null;
  if (input instanceof MemeticTerminalSession) return input;
  if (typeof input === "string") return new MemeticTerminalSession(input);
  return new MemeticTerminalSession(input);
}
