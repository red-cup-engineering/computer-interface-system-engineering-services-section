// Type declarations for @red-cup-engineering/abrash/collision.
import type { Grid, Charge } from "./world.d.ts";

export interface CollisionOpts {
  readonly passContested?: boolean;
}

export function blocks(charge: Charge, opts?: CollisionOpts): boolean;
export function occupied(g: Grid, x: number, z: number, radius: number, opts?: CollisionOpts): boolean;

export interface Body {
  readonly x: number;
  readonly z: number;
  readonly radius?: number;
}

export interface MoveResult {
  readonly body: Body;
  readonly hit: { readonly x: boolean; readonly z: boolean };
}

export function move(g: Grid, body: Body, dx: number, dz: number, opts?: CollisionOpts): MoveResult;
export function clearAhead(g: Grid, body: Body, dirx: number, dirz: number, maxDist: number, opts?: CollisionOpts): number;
