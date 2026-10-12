// index — the barrel re-exporting the tsander engine surface. The subpath exports in package.json are
// the primary surface (import the concern you need); this barrel gathers them for one-import callers.
//
// @561-group/tsander — the GAME ENGINE on @561-group/arnold: terminal/wireframe games. Its three
// engine-level concerns, each its own module:
//   - world.mjs          : the federated-trace WORLD substrate (a place = the fold of predications;
//                          unvisited = ⊥; disagreement = ⊤ HELD, both witnesses).
//   - wireframe.mjs      : the WIREFRAME renderer (3D vectors -> Arnold cells; a ⊤ object renders
//                          doubled + jittering — the bilattice readout).
//   - horsetail-hook.mjs : the hook to run a unit's "computer" program in @561-group/horsetail.
//   - engine.mjs         : the tick/realtime LOOP tying them together.
//   - math.mjs           : the rederived vec3/mat4 the renderer needs.

export * as world from "./world.mjs";
export * as wireframe from "./wireframe.mjs";
export * as horsetail from "./horsetail-hook.mjs";
export * as engine from "./engine.mjs";
export { v3, m4 } from "./math.mjs";

// the most-used entry points, flat, for convenience:
export { worldFromRows, place, renderables, positionOf, predicate, deny, FOUR } from "./world.mjs";
export { camera, render, frameToLines, emptyFrame, CHARGE_GLYPH } from "./wireframe.mjs";
export { makeComputer, runProgram, branchOnCharge } from "./horsetail-hook.mjs";
export { cockpit, tick, fly, run, makeWorld } from "./engine.mjs";
