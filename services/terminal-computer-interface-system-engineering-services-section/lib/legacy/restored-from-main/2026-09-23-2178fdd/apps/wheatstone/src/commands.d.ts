// commands.d.ts — hand-written types for src/commands.mjs.

export class History {
  items: string[];
  cap: number;
  cursor: number;
  constructor(cap?: number);
  submit(line: string): this;
  recall(dir: 1 | -1): string;
}

export function expandAlias(aliases: Record<string, string>, line: string): string;

export interface Trigger {
  pattern: string | RegExp;
  send?: string | ((fired: { trigger: Trigger; line: string; groups: string[] }) => string);
}

export interface FiredTrigger {
  trigger: Trigger;
  line: string;
  groups: string[];
}

export function matchTriggers(triggers: Trigger[], line: string): FiredTrigger[];

export type ParsedInput =
  | { kind: "command"; name: string; args: string }
  | { kind: "send"; text: string };

export function parseInput(line: string): ParsedInput;

export const SLASH_COMMANDS: Record<string, { help: string }>;
