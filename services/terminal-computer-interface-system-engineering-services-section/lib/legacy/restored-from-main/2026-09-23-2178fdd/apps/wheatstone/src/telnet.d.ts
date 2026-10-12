// telnet.d.ts — hand-written types for src/telnet.mjs, the CLIENT-perspective telnet codec.
// The wire-alphabet constants and byte helpers below are re-exported from
// @red-cup-engineering/feltos/telnet (a plain .mjs with no published types of its own), plus the
// two client-only prompt-mark constants (GA, EOR_MARK) telnet.mjs defines locally.

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

export function bytesOf(s: string): Buffer;
export function escapeIAC(buf: Buffer | number[]): Buffer;
export function parseMSDP(bytes: Buffer | Uint8Array | number[]): Record<string, unknown>;

export const WHEATSTONE_VERSION: string;

export interface Supports {
  gmcp: boolean;
  msdp: boolean;
  mxp: boolean;
  sga: boolean;
  eor: boolean;
  echo: boolean;
  compress2: boolean;
  compressionActive: boolean;
  localEcho: boolean;
  naws?: boolean;
  ttype?: boolean;
}

export interface ClientTelnetOpts {
  write: (bytes: Buffer) => void;
  naws?: { width: number; height: number };
  ttype?: string;
  accept?: { serverWill?: number[]; serverDo?: number[] };
  acceptCompression?: boolean;
  onError?: (error: Error) => void;
}

export type Unsubscribe = () => void;

export interface ClientTelnet {
  feed(chunk: Buffer | Uint8Array | string): void;
  onLine(cb: (line: string) => void): Unsubscribe;
  onPrompt(cb: (text: string) => void): Unsubscribe;
  onGMCP(cb: (pkg: string, data: unknown) => void): Unsubscribe;
  onMSDP(cb: (obj: Record<string, unknown>) => void): Unsubscribe;
  onNegotiate(cb: (supports: Supports) => void): Unsubscribe;
  send(text: string): void;
  sendLine(text: string): void;
  sendGMCP(pkg: string, data?: unknown): void;
  sendNAWS(w?: number, h?: number): void;
  end(): void;
  supports: Supports;
}

export function clientTelnet(opts: ClientTelnetOpts): ClientTelnet;
export default clientTelnet;
