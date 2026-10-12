# @red-cup-engineering/abrash

A pixel/3D game engine: a software raycaster (grid-DDA) over a federated voxel world into an RGBA
framebuffer, with a tick loop, grid collision, and a paraconsistent trace substrate for world state.
Named for Michael Abrash, who documented the software 3D renderer behind Quake. Browser-portable: the
raycaster's output is an RGBA raster a `<canvas>` can paint directly with `putImageData`, and the same
surface runs headless in Node with no DOM dependency.

```sh
npm install @red-cup-engineering/abrash --registry http://127.0.0.1:4873/
npm test
```

## What it is

- **`math`** — the vec2/rotation kernel the raycaster rests on: 2D vectors, rotation, and the algebra
  the cast and projection need. Pure, deterministic.
- **`grid`** — the dependency-free FOUR-valued grid reader shared by browser raycasting and collision;
  `gridFromCells` adapts JSON-safe voxel triples with caller-selected missing-cell semantics.
- **`world`** — the federated-trace voxel substrate. A voxel (a cell of the floor grid) is a subject;
  its solidity is the fold of every predication filed about it. A world is `Map<subject, Row[]>`, a
  G-Set (grow-only set) per subject, merged by `federate` (order-independent, content-deduped union) —
  the world-of-subjects algebra this module consumes from `@red-cup-engineering/computer/distribution`
  (`emptyWorld`, `admitLog`, `federate`, `mergeWorlds`, `frontier`, `sectionOf`, `disagreements`,
  and `migrate` — that package's `migrateSubjects`, a bulk namespace re-key). Adds the domain read:
  `place`, `grid`, `solidityAt`, `cellKey`, `chargeOf`.
- **`framebuffer`** — the RGBA raster surface: a headless `Framebuffer` (pure data, used directly by
  every test and by any non-visual caller) and `paintToCanvas(ctx, fb)` (one `putImageData` call, no
  re-encoding, since `fb.data` is already `ImageData`-shaped).
- **`raycaster`** — the software 3D renderer: a DDA ray per screen column into a `Framebuffer`, plus a
  billboard sprite pass for point entities. Pure and deterministic (no `Date.now`, no `Math.random`), so
  a frame is replay-identical for a given world, camera, and phase.
- **`collision`** — AABB-on-grid, slide-along-walls, using the same solidity predicate the raycaster
  uses to stop a ray (t and ⊤ block; f and ⊥ pass).
- **`engine`** — the tick loop: apply the player's intent (resolved by collision), run unit behaviors
  (which may contest a voxel), re-grid, project. `run()` is a `setTimeout` driver for a headless caller;
  a browser consumer should drive its own loop off `requestAnimationFrame` instead.

## The bilattice readout

A voxel carries one of four charges, and the charge is how the wall renders:

- **t** (affirmed solid) — a clean, distance-shaded **green** wall slice. Blocks a ray and a body.
- **f** (denied / carved) — passable: the ray passes, collision lets the body through.
- **⊥** (un-scanned) — fog: no solidity evidence; the ray passes and the horizon fogs faintly.
- **⊤** (contradicted) — two peers disagree (one `solid`, one its converse), folded to ⊤ and held with
  both witnesses. The slice is drawn shivering (a `y` offset that cycles with the tick phase —
  deterministic, never random) and split-tinted. The ray stops on it and a body is blocked, unless a
  game opts into `passContested`.

## Built on

`@red-cup-engineering/computer` — its `distribution` export for the world-of-subjects federation
algebra (G-Set union, frontier/sectionOf, disagreements, migrateSubjects) and its
`posix-holography/eavt-substrate` for the read→fold→settle spine; nothing else.

## Layout

- `src/*.mjs` + matching `.d.ts` — the modules above.
- `src/*.test.mts` — `node --test` suites, one per module.
- `world/proving-ground.jsonl` — a seed world (a 5x5 room with one contested wall at `voxel:2,4`) used
  by the tests and available as a starting world for a consumer.
