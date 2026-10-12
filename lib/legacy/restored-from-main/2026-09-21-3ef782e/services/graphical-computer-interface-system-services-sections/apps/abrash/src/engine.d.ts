// Type declarations for @red-cup-engineering/abrash/engine.
import type { Camera, Frame } from "./raycaster.d.ts";
import type { World, Row, Grid } from "./world.d.ts";

export { worldFromRows as makeWorld } from "./world.d.ts";
export { grid, place, predicate, deny, cellKey, allRows, FOUR } from "./world.d.ts";

export interface Player {
  readonly x: number;
  readonly z: number;
  readonly angle: number;
  readonly radius: number;
  readonly moveSpeed: number;
  readonly turnSpeed: number;
}

export interface Unit {
  readonly subject: string;
  readonly behavior?: (world: World, ctx: { t: unknown; phase: number; player: Player }) => readonly Row[] | void;
}

export interface Scene {
  readonly world: World;
  readonly player: Player;
  readonly phase: number;
  readonly cam: Partial<Camera>;
  readonly units: readonly Unit[];
  readonly log: readonly unknown[];
  readonly frame?: Frame;
  readonly camera?: Camera;
  readonly unitResults?: readonly { subject: string; appended: number }[];
}

export interface Intent {
  readonly forward?: number;
  readonly strafe?: number;
  readonly turn?: number;
}

export function scene(opts?: {
  world?: World;
  player?: Partial<Player>;
  phase?: number;
  cam?: Partial<Camera>;
  units?: readonly Unit[];
}): Scene;

export function applyIntent(
  g: Grid, player: Player, intent?: Intent, opts?: unknown
): { player: Player; hit: { x: boolean; z: boolean } };

export function runUnit(world: World, unit: Unit, ctx?: unknown): readonly Row[];

export function tick(state: Scene, opts?: { t?: unknown; intent?: Intent; width?: number; height?: number }): Scene;

export function walk(
  state: Scene, intents: readonly Intent[], opts?: unknown
): { scene: Scene; frames: readonly Frame[] };

export function run(args: {
  scene: Scene;
  onFrame?: (frame: Frame, scene: Scene) => boolean | void;
  interval?: number;
  ticks?: number;
  width?: number;
  height?: number;
  nextIntent?: (scene: Scene) => Intent;
}): Promise<Scene>;
