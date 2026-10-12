// Type declarations for @red-cup-engineering/abrash/raycaster.
import type { Vec2 } from "./math.d.ts";
import type { Framebuffer } from "./framebuffer.d.ts";
import type { Grid, Charge } from "./world.d.ts";

export const WALL_COLOR: Readonly<Record<Charge, readonly [number, number, number]>>;

export interface Camera {
  readonly x: number;
  readonly z: number;
  readonly angle: number;
  readonly fov: number;
  readonly width: number;
  readonly height: number;
  readonly maxDist: number;
}

export function camera(opts?: Partial<Camera>): Camera;

export interface RayHit {
  readonly hit: boolean;
  readonly charge: Charge;
  readonly dist: number;
  readonly side: 0 | 1;
  readonly mapX?: number;
  readonly mapZ?: number;
}

export function castRay(g: Grid, ox: number, oz: number, rdx: number, rdz: number, maxDist: number): RayHit;

export interface Census {
  t: number;
  f: number;
  bot: number;
  top: number;
}

export interface Column {
  readonly charge: Charge;
  dist: number;
  readonly drawn: boolean;
  readonly top?: number;
  readonly bot?: number;
  readonly shiver?: number;
  entity?: string | number;
}

export interface Frame {
  readonly fb: Framebuffer;
  readonly columns: readonly Column[];
  readonly census: Census;
  readonly phase: number;
  readonly width: number;
  readonly height: number;
}

// Entity — a floor-plane point object billboarded over the walls (see raycaster.mjs's "billboards"
// section): projected by the same camera transform the wall rays use, depth-tested per column against
// that column's own wall distance so nearer walls occlude it and it occludes farther entities in turn.
export interface Entity {
  readonly id: string | number;
  readonly x: number;
  readonly z: number;
  readonly color?: readonly [number, number, number];
  readonly scale?: number;
}

export function render(
  world: Grid | unknown,
  cam: Camera,
  opts?: { phase?: number; tile?: number; entities?: readonly Entity[] },
): Frame;
