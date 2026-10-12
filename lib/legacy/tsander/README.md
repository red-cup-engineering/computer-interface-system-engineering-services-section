# @561-group/tsander

**The game engine on [Arnold](../arnold/) — terminal/wireframe games.** Tsander is the engine layer of the [Okaga](../../../computer/docs/dev/notes/tsander-design.md) space-flight design: it gives a game the three things a paraconsistent wireframe game needs, and nothing more.

> Named Tsander←Tsander as Bussard←Bussard — the homage shape the design note opens with. **Tsander is the engine; Okaga is the game** that will ride it.

## What it is

Three engine-level concerns, each its own module, lifted from the design note:

1. **The federated-trace WORLD substrate** ([`src/world.mjs`](src/world.mjs)) — a *place* is a subject
   whose state is the **fold** of every predication filed about it. Built on the computer's own
   federation (the tensor ∥: a G-Set union, no coordinator, no clock, no last-write-wins) and its
   bilattice fold. The four readings the game plays on:
   - **t** — a settled fact (positive evidence only).
   - **f** — a denied fact (the converse predication won; a belief STATE, not absence).
   - **⊥** — *unvisited*: no evidence at all. Fog, not a guess. `place(world, star).visited === false`.
   - **⊤** — *contested*: two traces disagree, so the cell is **HELD** with **both witnesses**. A
     contested star. The substrate never collapses it; adding decisive evidence never erases the loser.
2. **The WIREFRAME renderer** ([`src/wireframe.mjs`](src/wireframe.mjs)) — a pure pipeline from a
   settled 3D section to Arnold cells: model vertices → camera (`lookAt`·`perspective`) → ndc → the
   character grid → Bresenham lines → a glyph frame. **The charge IS the render style** (the bilattice
   readout): `t` solid `#`, `⊥` dotted `·`, `f` a wreck-stub `x`, and **`⊤` drawn TWICE — two offset
   hulls JITTERING frame-to-frame**, a doubled, shivering wireframe. The shiver is driven by the tick
   **phase**, never an RNG, so a frame is **replay-identical**.
3. **The tick/realtime LOOP + the Horsetail hook** ([`src/engine.mjs`](src/engine.mjs),
   [`src/horsetail-hook.mjs`](src/horsetail-hook.mjs)) — a tick settles the world the camera sees, runs
   each unit's flight-**computer** program in [Horsetail](../../../computer/horsetail/) (the native
   paraconsistent Lisp, where `eval` is `settle`), appends the resulting predications, and projects a
   frame. There is **no global clock** — the world advances only when rows are appended. The killer
   feature: a unit program that settles **⊤ runs BOTH arms and holds the result contested**
   (`branchOnCharge`), so a ship can honestly both-dock-and-flee, and the wireframe shivers it.

THE LAW: ⊤ is HELD (a designed game mechanic, per the audit-is-the-feature note — games are the exception where ⊤ is shown as play), the trace is append-only, evidence is linear.

## Quick start

```sh
pnpm --filter @561-group/tsander demo     # fly a wireframe over the shipped settled world
pnpm --filter @561-group/tsander test     # the proofs (math, world, wireframe, horsetail, engine)
```

The demo orbits a camera around the seed cluster ([`world/core-systems.jsonl`](world/core-systems.jsonl)).
Three stars settle clean; **vega-prime** is told both `controlled-by federation` and its converse, so it renders **doubled and shivering** — a contested star, live.
On a non-TTY (CI, a pipe) it prints frames as plain text (`--headless`).

## Using the engine

```js
import { worldFromRows, place, renderables, predicate, deny } from "@561-group/tsander/world";
import { camera, render, frameToLines } from "@561-group/tsander/wireframe";
import { cockpit, tick, fly } from "@561-group/tsander/engine";

const world = worldFromRows([
  predicate("vega", "at-position", [0, 0, 0], 1),
  predicate("vega", "controlled-by", "federation", 1),
  deny("vega", "controlled-by", "federation", 2),   // the converse: a disagreement
]);

place(world, "vega").charge;        // "top" — a contested star, HELD, both witnesses kept
place(world, "unseen").charge;      // "bot" — ⊥ fog: unvisited, no evidence

const cam = camera({ eye: [0, 0, 12], target: [0, 0, 0], width: 60, height: 20 });
const frame = render(renderables(world), cam, { phase: 1 });
console.log(frameToLines(frame).join("\n"));   // vega draws doubled (%)
```

## Layout

```
src/world.mjs           the federated-trace world: place = fold; ⊥ unvisited; ⊤ contested (both witnesses)
src/wireframe.mjs       3D section -> Arnold cells; ⊤ renders doubled+jittering (the bilattice readout)
src/horsetail-hook.mjs  run a unit's flight-computer program in Horsetail; ⊤ runs BOTH arms held
src/engine.mjs          the tick/realtime loop tying world + renderer + hook together (no global clock)
src/math.mjs            the rederived vec3/mat4 the renderer needs (proven by identities in tests/)
scripts/tsander.mjs         the demo: fly a wireframe over the settled seed world
world/core-systems.jsonl the shipped seed trace (append-only; one {e,a,v,t} row per line)
tests/                  math · world · wireframe · horsetail · engine proofs
```

## Dependencies

- **[`@561-group/computer`](../../../computer/)** — `substrate` (fold/settle/section/relate), the `distribution/federate` tensor ∥, and `horsetail` (the unit-program language).
  The world, the federation, and the ship-programming all come from here.
- **[`@561-group/arnold`](../arnold/)** — the terminal surface the wireframe draws into (the cell buffer + diffed render the demo uses).

Games ride this engine; the engine rides Arnold and the computer.
