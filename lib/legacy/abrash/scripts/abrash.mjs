#!/usr/bin/env node
// abrash demo — a first-person SOFTWARE 3D walk through a tiny SETTLED voxel world, rendered over
// daleske's pixel framebuffer (kitty/sixel), the engine's first-playable proof. It loads the shipped
// seed (world/proving-ground.jsonl) — a 5x5 room with ONE contested wall (voxel:2,4 is told both
// `solid` and its converse, folding to ⊤) — settles the grid, and casts one ray per screen column from
// the player's eye each tick. You walk the room and watch the contested wall SHIVER and split-tint while
// the settled walls stand clean: the bilattice readout, live, in 3D.
//
// Two modes:
//   (default, TTY)  — daleske's alt-screen pixel cockpit: the 3D frame blitted via kitty/sixel, a status
//                     line announcing the four-value census, WASD to move/turn, q/Ctrl-C to quit.
//   --headless / non-TTY — render N frames and print each as a small ASCII downsample of the pixel frame
//                     (so CI, an audit, or a pipe can SEE the 3D view and the contested wall).
//
// Run: node scripts/abrash.mjs   (or: pnpm --filter @561-group/abrash demo)

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import { PixelScreen } from "@561-group/daleske/screen";

import { worldFromRows, grid, FOUR } from "../src/world.mjs";
import { scene, tick } from "../src/engine.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const SEED = join(HERE, "..", "world", "proving-ground.jsonl");

function loadSeed() {
  const text = readFileSync(SEED, "utf8").trim();
  return text ? text.split("\n").map((l) => JSON.parse(l)) : [];
}

// a deterministic walk path: turn to face down the room, step forward toward the contested south wall,
// strafe a little — a replay-identical sweep so the headless frames are stable.
function intentAt(step) {
  const ring = [
    { turn: 0.5 }, { turn: 0.5 }, { forward: 1 }, { forward: 1 },
    { turn: -0.3 }, { forward: 1 }, { strafe: 1 }, { turn: -0.4 },
  ];
  return ring[step % ring.length];
}

// ── headless: render frames and print a tiny ASCII downsample so a pipe/CI can see the 3D view ──
// We sample the framebuffer on a coarse grid and pick a glyph by the dominant channel: a green-ish
// wall is '#', a yellow-ish (contested seam / deny face) wall is '%' (the shivering wall you watch), a
// dark sky/floor is ' ' or '.'. This is the audit surface — calm by default, the ⊤ wall made visible.
function frameToAscii(frame, cols = 56, rows = 22) {
  const { fb } = frame;
  const sx = fb.width / cols, sy = fb.height / rows;
  const lines = [];
  for (let r = 0; r < rows; r++) {
    let line = "";
    for (let c = 0; c < cols; c++) {
      const [R, G, B] = fb.getPixel(Math.floor(c * sx), Math.floor(r * sy));
      const lum = (R + G + B) / 3;
      if (G > R + 30 && G > B + 30 && lum > 70) line += "#";          // settled wall (green)
      else if (R > 150 && G > 130 && B < 110) line += "%";            // contested wall (yellow/deny)
      else if (R > 120 && G < 100 && B < 100) line += "%";            // contested deny face (red)
      else if (lum > 45) line += ".";                                  // floor / fog
      else line += " ";                                                // sky
    }
    lines.push(line);
  }
  return lines.join("\n");
}

function runHeadless(world, frames = 6) {
  let state = scene({ world, player: { x: 2.5, z: 1.5, angle: Math.PI / 2 }, cam: { width: 168, height: 96, fov: Math.PI / 3, maxDist: 16 } });
  for (let n = 0; n < frames; n++) {
    state = tick(state, { intent: intentAt(n) });
    const f = state.frame;
    console.log(`\n── frame ${n} ──  t:${f.census.t} ⊥:${f.census.bot} f:${f.census.f} ⊤:${f.census.top}  (player ${state.player.x.toFixed(1)},${state.player.z.toFixed(1)} ∠${state.player.angle.toFixed(2)})`);
    console.log(frameToAscii(f));
  }
  console.log("\n(the '%' columns are the CONTESTED south wall — voxel:2,4, told both solid and not-solid,");
  console.log(" held ⊤ by the substrate: it SHIVERS frame-to-frame, split green/red. The clean '#' walls are settled t.)");
}

// ── interactive: daleske pixel cockpit, WASD to move, q to quit ──
function runInteractive(world) {
  const screen = new PixelScreen();
  let state = scene({
    world,
    player: { x: 2.5, z: 1.5, angle: Math.PI / 2 },
    cam: { fov: Math.PI / 3, maxDist: 16 },
  });
  let running = true;
  let intent = {};

  const paint = () => {
    // render at the screen's pixel size; the engine fills camera position/angle from the player.
    state = tick(state, { width: screen.width, height: screen.height, intent });
    intent = {}; // intents are one-shot per key; clear after applying
    screen.paint(state.frame.fb);
    const cen = state.frame.census;
    // a calm status line under the raster (audit on demand): the four-value census.
    process.stdout.write(`\x1b[${Math.floor(screen.height / 16) + 1};1Habrash  t:${cen.t} ⊥:${cen.bot} f:${cen.f} ⊤:${cen.top}  [WASD] move  [q] quit — the ⊤ wall shivers`);
  };

  screen.start();
  paint();
  screen.onKey((k) => {
    if (k.name === "q") { running = false; screen.stop(); process.exit(0); }
    if (k.name === "char") {
      if (k.char === "w") intent = { forward: 1 };
      else if (k.char === "s") intent = { forward: -1 };
      else if (k.char === "a") intent = { turn: -1 };
      else if (k.char === "d") intent = { turn: 1 };
    }
  });
  screen.onInterrupt(() => { running = false; screen.stop(); process.exit(0); });

  const loop = () => {
    if (!running) return;
    paint();
    setTimeout(loop, 90);
  };
  setTimeout(loop, 90);
}

function main() {
  const world = worldFromRows(loadSeed());
  // a quick sanity line so the run reports what it loaded (and confirms the ⊤ wall is present).
  const g = grid(world);
  const contested = [...g.cells.values()].filter((c) => c.charge === FOUR.TOP).length;
  const headless = process.argv.includes("--headless") || !process.stdout.isTTY;
  if (!headless) { /* interactive prints its own status */ }
  else console.log(`abrash — loaded ${g.cells.size} voxels (${contested} contested ⊤) from proving-ground.jsonl`);
  if (headless) runHeadless(world);
  else runInteractive(world);
}

main();
