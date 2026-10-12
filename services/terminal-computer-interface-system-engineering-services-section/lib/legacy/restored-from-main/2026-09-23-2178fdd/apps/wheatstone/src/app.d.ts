// app.d.ts — hand-written types for src/app.mjs, the composition root.

import type { Screen } from "@red-cup-engineering/arnold/app";
import type { KeyEvent } from "@red-cup-engineering/terminal-user-interface-engine";
import { Scrollback } from "./scrollback.mjs";
import { WorldState } from "./worldstate.mjs";
import { History, type Trigger } from "./commands.mjs";
import type { World } from "./world.mjs";
import type { ViewState } from "./render.mjs";

export interface FakeScreen {
  start?(): unknown;
  stop?(): unknown;
  onKey?(fn: (k: KeyEvent) => void): unknown;
  onInterrupt?(fn: () => void): unknown;
  render(draw: (buf: unknown, rect: unknown) => void): unknown;
}

export interface WheatstoneOpts {
  screen?: Screen | FakeScreen;
  world?: World | null;
  name?: string;
  exit?: (code: number) => unknown;
  target?: string;
  host?: string;
  port?: number;
  naws?: { width: number; height: number };
  ttype?: string;
  makeWorld?: (opts: Record<string, unknown>) => World;
  scrollbackCap?: number;
  aliases?: Record<string, string>;
  triggers?: Trigger[];
  showPanel?: boolean;
}

export class Wheatstone {
  screen: Screen | FakeScreen;
  world: World | null;
  name: string;
  exit: (code: number) => unknown;
  target: string;
  scrollback: Scrollback;
  worldstate: WorldState;
  history: History;
  input: { value: string; cursor: number };
  aliases: Record<string, string>;
  triggers: Trigger[];
  status: { state: string; detail?: Record<string, unknown> };
  prompt: string;
  showPanel: boolean;
  showAudit: boolean;
  constructor(opts?: WheatstoneOpts);
  state(): ViewState;
  paint(): void;
  wireWorld(world: World | null): void;
  start(): this;
  stop(): void;
  connect(): void;
  onKey(k: KeyEvent): void;
  submit(line: string): void;
  runCommand(name: string, args: string): void;
}

export function run(opts?: WheatstoneOpts & { host?: string; port?: number }): Wheatstone;
