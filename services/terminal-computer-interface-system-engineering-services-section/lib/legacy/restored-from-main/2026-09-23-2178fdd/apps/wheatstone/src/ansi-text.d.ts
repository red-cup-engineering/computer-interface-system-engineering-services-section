// ansi-text.d.ts — hand-written types for src/ansi-text.mjs.

export interface AnsiStyle {
  fg?: string | number | { r: number; g: number; b: number };
  bg?: string | number | { r: number; g: number; b: number };
  bold?: boolean;
  dim?: boolean;
  italic?: boolean;
  underline?: boolean;
  inverse?: boolean;
  strike?: boolean;
}

export function applySGR(style: AnsiStyle, params: number[]): AnsiStyle;

export interface Segment {
  text: string;
  style: AnsiStyle;
}

export interface ParsedAnsi {
  segments: Segment[];
  style: AnsiStyle;
}

export function parseAnsi(line: string, initialStyle?: AnsiStyle): ParsedAnsi;
export function hasAnsi(line: string): boolean;
