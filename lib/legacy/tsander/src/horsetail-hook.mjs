// horsetail-hook — the hook to run a UNIT's "computer" program in @561-group/horsetail. A unit (a ship,
// a station, an autopilot) carries a flight-computer program written in Horsetail, the computer's native
// paraconsistent Lisp where `eval` IS `settle` and ⊤ is a bindable HELD value (the belnap/Horsetail
// journal). This module is the seam: give it a unit's program source and an environment, get back the
// settled CHARGE — and, crucially, the FOUR reading of that charge, so the engine can branch on it the
// way the design note's §9 does: `(if ⊤ …)` runs BOTH arms and holds the result contested.
//
// THE LAW kept here: we never put anything load-bearing on Horsetail (the journal's caveat — Horsetail
// is not to be relied on yet); a unit's program is its OWN internals, blast-radius = that unit. The
// engine reads the program's settled charge as a four-valued signal and reacts; a crash in a unit's
// program is caught and surfaced as a ⊥ (no settled signal), never an engine halt.

import { world as htWorld, run as htRun, fourName, glyph } from "@561-group/computer/horsetail";

// FOUR names align with world.FOUR so the engine reads one vocabulary. Horsetail's fourName gives
// "t"|"f"|"bot"|"top"; we pass it straight through.
export const HORSETAIL = "horsetail";

// makeComputer(init) — a fresh Horsetail world (stdlib loaded) for a unit's flight computer. Each unit
// gets its OWN world so one ship's program cannot reach into another's (the blast-radius rule).
export function makeComputer(init = {}) {
  return htWorld(init);
}

// runProgram(source, computer) — settle a unit's program source into its computer world and read the
// LAST form's charge. Returns { charge, four, glyph, ok, error? }. A throw inside the program (a parse
// error, an unbound symbol) is CAUGHT and reported as ok:false with four "bot" — the engine treats an
// un-settleable program as "no signal" (⊥), never a halt.
export function runProgram(source, computer = makeComputer()) {
  try {
    const charge = htRun(source, computer);
    return { charge, four: fourName(charge), glyph: glyph(charge), ok: true, world: computer };
  } catch (error) {
    return { charge: null, four: "bot", glyph: "⊥", ok: false, error: String(error?.message ?? error), world: computer };
  }
}

// branchOnCharge(four, arms) — the §9 reading of a four-valued result. The KILLER feature only this
// machine allows: a ⊤ result runs BOTH the t-arm AND the f-arm and HOLDS the pair contested (it does
// not pick one). `arms` is { t, f, bot, top }, each an optional thunk; the result names which arm(s)
// fired and their values, so the engine (and the renderer) can show a unit honestly both-acting.
//   four "t"   -> run arms.t
//   four "f"   -> run arms.f
//   four "bot" -> run arms.bot (unknown — e.g. scan first)
//   four "top" -> run BOTH arms.t and arms.f, return { held:true, t, f } (contested, both kept)
export function branchOnCharge(four, arms = {}) {
  const call = (fn) => (typeof fn === "function" ? fn() : undefined);
  switch (four) {
    case "t": return { fired: ["t"], value: call(arms.t) };
    case "f": return { fired: ["f"], value: call(arms.f) };
    case "top":
      // ⊤: run both arms, hold the result contested — neither face erased.
      return { fired: ["t", "f"], held: true, t: call(arms.t), f: call(arms.f) };
    case "bot":
    default:
      return { fired: ["bot"], value: call(arms.bot) };
  }
}
