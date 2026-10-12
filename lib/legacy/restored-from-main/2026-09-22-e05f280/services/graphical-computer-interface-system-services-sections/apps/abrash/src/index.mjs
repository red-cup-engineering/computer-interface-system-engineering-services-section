// abrash — the pixel/3D GAME ENGINE the browser port ships as @red-cup-engineering/abrash. The barrel
// re-export so a caller can `import { scene, tick, render, camera } from "@red-cup-engineering/abrash"`.
//
// The pieces, by concern (each pure unless noted):
//   math        — the rederived vec2/rotation kernel the raycaster rests on (proven by identities).
//   world       — the federated-trace VOXEL substrate: a voxel is a subject; ⊥ un-scanned, ⊤ contested,
//                 both witnesses HELD. Composes @red-cup-engineering/computer/distribution (the
//                 world-of-subjects algebra: G-Set union, frontier/sectionOf, disagreements) with the
//                 published substrate; adds the domain read.
//   framebuffer — the RGBA raster surface contract: a headless Framebuffer (pure data, used directly by
//                 tests) plus a canvas-target paint function for the browser.
//   raycaster   — the software 3D renderer: one DDA ray per screen column → a Framebuffer, with the
//                 bilattice readout (a ⊤ wall SHIVERS + split-tints; ⊥ fogs).
//   collision   — AABB-on-grid, slide-along-walls; t and ⊤ block, f and ⊥ pass (same predicate as cast).
//   engine      — the tick/realtime loop (no global clock): apply intent, run units (may contest a
//                 voxel), re-grid, project. The realtime `run` is a timer; everything else pure.

export {
  // world substrate
  worldFromRows, federate, place, grid, solidityAt, disagreements,
  predicate, deny, cellKey, chargeOf, settleOpts, FOUR,
  emptyWorld, admitLog, subjects, allRows,
} from "./world.mjs";

export {
  mergeWorlds, logFor, frontier, sectionOf,
  migrateSubjects as migrate,
} from "@red-cup-engineering/computer/distribution";

export { v2, dir, clampInt, mix } from "./math.mjs";
export { Framebuffer, paintToCanvas } from "./framebuffer.mjs";
export { camera, render, castRay, WALL_COLOR } from "./raycaster.mjs";
export { blocks, occupied, move, clearAhead } from "./collision.mjs";
export { scene, tick, walk, run, applyIntent, runUnit, makeWorld } from "./engine.mjs";
