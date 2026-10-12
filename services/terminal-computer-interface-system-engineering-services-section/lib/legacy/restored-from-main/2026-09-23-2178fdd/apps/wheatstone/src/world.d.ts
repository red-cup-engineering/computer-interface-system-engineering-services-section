// world.d.ts — hand-written types for src/world.mjs, the pluggable carrier seam.

import type { Supports, Unsubscribe } from "./telnet.mjs";

export interface StatusEvent {
  state: "connecting" | "connected" | "error" | "closed" | string;
  detail?: Record<string, unknown>;
}

export interface World {
  kind: string;
  connect(): Promise<void>;
  send(text: string): void;
  close(): void;
  onLine(cb: (line: string) => void): Unsubscribe;
  onPrompt?(cb: (text: string) => void): Unsubscribe;
  onGMCP(cb: (pkg: string, data: unknown) => void): Unsubscribe;
  onMSDP?(cb: (obj: Record<string, unknown>) => void): Unsubscribe;
  onNegotiate?(cb: (supports: Supports) => void): Unsubscribe;
  onStatus?(cb: (s: StatusEvent) => void): Unsubscribe;
  readonly supports: Supports | Record<string, never>;
}

export interface TelnetWorldOpts {
  host?: string;
  port: number;
  naws?: { width: number; height: number };
  ttype?: string;
  createConnection?: typeof import("node:net").createConnection;
}

export function telnetWorld(opts: TelnetWorldOpts): World & { _telnet: import("./telnet.mjs").ClientTelnet };

export interface LocalWorldEmit {
  line(l: string): void;
  gmcp(pkg: string, data: unknown): void;
  msdp(obj: Record<string, unknown>): void;
  prompt(t: string): void;
}

export interface LocalWorldSpec {
  kind?: string;
  onConnect?: (emit: LocalWorldEmit) => Promise<void> | void;
  onSend?: (text: string, emit: LocalWorldEmit) => void;
  onClose?: () => void;
}

export function localWorld(spec?: LocalWorldSpec): World & { emit: LocalWorldEmit };
