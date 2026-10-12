// Type declarations for @red-cup-engineering/abrash/world. The federation types below (World, Row,
// Folded, Section, SettleOpts, Disagreement) and the emptyWorld/federate/mergeWorlds/admitLog/migrate/
// subjects/logFor/allRows/frontier/sectionOf functions are this module's own consumption of the
// published @red-cup-engineering/computer/distribution algebra (migrate here is that package's
// migrateSubjects — a bulk namespace re-key, distinct from its own two-world migrate).

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
export function admitLog(world: World, subject: string, rows: readonly Row[]): { world: World; added: number; skipped: number };
export function federate(a: World, b: World): World;
export function mergeWorlds(...worlds: readonly World[]): World;
export function frontier(world: World, subject: string, opts?: SettleOpts): Folded;
export function sectionOf(world: World, subject: string, opts?: SettleOpts): Section;
export function migrate(world: World, mapSubject: (subject: string) => string): World;

export function rowId(row: Row): string;
export function assertRow(row: unknown): Row;
export function relate(rows: readonly Row[], predicate: string, object: unknown): readonly string[];
export function relateFrom(rows: readonly Row[], subject: string, predicate: string): readonly unknown[];

export const CONVERSE: Readonly<Record<string, string>>;
export function predicate(s: string, p: string, o: unknown, t?: unknown): Row;
export function deny(s: string, p: string, o: unknown, t?: unknown): Row;
export function worldFromRows(rows: readonly Row[]): World;
export function settleOpts(opts?: SettleOpts): Required<Pick<SettleOpts, "converse" | "functional">> & SettleOpts;
export function disagreements(world: World, opts?: SettleOpts): readonly Disagreement[];

export type Charge = "t" | "f" | "bot" | "top";
export const FOUR: { readonly T: "t"; readonly F: "f"; readonly BOT: "bot"; readonly TOP: "top" };

export function chargeOf(value: { pos?: unknown; neg?: unknown } | undefined): Charge;

export interface Place {
  readonly subject: string;
  readonly folded: Folded;
  readonly section: Section;
  readonly contested: readonly { predicate: string; object: unknown; evidence: unknown }[];
  readonly visited: boolean;
  readonly charge: Charge;
}

export function place(world: World, subject: string, opts?: SettleOpts): Place;
export function cellKey(x: number, z: number): string;

export interface SolidityResult {
  readonly charge: Charge;
  readonly subject: string;
}

export function solidityAt(world: World, x: number, z: number, opts?: SettleOpts): SolidityResult;

export interface GridCell {
  readonly x: number;
  readonly z: number;
  readonly charge: Charge;
}

export interface Grid {
  readonly cells: ReadonlyMap<string, GridCell>;
  readonly bounds: { minX: number; maxX: number; minZ: number; maxZ: number };
  at(x: number, z: number): GridCell;
}

export function grid(world: World, opts?: SettleOpts): Grid;
