// Type declarations for @red-cup-engineering/abrash/math.

export type Vec2 = readonly [number, number];

export const v2: {
  create(x?: number, y?: number): Vec2;
  add(a: Vec2, b: Vec2): Vec2;
  sub(a: Vec2, b: Vec2): Vec2;
  scale(a: Vec2, s: number): Vec2;
  dot(a: Vec2, b: Vec2): number;
  length(a: Vec2): number;
  normalize(a: Vec2): Vec2;
  perp(a: Vec2): Vec2;
  rotate(a: Vec2, ang: number): Vec2;
};

export function dir(angle: number): Vec2;
export function clampInt(n: number, lo: number, hi: number): number;
export function mix(a: number, b: number, t: number): number;
