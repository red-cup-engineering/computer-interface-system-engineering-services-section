// abrash — the GAME ENGINE on @561-group/daleske (pixel/3D games), the pixel sibling of tsander. The
// barrel re-export so a caller can `import { scene, tick, render, camera } from "@561-group/abrash"`.
//
// The pieces, by concern (each pure unless noted):
//   math       — the rederived vec2/rotation kernel the raycaster rests on (proven by identities).
//   world      — the federated-trace VOXEL substrate: a voxel is a subject; ⊥ un-scanned, ⊤ contested,
//                both witnesses HELD. Composes computer's federation + substrate; adds the domain read.
//   raycaster  — the software 3D renderer: one DDA ray per screen column → daleske's RGBA framebuffer,
//                with the bilattice readout (a ⊤ wall SHIVERS + split-tints; ⊥ fogs).
//   collision  — AABB-on-grid, slide-along-walls; t and ⊤ block, f and ⊥ pass (same predicate as cast).
//   engine     — the tick/realtime loop (no global clock): apply intent, run units (may contest a
//                voxel), re-grid, project. The realtime `run` is the only timer; everything else pure.

export {
  // world substrate
  worldFromRows, federate, place, grid, solidityAt, disagreements,
  predicate, deny, cellKey, chargeOf, settleOpts, FOUR,
  emptyWorld, admitLog, subjects, allRows,
} from "./world.mjs";

export { v2, dir, clampInt, mix } from "./math.mjs";
export { camera, render, castRay, WALL_COLOR } from "./raycaster.mjs";
export { blocks, occupied, move, clearAhead } from "./collision.mjs";
export { scene, tick, walk, run, applyIntent, runUnit, makeWorld } from "./engine.mjs";
