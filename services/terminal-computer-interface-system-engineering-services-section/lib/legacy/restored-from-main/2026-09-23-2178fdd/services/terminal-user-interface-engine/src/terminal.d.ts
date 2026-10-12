export interface KeyEvent {
  name: string;
  char?: string;
  ctrl: boolean;
  meta: boolean;
  shift: boolean;
  raw: string;
}

export interface TerminalCapabilities {
  graphics: "kitty" | "sixel" | "none";
  why: string;
  tty?: boolean;
}

export const enterAlternateScreen: string;
export const leaveAlternateScreen: string;
export const hideCursor: string;
export const showCursor: string;
export const resetStyle: string;
export const clearScreen: string;
export const cursorHome: string;
export const GRAPHICS_PROTOCOLS: readonly ["kitty", "sixel", "none"];

export function parseKey(sequence: string): KeyEvent;
export function splitKeys(input: string): string[];
export function detectTerminalCapabilities(
  env?: Record<string, string | undefined>,
  options?: { graphicsOverride?: string; overrideName?: string },
): TerminalCapabilities;
export function probeTerminal(
  stream?: { isTTY?: boolean },
  env?: Record<string, string | undefined>,
  options?: { graphicsOverride?: string; overrideName?: string },
): TerminalCapabilities & { tty: boolean };

export class Keyboard {
  constructor(stream?: unknown);
  start(): this;
  stop(): this;
  on(event: "key" | "interrupt", listener: (event: KeyEvent) => void): this;
}

export class TerminalSession {
  constructor(options?: {
    input?: unknown;
    output?: unknown;
    env?: Record<string, string | undefined>;
    keyboard?: Keyboard;
    graphicsOverride?: string;
    overrideName?: string;
  });
  input: unknown;
  output: { columns?: number; rows?: number; write(bytes: string): unknown };
  keyboard: Keyboard;
  capabilities: TerminalCapabilities & { tty: boolean };
  readonly started: boolean;
  readonly columns: number;
  readonly rows: number;
  size(): { columns: number; rows: number };
  write(bytes: string): this;
  start(): this;
  stop(): this;
  onKey(handler: (event: KeyEvent) => void): this;
  onInterrupt(handler: (event: KeyEvent) => void): this;
  onResize(handler: (size: { columns: number; rows: number }) => void): this;
  offResize(handler: (size: { columns: number; rows: number }) => void): this;
  beforeStop(handler: (terminal: TerminalSession) => void): this;
  offBeforeStop(handler: (terminal: TerminalSession) => void): this;
}
