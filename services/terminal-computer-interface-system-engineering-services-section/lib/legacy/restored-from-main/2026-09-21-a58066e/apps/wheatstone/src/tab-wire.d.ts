// tab-wire.d.ts — hand-written types for src/tab-wire.mjs (a local shim; see its header).

export const IAC: 255;
export const DONT: 254;
export const DO: 253;
export const WONT: 252;
export const WILL: 251;
export const SB: 250;
export const SE: 240;
export const GA: 249;
export const EOR_MARK: 239;
export const COMPRESS2: 86;
export const MXP: 91;
export const GMCP: 201;
export const MSDP: 69;
export const ECHO: 1;
export const SGA: 3;
export const EOR: 25;
export const TTYPE: 24;
export const NAWS: 31;
export const CHARSET: 42;
export const MSDP_VAR: 1;
export const MSDP_VAL: 2;
export const MSDP_TABLE_OPEN: 3;
export const MSDP_TABLE_CLOSE: 4;
export const MSDP_ARRAY_OPEN: 5;
export const MSDP_ARRAY_CLOSE: 6;

export function bytesOf(s: string): Buffer;
export function escapeIAC(buf: Buffer | number[]): Buffer;
export function parseMSDP(bytes: Buffer | Uint8Array | number[]): Record<string, unknown>;
