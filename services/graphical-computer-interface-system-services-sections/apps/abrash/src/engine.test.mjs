// engine.test.mts — proves the tick loop: intent resolves against collision, a unit behavior can APPEND
// rows (including a contest — both faces on one cell, folding it to ⊤), the phase advances every tick,
// and the whole loop is deterministic: replaying the identical intent sequence over the identical seed
// produces byte-identical resulting worlds and frames (no Date.now/Math.random anywhere in the pure
// path — walk()/tick() never call either).

import { test } from "node:test";
import assert from "node:assert/strict";
import { scene, tick, walk, applyIntent, runUnit } from "./engine.mjs";
import { worldFromRows, predicate, deny, grid, place, FOUR } from "./world.mjs";

function room() {
  // a small enclosed room, walls on x=0,x=4 and z=0,z=4, open floor inside.
  const rows = [];
  for (let x = 0; x <= 4; x++) { rows.push(predicate(`voxel:${x},0`, "solid", "wall", 1)); rows.push(predicate(`voxel:${x},4`, "solid", "wall", 1)); }
  for (let z = 1; z <= 3; z++) { rows.push(predicate(`voxel:0,${z}`, "solid", "wall", 1)); rows.push(predicate(`voxel:4,${z}`, "solid", "wall", 1)); }
  return worldFromRows(rows);
}

test("scene: fills player defaults", () => {
  const s = scene({ world: room() });
  assert.equal(s.player.x, 1.5);
  assert.equal(s.player.z, 1.5);
  assert.equal(s.phase, 0);
});

test("applyIntent: forward moves the player along its heading", () => {
  const w = room();
  const g = grid(w);
  const { player } = applyIntent(g, { x: 1.5, z: 1.5, angle: 0, radius: 0.2, moveSpeed: 0.2, turnSpeed: 0.1 }, { forward: 1 });
  assert.ok(player.x > 1.5);
  assert.ok(Math.abs(player.z - 1.5) < 1e-9);
});

test("applyIntent: turn changes angle without moving position", () => {
  const w = room();
  const g = grid(w);
  const { player } = applyIntent(g, { x: 1.5, z: 1.5, angle: 0, radius: 0.2, moveSpeed: 0.2, turnSpeed: 0.1 }, { turn: 1 });
  assert.ok(Math.abs(player.angle - 0.1) < 1e-9);
  assert.equal(player.x, 1.5);
  assert.equal(player.z, 1.5);
});

test("applyIntent: collision stops the player at a settled wall (cannot walk through t)", () => {
  const w = room();
  const g = grid(w);
  let player = { x: 1.5, z: 1.5, angle: 0, radius: 0.2, moveSpeed: 3, turnSpeed: 0.1 }; // a big forward step
  const result = applyIntent(g, player, { forward: 1 });
  assert.ok(result.player.x < 4); // never crosses into/through the far wall
});

test("runUnit: a behavior returning rows contests a voxel — both faces fold that cell to ⊤", () => {
  const w = room();
  const unit = {
    subject: "trap:0",
    behavior: () => [predicate("voxel:2,2", "solid", "trap", 1), deny("voxel:2,2", "solid", "trap", 1.5)],
  };
  const rows = runUnit(w, unit, {});
  assert.equal(rows.length, 2);
});

test("runUnit: a unit with no behavior function appends nothing", () => {
  const rows = runUnit(room(), { subject: "inert" }, {});
  assert.deepEqual(rows, []);
});

test("tick: advances the phase by exactly 1 and produces a frame", () => {
  const s0 = scene({ world: room(), cam: { width: 16, height: 16 } });
  const s1 = tick(s0, { intent: {} });
  assert.equal(s1.phase, 1);
  assert.ok(s1.frame);
  assert.ok(s1.frame.fb);
});

test("tick: a unit's contest is admitted into the world and visible on the next grid read", () => {
  const s0 = scene({
    world: room(),
    cam: { width: 8, height: 8 },
    units: [{
      subject: "contester",
      behavior: () => [predicate("voxel:2,2", "solid", "trap", 10), deny("voxel:2,2", "solid", "trap", 11)],
    }],
  });
  const s1 = tick(s0, { intent: {} });
  const p = place(s1.world, "voxel:2,2");
  assert.equal(p.reading, FOUR.TOP);
});

test("tick: never mutates the input scene (returns a new object)", () => {
  const s0 = scene({ world: room(), cam: { width: 8, height: 8 } });
  const s1 = tick(s0, { intent: { forward: 1 } });
  assert.notEqual(s0, s1);
  assert.equal(s0.phase, 0);
});

test("walk: applies a sequence of intents, one tick each, and returns every frame", () => {
  const s0 = scene({ world: room(), player: { x: 1.5, z: 1.5, angle: 0 }, cam: { width: 8, height: 8 } });
  const { scene: sN, frames } = walk(s0, [{ forward: 1 }, { forward: 1 }, { turn: 1 }]);
  assert.equal(frames.length, 3);
  assert.equal(sN.phase, 3);
});

test("DETERMINISM: replaying the identical intent log over the identical seed yields byte-identical worlds", () => {
  const intents = [{ forward: 1 }, { turn: 0.5 }, { forward: 1 }, { strafe: 1 }, { turn: -0.3 }];

  function run() {
    const s0 = scene({
      world: room(),
      player: { x: 1.5, z: 1.5, angle: 0 },
      cam: { width: 12, height: 12 },
      units: [{
        subject: "contester",
        behavior: (_w, ctx) => (ctx.phase === 2
          ? [predicate("voxel:2,2", "solid", "trap", 100 + ctx.phase), deny("voxel:2,2", "solid", "trap", 100.5 + ctx.phase)]
          : []),
      }],
    });
    return walk(s0, intents);
  }

  const runA = run();
  const runB = run();

  assert.equal(runA.scene.player.x, runB.scene.player.x);
  assert.equal(runA.scene.player.z, runB.scene.player.z);
  assert.equal(runA.scene.player.angle, runB.scene.player.angle);
  assert.deepEqual([...runA.scene.world.keys()].sort(), [...runB.scene.world.keys()].sort());
  for (const k of runA.scene.world.keys()) {
    assert.deepEqual(runA.scene.world.get(k), runB.scene.world.get(k));
  }
  // and the rendered frames themselves are byte-identical, not just the world state
  for (let i = 0; i < runA.frames.length; i++) {
    assert.deepEqual([...runA.frames[i].fb.data], [...runB.frames[i].fb.data]);
  }
});
