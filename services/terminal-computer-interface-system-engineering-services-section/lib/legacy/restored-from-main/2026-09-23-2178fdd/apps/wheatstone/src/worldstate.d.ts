// worldstate.d.ts — hand-written types for src/worldstate.mjs.

import type { AnsiStyle } from "./ansi-text.mjs";

export interface AuditEntry {
  value: unknown;
  source: string;
  seq: number;
}

export interface StatusSlots {
  left: string;
  center: string;
  right: string;
}

export interface PanelLine {
  text: string;
  style?: AnsiStyle;
}

export class WorldState {
  vitals: Record<string, unknown>;
  room: Record<string, unknown>;
  char: Record<string, unknown>;
  who: unknown[];
  raw: Record<string, unknown>;
  audit: Record<string, AuditEntry[]>;
  constructor();
  applyGMCP(pkg: string, data: unknown): this;
  applyMSDP(obj: Record<string, unknown>): this;
  statusSlots(): StatusSlots;
  panelLines(opts?: { audit?: boolean }): PanelLine[];
}
