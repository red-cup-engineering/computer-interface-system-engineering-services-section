// Type declarations for @red-cup-engineering/abrash/federation.

export interface Row {
  readonly e: string;
  readonly a: string;
  readonly v: unknown;
  readonly t: unknown;
}

export type World = ReadonlyMap<string, readonly Row[]>;

export interface FoldedCellValue {
  readonly pos: 0 | 1;
  readonly neg: 0 | 1;
  readonly evidence: readonly [readonly string[], readonly string[]];
}

export interface FoldedCell {
  readonly predicate: string;
  readonly object: unknown;
  readonly value: FoldedCellValue;
}

export interface Folded {
  readonly entity: string;
  readonly fiber: readonly FoldedCell[];
}

export interface Section {
  readonly affirmed: readonly { predicate: string; object: unknown }[];
  readonly denied: readonly { predicate: string; object: unknown }[];
  readonly contradicted: readonly { predicate: string; object: unknown }[];
}

export interface SettleOpts {
  readonly converse?: Record<string, string>;
  readonly functional?: Set<string> | ((predicate: string) => boolean);
  readonly retract?: boolean;
}

export interface Disagreement {
  readonly subject: string;
  readonly predicate: string;
  readonly object: unknown;
  readonly evidence: readonly [readonly string[], readonly string[]];
}

export function emptyWorld(): World;
export function logFor(world: World, subject: string): readonly Row[];
export function subjects(world: World): readonly string[];
export function allRows(world: World): readonly Row[];
export function admitLog(world: World, subject: string, rows: readonly Row[]): { world: World; appended: number };
export function federate(a: World, b: World): World;
export function mergeWorlds(...worlds: readonly World[]): World;
export function frontier(world: World, subject: string, opts?: SettleOpts): Folded;
export function sectionOf(world: World, subject: string, opts?: SettleOpts): Section;
export function disagreements(world: World, opts?: SettleOpts): readonly Disagreement[];
export function migrate(world: World, mapSubject: (subject: string) => string): World;
