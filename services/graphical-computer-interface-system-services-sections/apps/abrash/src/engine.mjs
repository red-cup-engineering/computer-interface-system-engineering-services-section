// engine — the tick/realtime LOOP that ties the engine's concerns together: the federated-trace WORLD
// (world.mjs), the software RAYCASTER (raycaster.mjs), and grid COLLISION (collision.mjs). A tick is one
// turn of the core loop, but with NO global clock to wait on (the substrate is "aperiodic settling, not
// stepping"): a tick reads the world the player sees, applies the player's intent (a move, resolved
// against the voxel grid), runs each unit's behavior (which may APPEND predications — including the ⊤
// both-faces append that contests a voxel), and projects a 3D frame. The world only advances when
// predications are appended — by the player, by a unit, or by a peer federating in. The loop re-grids,
// re-collides, re-projects.
//
// Pure where it can be: `tick` takes a scene + an intent and returns a NEW scene + frame, appending
// rows rather than mutating. The realtime driver (`run`) is the thin imperative shell that calls tick on
// an interval and hands the frame to a renderer (a canvas paint, or a test). A browser face should drive
// its own tick loop off requestAnimationFrame instead of this module's setTimeout `run`, which exists
// for a headless/test driver that wants ticks on an interval without a browser.

import {
  worldFromRows, admitLog, grid, place, predicate, deny, cellKey, allRows, FOUR,
} from "./world.mjs";
import { camera, render } from "./raycaster.mjs";
import { move } from "./collision.mjs";

// makeWorld(rows) — a world from a seed of {e,a,v,t} rows (the shipped seed `.jsonl`).
export { worldFromRows as makeWorld };

// scene(opts) — the per-session state the loop carries: the world, the player (position + heading +
// radius), the tick phase (drives the ⊤ shiver), the camera config, and the units whose behaviors run
// each tick. A unit is { subject, behavior } — its trace subject and a pure function returning the rows
// it wishes to append this tick.
export function scene(opts = {}) {
  return {
    world: opts.world,
    player: {
      x: opts.player?.x ?? 1.5,
      z: opts.player?.z ?? 1.5,
      angle: opts.player?.angle ?? 0,
      radius: opts.player?.radius ?? 0.2,
      moveSpeed: opts.player?.moveSpeed ?? 0.2,
      turnSpeed: opts.player?.turnSpeed ?? 0.12,
    },
    phase: opts.phase ?? 0,
    cam: opts.cam ?? {}, // fov/width/height/maxDist; position/angle filled from the player at render
    units: opts.units ?? [],
    log: [], // an append-only record of what each tick did (for audit)
  };
}

// applyIntent(grid, player, intent) — resolve a player intent against the voxel grid. An intent is
// { forward, strafe, turn } each a signed magnitude (e.g. -1/0/1). Turning rotates the heading; forward/
// strafe move along/across the heading, resolved by collision.move so the player slides on walls and
// CANNOT walk through a t or ⊤ voxel. Pure — returns a new player.
export function applyIntent(g, player, intent = {}, opts = {}) {
  const turn = (intent.turn ?? 0) * player.turnSpeed;
  const angle = player.angle + turn;
  const fwd = (intent.forward ?? 0) * player.moveSpeed;
  const str = (intent.strafe ?? 0) * player.moveSpeed;
  // forward is along the heading; strafe is along its right-hand perpendicular.
  const dx = Math.cos(angle) * fwd + Math.cos(angle + Math.PI / 2) * str;
  const dz = Math.sin(angle) * fwd + Math.sin(angle + Math.PI / 2) * str;
  const { body, hit } = move(g, { x: player.x, z: player.z, radius: player.radius }, dx, dz, opts);
  return { player: { ...player, x: body.x, z: body.z, angle }, hit };
}

// runUnit(world, unit, ctx) — run one unit's behavior and collect the rows it wishes to append. The
// behavior is a pure (world, ctx) -> rows function; the engine just admits what it returns. A behavior
// that wants to CONTEST a voxel (the ⊤ mechanic) returns BOTH faces for the same cell — predicate(...,
// "solid", ...) AND deny(..., "solid", ...) — which folds that voxel to ⊤ and makes the raycaster
// shiver it. Returns the rows (possibly empty).
export function runUnit(world, unit, ctx = {}) {
  if (typeof unit.behavior !== "function") return [];
  const rows = unit.behavior(world, ctx) ?? [];
  return Array.isArray(rows) ? rows : [];
}

// tick(scene, opts) — one turn: apply the player's intent against the current grid, run each unit's
// behavior and admit the appended rows (append-only; never overwrite), advance the phase, and project a
// 3D frame the player sees. Returns a NEW scene plus the frame. No clock — the caller decides when to
// tick (a key press, an interval, a peer message). opts.intent is the player's intent for this tick.
export function tick(state, opts = {}) {
  const t = opts.t ?? state.phase;
  let world = state.world;

  // 1. read the world into a grid, then resolve the player's intent against it (collision).
  const g0 = grid(world, opts);
  const { player } = applyIntent(g0, state.player, opts.intent ?? {}, opts);

  // 2. run unit behaviors; admit every appended row (append-only union). A unit may contest a voxel.
  const ctx = { t, phase: state.phase, player };
  const unitResults = [];
  for (const unit of state.units) {
    const rows = runUnit(world, unit, ctx);
    for (const r of rows) world = admitLog(world, r.e, [r]).world;
    unitResults.push({ subject: unit.subject, appended: rows.length });
  }

  // 3. re-grid (units may have changed solidity) and project the 3D frame from the player's eye.
  const phase = state.phase + 1;
  const g = grid(world, opts);
  const cam = camera({
    ...state.cam,
    x: player.x, z: player.z, angle: player.angle,
    width: opts.width ?? state.cam.width,
    height: opts.height ?? state.cam.height,
  });
  const frame = render(g, cam, { phase });

  const logEntry = { t, phase, units: unitResults, census: frame.census };
  return {
    ...state,
    world,
    player,
    phase,
    cam: { ...state.cam },
    log: [...state.log, logEntry],
    frame,
    camera: cam,
    unitResults,
  };
}

// walk(scene, intents, opts) — advance the scene along a SEQUENCE of intents, one tick each, returning
// the final scene plus every frame walked. The demo's "walk a 3D corridor over a tiny settled world" — a
// deterministic path, replay-identical. `intents` is a list of { forward, strafe, turn }.
export function walk(state, intents, opts = {}) {
  let s = state;
  const frames = [];
  for (const intent of intents) {
    s = tick(s, { ...opts, intent });
    frames.push(s.frame);
  }
  return { scene: s, frames };
}

// ── the realtime driver (the thin imperative shell) ─────────────────────────────────────────────
// run({ scene, onFrame, interval, ticks, nextIntent }) — call tick on an interval, handing each frame
// to onFrame. `nextIntent(scene)` supplies the player's intent per tick (default: stand still). Stops
// after `ticks` ticks or when onFrame returns false. This is the ONLY part of the engine package with a
// timer; everything it calls is pure. Returns the final scene.
export function run({ scene: state, onFrame, interval = 100, ticks = Infinity, width, height, nextIntent }) {
  return new Promise((resolve) => {
    let s = state;
    let n = 0;
    const step = () => {
      const intent = nextIntent ? nextIntent(s) : {};
      s = tick(s, { width, height, intent });
      const cont = onFrame ? onFrame(s.frame, s) : true;
      n += 1;
      if (cont === false || n >= ticks) { resolve(s); return; }
      setTimeout(step, interval);
    };
    step();
  });
}

export { grid, place, predicate, deny, cellKey, allRows, FOUR };
