# @561-group/abrash

> A **pixel/3D GAME ENGINE** over [`@561-group/daleske`](../daleske) (the kitty/sixel pixel terminal) — the **software-3D sibling** of [`@561-group/tsander`](../tsander) (the wireframe engine over the cell terminal arnold). abrash casts a **software raycaster** over a federated voxel world into daleske's RGBA framebuffer, with a tick loop, grid collision, and the paraconsistent trace substrate.
> It sits ABOVE [`@561-group/computer`](../../../computer) (the EAVT substrate) and `@561-group/daleske`; neither depends on it.
> Named for **Michael Abrash**, who documented the software 3D renderer behind Quake.

```sh
npm test                  # 81 assertions across 5 proofs
npm run demo              # walk a 3D room over kitty/sixel (or an ASCII downsample in a pipe)
npm run demo -- --headless   # render frames as a small ASCII view of the 3D scene (CI / audit)
```

## What it is

A first-person software 3D engine whose **world is a federated paraconsistent trace**.
Where tsander projects 3D vectors to Arnold *cells* and Bresenham-rasters wireframe edges, abrash casts **one ray per screen column** through a voxel grid (the grid-DDA technique Abrash documented) and paints a vertical **wall slice** per column into daleske's **pixel** framebuffer — a real first-person 3D view computed in pure JS.

- **`math`** — the rederived vec2/rotation kernel the raycaster rests on, proven by identities (rotation preserves length, the camera plane is perpendicular to the facing).
  Nothing imported, nothing assumed about "how a raycaster works."
- **`world`** — the federated-trace **voxel** substrate.
  A *voxel* (a cell of the floor grid) is a subject; its solidity is the **fold** of every predication filed about it.
  It composes computer's `distribution/federate` (the G-Set union ∥ — no coordinator, no clock, no last-write-wins) and `substrate` (read→fold→settle), adding only the domain read.
- **`raycaster`** — the software 3D renderer: a DDA ray per column → a daleske `Framebuffer`. **THE SEAM** — pure, deterministic, replay-identical (no `Date.now`, no `Math.random`).
- **`collision`** — AABB-on-grid, slide-along-walls.
  The same four-valued predicate the caster uses to *stop a ray* decides what *blocks a body*, kept in one place so render and walk agree.
- **`engine`** — the tick/realtime loop with **no global clock** (aperiodic settling): apply the player's intent (resolved by collision), run unit behaviors (which may **contest** a voxel), re-grid, project.
  The realtime `run` is the only timer; everything it calls is pure.

## The bilattice readout — THE LAW, in 3D pixels

A voxel carries one of **four** charges, and the charge **is** how the wall renders — a direct readout of the bilattice, not decoration:

- **t** (affirmed solid) → a clean, distance-shaded **green** wall slice.
  A ray **stops** on it; a body **cannot walk through** it.
- **f** (denied / carved) → **passable**: a wall a peer says was opened.
  The ray **passes**, collision lets the body through — the negative face honored, not blankness.
- **⊥** (un-scanned) → **fog**: no solidity evidence.
  The ray **passes** and the open distance is fogged at the horizon — ⊥ shown faintly, not a confident empty room.
- **⊤** (contradicted) → **CONTESTED**: two peers disagree about the wall (one `solid`, one its converse), folded to ⊤ and **HELD** with both witnesses.
  The slice is drawn **SHIVERING** — a `y` offset that oscillates with the tick **phase** (a parameter, never an RNG, so it is replay-identical) — and **split-tinted** (affirm-green top half, deny-red bottom half, a yellow seam between).
  The ray **stops** on it and a body is **blocked** by it (a held obstacle), unless a game opts into `passContested` to make it a phase-through mechanic. **In a game, ⊤ is a designed MECHANIC — the wall you cannot trust — never hidden, never a debug dump.**

A unit behavior contests a voxel by appending **both faces** for the same cell (`predicate(cell,"solid",…)` AND `deny(cell,"solid",…)`), which folds it to ⊤ and makes the next frame shiver — disagreement is an enumerable **value** (`disagreements(world)`), never an error.

## The demo

`scripts/abrash.mjs` loads `world/proving-ground.jsonl` — a 5×5 room of settled walls with **one contested wall** (`voxel:2,4`, told both `solid` and `not-solid`) — and walks the player toward it.
The contested wall renders as the `%` columns that **shiver** between frames while the clean `#` walls stand settled.
A calm status line carries the four-value census (audit on demand); the shivering wall is the play.

## Built on

`@561-group/computer` (federation + the read→fold→settle substrate) and `@561-group/daleske` (the pixel framebuffer + kitty/sixel blit).
Games ride this engine; the engine rides the terminal; the terminal rides the computer.
