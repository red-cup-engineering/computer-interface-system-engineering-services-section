// worldstate — the structured-data model the status line and side panel render. A MUD feeds
// out-of-band state over GMCP (JSON packages like Char.Vitals, Room.Info, Char.Status) and MSDP
// (var/val pairs). We fold those updates into a small, flat state record the UI reads. This is the
// CALM-by-default surface (per computer/docs/dev/journal/2026-06-05-the-audit-is-the-feature.md):
// the status line shows a clean, sensible reading (the latest vitals), NOT a flaunted contradiction.
// When a field is updated by conflicting sources, we keep the LATEST as the shown value but RETAIN
// the prior values + their source as an audit trail — held, not destroyed — so the side panel's
// audit view can answer "why does HP say this?" on demand. The contradiction is available, not in
// the user's face.
//
// Pure data: applyGMCP / applyMSDP fold an update into a new-ish state in place; no I/O.

export class WorldState {
  constructor() {
    // the CALM reading: the current shown value per field.
    this.vitals = {};       // e.g. { hp, maxhp, mp, maxmp, sp, maxsp }
    this.room = {};         // e.g. { name, exits, area }
    this.char = {};         // e.g. { name, level, class }
    this.who = [];          // list of present players (Room.Players / Comm)
    this.raw = {};          // last raw payload per GMCP package (for the side panel)
    // the AUDIT trail: per field, the history of { value, source, at } we have seen. Held, not
    // overwritten — this is the "why" the journal calls the real feature.
    this.audit = {};        // field-path → [{ value, source }]
    this._seq = 0;
  }

  _record(path, value, source) {
    if (!this.audit[path]) this.audit[path] = [];
    this.audit[path].push({ value, source, seq: this._seq++ });
    // bound the per-field audit so it cannot grow unbounded over a long session
    if (this.audit[path].length > 50) this.audit[path].splice(0, this.audit[path].length - 50);
  }

  // applyGMCP(pkg, data) — fold a GMCP package into state. We map the conventional packages
  // (Char.Vitals, Char.Status, Room.Info, Room.Players, Comm.Channel.*) and stash every raw
  // payload under raw[pkg] so the side panel can show any package a MUD sends, mapped or not.
  applyGMCP(pkg, data) {
    this.raw[pkg] = data;
    const p = String(pkg);
    if (p === "Char.Vitals" && data && typeof data === "object") {
      for (const [k, v] of Object.entries(data)) { this.vitals[k] = v; this._record(`vitals.${k}`, v, `gmcp:${p}`); }
    } else if (p === "Char.Status" && data && typeof data === "object") {
      for (const [k, v] of Object.entries(data)) { this.char[k] = v; this._record(`char.${k}`, v, `gmcp:${p}`); }
    } else if ((p === "Room.Info" || p === "Room.Name") && data && typeof data === "object") {
      for (const [k, v] of Object.entries(data)) { this.room[k] = v; this._record(`room.${k}`, v, `gmcp:${p}`); }
    } else if (p === "Room.Players" && Array.isArray(data)) {
      this.who = data;
      this._record("who", data, `gmcp:${p}`);
    } else if (p === "Char.Name" && data && typeof data === "object") {
      for (const [k, v] of Object.entries(data)) { this.char[k] = v; this._record(`char.${k}`, v, `gmcp:${p}`); }
    }
    return this;
  }

  // applyMSDP(obj) — fold an MSDP var/val object into state. MSDP uses upper-case var names
  // (HEALTH, MAX_HEALTH, ROOM_NAME, ...). We map the common ones into the same vitals/room fields
  // so the status line is source-agnostic (GMCP and MSDP feed one model).
  applyMSDP(obj) {
    if (!obj || typeof obj !== "object") return this;
    const map = {
      HEALTH: ["vitals", "hp"], MAX_HEALTH: ["vitals", "maxhp"],
      MANA: ["vitals", "mp"], MAX_MANA: ["vitals", "maxmp"],
      MOVEMENT: ["vitals", "sp"], MAX_MOVEMENT: ["vitals", "maxsp"],
      ROOM_NAME: ["room", "name"], AREA_NAME: ["room", "area"],
      LEVEL: ["char", "level"], CHARACTER_NAME: ["char", "name"],
    };
    for (const [k, v] of Object.entries(obj)) {
      this.raw[`MSDP.${k}`] = v;
      const dest = map[k];
      if (dest) { this[dest[0]][dest[1]] = v; this._record(`${dest[0]}.${dest[1]}`, v, `msdp:${k}`); }
    }
    return this;
  }

  // statusSlots() — the three status-line slots (left/center/right) from the CALM reading. The
  // status line shows the latest vitals plainly; no ⊤ spectacle.
  statusSlots() {
    const name = this.char.name || this.char.Name || "";
    const lvl = this.char.level != null ? ` L${this.char.level}` : "";
    const left = name ? `${name}${lvl}` : "";
    const center = this.room.name ? String(this.room.name) : "";
    const v = this.vitals;
    const bar = (cur, max, tag) => (cur != null ? `${tag} ${cur}${max != null ? "/" + max : ""}` : "");
    const right = [bar(v.hp, v.maxhp, "HP"), bar(v.mp, v.maxmp, "MP"), bar(v.sp, v.maxsp, "SP")].filter(Boolean).join("  ");
    return { left, center, right };
  }

  // panelLines(opts) — the side panel's content: the room, exits, who, and (when opts.audit) the
  // audit trail for each field that has had more than one source/value (the "why" view, on demand).
  panelLines(opts = {}) {
    const out = [];
    if (this.room.name) out.push({ text: String(this.room.name), style: { bold: true } });
    if (this.room.area) out.push({ text: String(this.room.area), style: { dim: true } });
    if (this.room.exits) {
      const exits = Array.isArray(this.room.exits) ? this.room.exits.join(" ") : Object.keys(this.room.exits || {}).join(" ");
      if (exits) out.push({ text: `exits: ${exits}`, style: { fg: "cyan" } });
    }
    if (this.who.length) {
      out.push({ text: `who (${this.who.length}):`, style: { bold: true } });
      for (const w of this.who.slice(0, 12)) out.push({ text: `  ${typeof w === "string" ? w : (w.name || JSON.stringify(w))}` });
    }
    // vitals as plain lines (also shown in the status bar; here for the no-status layouts)
    const v = this.vitals;
    if (v.hp != null) out.push({ text: `HP ${v.hp}${v.maxhp != null ? "/" + v.maxhp : ""}`, style: { fg: "red" } });
    if (v.mp != null) out.push({ text: `MP ${v.mp}${v.maxmp != null ? "/" + v.maxmp : ""}`, style: { fg: "blue" } });
    if (opts.audit) {
      out.push({ text: "── audit ──", style: { dim: true } });
      for (const [path, hist] of Object.entries(this.audit)) {
        if (hist.length < 2) continue; // only fields with more than one observation are interesting
        const sources = [...new Set(hist.map((h) => h.source))];
        if (sources.length < 2) continue; // and only when SOURCES differ (a real "why" question)
        out.push({ text: `${path}: ${hist[hist.length - 1].value}`, style: { fg: "yellow" } });
        for (const h of hist.slice(-3)) out.push({ text: `   ⊢ ${h.value} (${h.source})`, style: { dim: true } });
      }
    }
    return out;
  }
}
