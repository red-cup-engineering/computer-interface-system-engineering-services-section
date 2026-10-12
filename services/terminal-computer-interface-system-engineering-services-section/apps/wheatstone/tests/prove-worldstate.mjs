// prove-worldstate — the GMCP/MSDP-fed state model, the CALM status reading, and the
// audit-on-demand trail (held, not destroyed) per the audit-is-the-feature journal.

import { ok, eq, done } from "./_harness.mjs";
import { WorldState } from "../src/worldstate.mjs";

// GMCP Char.Vitals → vitals + status slots
{
  const w = new WorldState();
  w.applyGMCP("Char.Vitals", { hp: 80, maxhp: 100, mp: 30, maxmp: 50 });
  eq(w.vitals, { hp: 80, maxhp: 100, mp: 30, maxmp: 50 }, "Char.Vitals folds into vitals");
  const slots = w.statusSlots();
  ok(slots.right.includes("HP 80/100"), "the status line shows HP plainly (CALM)");
  ok(slots.right.includes("MP 30/50"), "the status line shows MP plainly");
}

// GMCP Room.Info → room name in the center slot + panel
{
  const w = new WorldState();
  w.applyGMCP("Room.Info", { name: "The Town Square", area: "Old Quarter", exits: ["north", "east"] });
  eq(w.statusSlots().center, "The Town Square", "room name is the center status slot");
  const panel = w.panelLines();
  ok(panel.some((l) => l.text.includes("exits: north east")), "the side panel lists exits");
}

// GMCP Char.Status → name/level in the left slot
{
  const w = new WorldState();
  w.applyGMCP("Char.Status", { name: "Gorin", level: 12 });
  eq(w.statusSlots().left, "Gorin L12", "char name + level in the left slot");
}

// MSDP feeds the SAME model (source-agnostic)
{
  const w = new WorldState();
  w.applyMSDP({ HEALTH: "44", MAX_HEALTH: "120", ROOM_NAME: "A Dark Cave" });
  ok(w.statusSlots().right.includes("HP 44/120"), "MSDP HEALTH feeds the same HP slot as GMCP");
  eq(w.statusSlots().center, "A Dark Cave", "MSDP ROOM_NAME feeds the room slot");
}

// THE LAW: CALM-by-default + AUDIT-on-demand. Conflicting sources keep the LATEST shown, but the
// audit trail HOLDS both — surfaced only when the audit panel is asked for.
{
  const w = new WorldState();
  w.applyGMCP("Char.Vitals", { hp: 100 });    // source A says 100
  w.applyMSDP({ HEALTH: "60" });               // source B (different) says 60
  // calm default: the latest value is shown, no spectacle
  ok(w.statusSlots().right.includes("HP 60"), "CALM default shows the latest reading (60), not a ⊤ spectacle");
  const calmPanel = w.panelLines({ audit: false });
  ok(!calmPanel.some((l) => l.text.includes("audit")), "no audit section in the calm panel");
  // audit on demand: the held trail surfaces BOTH sources for the field
  const audited = w.panelLines({ audit: true });
  ok(audited.some((l) => l.text.includes("audit")), "the audit section appears on demand");
  const trail = audited.filter((l) => l.text.includes("⊢"));
  ok(trail.some((l) => l.text.includes("gmcp")) && trail.some((l) => l.text.includes("msdp")),
    "the audit trail HOLDS both sources (gmcp + msdp) — evidence not destroyed");
}

// Room.Players → who list in the panel
{
  const w = new WorldState();
  w.applyGMCP("Room.Players", [{ name: "Alice" }, { name: "Bob" }]);
  const panel = w.panelLines();
  ok(panel.some((l) => l.text.includes("who (2)")), "the panel shows a who count");
  ok(panel.some((l) => l.text.includes("Alice")), "the panel lists present players");
}

done("prove-worldstate");
