// shell — the SETTLING SHELL engine: the read -> SETTLE -> project -> loop, as a pure-ish driver over a
// trace root. This is the FIRST userspace interface app for the 561-group computer — NOT part of
// computer proper. It is a THIN DRIVER: every bit of logic lives in @561-group/computer's tools. The
// shell only (1) READS rows from the trace, (2) APPENDS a predication, (3) SETTLES the world to a fixed
// point (substrate.settle), (4) PROJECTS the settled section back, with ⊤ SHOWN and ⊥ pending.
//
// THE LAW this driver respects (it does not implement it — computer's tools do; the shell only must not
// VIOLATE it):
//   - paraconsistent: a contradiction is ⊤ — HELD, both witnesses surfaced — never resolved to a
//     winner, never collapsed to access-denied. The shell DISPLAYS ⊤; it never picks a side.
//   - append-only: state IS the folded trace. A command appends a row; nothing overwrites. There is no
//     session-bit — "who am I / may I" is a CONTINUOUS FOLD of evidence, recomputed every prompt.
//   - evidence is linear witnesses: every row is conserved on disk; the shell never deletes a row.
//   - identity via jcs: row identity / capability identity are computer's (rowId/jcs); the shell reuses.
//
// The medium is EAVT ROWS / settled SECTIONS — not text. Commands compose computer's tools like
// coreutils over the trace; the "pipe" is the fold/settle. The shell maps a small verb set onto them.

import { appendFileSync, mkdirSync, readFileSync, existsSync } from "node:fs";
import { dirname } from "node:path";

import {
  settle,
  section as projectSection,
  relate,
  relateFrom,
  rowId,
  jcs,
} from "@561-group/computer/posix-holography/eavt-substrate";

import principal, {
  recognize,
  dispute,
  present,
  whois,
  authenticated,
  may,
  can,
  grant,
  revoke,
  recognizesAuthority,
  withholdsAuthority,
  IDENTITY_CONVERSE,
  CAPABILITY_CONVERSE,
} from "./principal.mjs";

const CHARGE_GLYPHS = Object.freeze({ potential: "t", active: "f", absurd: "⊥", stable: "⊤" });

// === trace I/O — the ONLY side-effects in the shell ========================================
// A trace root is a single append-only jsonl EAVT log. We read it as raw {e,a,v,t} rows (NOT through
// eavt-read's articulate, which returns a presheaf — the shell wants the bare rows to hand to settle).
// readTrace and appendRow are the shell's whole footprint on the world: read all rows, append one row.
// (computer's eavt-append is the same appendFileSync discipline; we inline it to keep raw rows the
// medium and avoid the articulate round-trip. Identity/fold/settle all stay computer's.)

export function readTrace(path) {
  if (!existsSync(path)) return [];
  const text = readFileSync(path, "utf8");
  const rows = [];
  for (const line of text.split("\n")) {
    const s = line.trim();
    if (!s) continue;
    rows.push(JSON.parse(s));
  }
  return rows;
}

export function appendRow(path, row) {
  mkdirSync(dirname(path), { recursive: true });
  appendFileSync(path, JSON.stringify(row) + "\n", "utf8");
  return row;
}

// === the converse map the shell folds under ================================================
// The shell's settle must know which predicates are CONVERSES (negative faces) so a recognize + a
// dispute, or a grant + a revoke, rise to ⊤ instead of two unrelated cells. We compose the maps the
// principal tool already declares (identity + capability), plus the authority-graph converse, plus a
// general user-facing `not-<p>` convention so a hand-typed contradiction also folds to ⊤.
const CONVERSE = Object.freeze({
  ...IDENTITY_CONVERSE,
  ...CAPABILITY_CONVERSE,
  "withholds-authority": "recognizes-authority",
});

// resolveConverse(rows) — extend CONVERSE with any `not-<p>` predicates actually present in the trace,
// so a user who appends (alice, located-in, kitchen) and (alice, not-located-in, kitchen) sees ⊤. The
// `not-` prefix is the shell's user-facing convention for "the converse of"; computer's fold also reads
// in-trace `has-converse` rows on its own.
function resolveConverse(rows) {
  const conv = { ...CONVERSE };
  for (const r of rows) {
    if (typeof r.a === "string" && r.a.startsWith("not-")) conv[r.a] = r.a.slice("not-".length);
  }
  return conv;
}

// === a session is a PLAY (not a session-bit) ===============================================
// A session records WHO you are acting AS. It carries NO authentication bit: every time the shell needs
// "am I authenticated / may I", it FOLDS the trace fresh (authenticated()/may()). The session is just
// the principal name + an optional challenge play + the act-time clock the continuous-auth fold reads.
export function makeSession({ trace, principal: actingAs = null, now = null, challenge = null } = {}) {
  return { trace, actingAs, now, challenge };
}

// === the settle/project core ===============================================================
// settleSubject(rows, subject) — fold a subject's trace to its settled section, folding under the
// shell's converse map so contradictions surface as ⊤. This is computer's settle; the shell only
// supplies the converse. Returns the folded section (fiber of charged cells).
export function settleSubject(rows, subject, opts = {}) {
  return settle(subject, rows, { converse: resolveConverse(rows), ...opts });
}

// projectCells(folded) — split a folded section into the three readings the shell prints: affirmed (t),
// contradicted (⊤ — SHOWN with both witnesses), and pending (⊥ — present as a cell but neither face
// stands). We surface ⊤ explicitly because the law forbids resolving it. This is computer's section()
// plus a ⊥/pending read off the fiber.
export function projectCells(folded, rows) {
  const sec = projectSection(folded);            // {affirmed, denied, contradicted} — computer's
  const witnessIndex = buildWitnessIndex(rows ?? []);
  const witnessesFor = (cell) => {
    // find the folded fiber cell for this (predicate, object) and resolve its evidence ids to parties.
    const fc = folded.fiber.find((c) => c.predicate === cell.predicate && jcs(c.object) === jcs(cell.object));
    if (!fc) return { pos: [], neg: [] };
    const [posIds, negIds] = fc.value.evidence;
    return { pos: partiesFor(posIds, witnessIndex), neg: partiesFor(negIds, witnessIndex) };
  };
  return {
    affirmed: sec.affirmed.map((c) => ({ ...c, by: witnessesFor(c).pos })),
    denied: sec.denied.map((c) => ({ ...c, by: witnessesFor(c).neg })),
    // ⊤ — HELD. Both witness sets surfaced; NEVER resolved to a winner.
    contradicted: sec.contradicted.map((c) => {
      const w = witnessesFor(c);
      return { ...c, held: true, value: "stable", recognizedBy: w.pos, disputedBy: w.neg };
    }),
  };
}

// === the verb set — a small coreutils-over-the-trace surface ===============================
// Each verb maps to a computer tool over EAVT rows / sections. A verb either APPENDS a predication
// (relate / believe / recognize / grant / revoke …) and returns the settled projection, or it READS a
// fold (settle / section / whois / may / can / authenticated). The shell only routes; the tools decide.
//
// run(session, line) — parse one command line, dispatch the verb, return a structured result the REPL
// renders. It NEVER throws on a bad verb — it returns an error result, because the prompt must keep
// folding. A command is a PREDICATION appended; the result is the settled section (⊤ shown).
export function run(session, line) {
  const argv = tokenize(line);
  if (!argv.length) return { kind: "noop" };
  const [verb, ...rest] = argv;
  const handler = VERBS[verb];
  if (!handler) {
    return { kind: "error", verb, message: `unknown verb '${verb}'. verbs: ${Object.keys(VERBS).join(" ")}` };
  }
  try {
    return handler(session, rest);
  } catch (e) {
    return { kind: "error", verb, message: e?.message ?? String(e) };
  }
}

const VERBS = {
  // --- READS over the fold ---------------------------------------------------------------
  // settle <subject> — fold the subject's trace and project its settled section (affirmed / ⊤ / pending).
  settle(session, [subject]) {
    requireArg(subject, "settle <subject>");
    const rows = readTrace(session.trace);
    const folded = settleSubject(rows, subject);
    return { kind: "section", subject, projection: projectCells(folded, rows) };
  },

  // section <subject> — alias of settle; the projected settled SECTION is the shell's "output".
  section(session, args) { return VERBS.settle(session, args); },

  // relate <predicate> <object> — the relational read: who stands in <predicate> to <object>? (e.g.
  // `relate located-in kitchen`). Pure computer/substrate.relate over the trace.
  relate(session, [predicate, ...objectParts]) {
    requireArg(predicate, "relate <predicate> <object>");
    const object = parseValue(objectParts.join(" "));
    const rows = readTrace(session.trace);
    return { kind: "relate", predicate, object, subjects: relate(rows, predicate, object) };
  },

  // of <subject> <predicate> — the inverse relational read: what does <subject> stand in <predicate> to?
  of(session, [subject, predicate]) {
    requireArg(subject, "of <subject> <predicate>");
    requireArg(predicate, "of <subject> <predicate>");
    const rows = readTrace(session.trace);
    return { kind: "relate-from", subject, predicate, objects: relateFrom(rows, subject, predicate) };
  },

  // --- APPENDS a predication (then settles + projects) -----------------------------------
  // believe <subject> <predicate> <object…> — append (subject, predicate, object), witnessed BY the
  // session's acting principal, then settle the subject and project. A contradicting predication
  // (predicate vs not-<predicate>) shows ⊤ — both witnesses — NOT an overwrite.
  believe(session, [subject, predicate, ...objectParts]) {
    requireArg(subject, "believe <subject> <predicate> <object>");
    requireArg(predicate, "believe <subject> <predicate> <object>");
    const object = parseValue(objectParts.join(" "));
    const row = freezeRow({ e: subject, a: predicate, v: object, t: witnessStamp(session) });
    appendRow(session.trace, row);
    const rows = readTrace(session.trace);
    return {
      kind: "appended",
      row,
      subject,
      projection: projectCells(settleSubject(rows, subject), rows),
    };
  },

  // --- IDENTITY (principal tool) ---------------------------------------------------------
  // whois <principal> — FOLD the identity cell. A recognition dispute is ⊤, HELD with both witnesses.
  whois(session, [name]) {
    requireArg(name, "whois <principal>");
    const rows = readTrace(session.trace);
    const id = whois(rows, name);
    return { kind: "whois", whois: id };
  },

  // recognize <principal> <as…> — append a positive identity claim, witnessed by the acting principal
  // (web-of-trust). recognize <principal> not <as> appends the DISPUTE converse instead.
  recognize(session, [name, ...rest]) {
    requireArg(name, "recognize <principal> [not] <as>");
    const by = actorName(session);
    let row;
    if (rest[0] === "not") {
      row = dispute(by, name, parseValue(rest.slice(1).join(" ")), session.now);
    } else {
      row = recognize(by, name, parseValue(rest.join(" ")), session.now);
    }
    appendRow(session.trace, row);
    const rows = readTrace(session.trace);
    return { kind: "whois", row, whois: whois(rows, name) };
  },

  // login <principal> [nonce] — a challenge-response PLAY. The shell ISSUES a challenge (a nonce) and
  // the principal RESPONDS; the surviving strategy is authenticated. This sets the session's acting
  // principal and challenge — but grants NO bit: `authenticated` is still a continuous fold read at
  // act-time. (The crypto is the caller's; here the matching response is the surviving play.)
  login(session, [name, nonce]) {
    requireArg(name, "login <principal> [nonce]");
    const issued = { nonce: nonce ?? `nonce:${rowId({ name, at: session.now }).slice(0, 12)}` };
    const challenge = { issued, response: { nonce: issued.nonce, t: session.now } };
    session.actingAs = name;
    session.challenge = challenge;
    // present the challenge-response as evidence ON the principal (a row the auth fold reads).
    const row = present(name, name, { kind: "capability", resource: `login:${issued.nonce}` }, session.now);
    appendRow(session.trace, row);
    const rows = readTrace(session.trace);
    const auth = authenticated(rows, name, { now: session.now, challenge, halfLife: session.halfLife ?? Infinity });
    return { kind: "login", principal: name, auth };
  },

  // who — fold the session's current standing: WHO am I acting as, and what is my authenticated fold
  // RIGHT NOW (continuous, recomputed; no session-bit). This is what the live prompt shows.
  who(session) {
    const name = session.actingAs;
    if (!name) return { kind: "who", principal: null, auth: null };
    const rows = readTrace(session.trace);
    const auth = authenticated(rows, name, { now: session.now, challenge: session.challenge, halfLife: session.halfLife ?? Infinity });
    return { kind: "who", principal: name, auth };
  },

  // --- AUTHORITY (governAction via principal.may) ----------------------------------------
  // may <action> [principal] [--regime <r>] — the AUTHORITY fold: route through governAction over the
  // recognition graph. Returns FOUR (t/f/⊤/⊥) — NOT a boolean. Under the default (kyriarchical/
  // capability) regime, holding a covering capability folds to t and lacking one to f. Routing through
  // `contrarian` lets contested authority in the recognition graph rise to ⊤ — HELD and SURFACED, not
  // denied; `consensus-by-withdrawal` yields ⊥ (no basis) when no affirmation has entered the join.
  // governance POSITS the value; the shell only routes the regime and surfaces FOUR. Defaults to the
  // session's acting principal.
  may(session, args) {
    const { positional, opts } = takeOpts(args, ["regime"]);
    const [action, name] = positional;
    requireArg(action, "may <action> [principal] [--regime <r>]");
    const subject = name ?? actorName(session);
    const rows = readTrace(session.trace);
    const decision = may(rows, subject, action, opts.regime ? { regime: opts.regime } : {});
    return { kind: "may", principal: subject, action, decision, four: decision.four ?? decision.value };
  },

  // can <action> [principal] — the bare object-capability limb: does the principal HOLD a covering
  // capability? FOUR, not boolean (⊤ when both granted and revoked).
  can(session, [action, name]) {
    requireArg(action, "can <action> [principal]");
    const subject = name ?? actorName(session);
    const rows = readTrace(session.trace);
    return { kind: "can", capability: can(rows, subject, action) };
  },

  // grant <principal> <action> — the acting principal GRANTS <principal> a capability covering <action>.
  // revoke is the converse; a grant + a revoke on the same cell rise to ⊤ (held), never dropped.
  grant(session, [to, action]) {
    requireArg(to, "grant <principal> <action>");
    requireArg(action, "grant <principal> <action>");
    const row = grant(actorName(session), to, action, session.now);
    appendRow(session.trace, row);
    const rows = readTrace(session.trace);
    return { kind: "can", row, capability: can(rows, to, action) };
  },
  revoke(session, [to, action]) {
    requireArg(to, "revoke <principal> <action>");
    requireArg(action, "revoke <principal> <action>");
    const row = revoke(actorName(session), to, action, session.now);
    appendRow(session.trace, row);
    const rows = readTrace(session.trace);
    return { kind: "can", row, capability: can(rows, to, action) };
  },

  // affirm/withhold <principal> <action> — append authority-graph evidence the may() fold reads. Two
  // parties affirming + withholding the SAME authority is how may() rises to ⊤.
  affirm(session, [name, action]) {
    requireArg(name, "affirm <principal> <action>");
    requireArg(action, "affirm <principal> <action>");
    const row = recognizesAuthority(actorName(session), name, action, session.now);
    appendRow(session.trace, row);
    const rows = readTrace(session.trace);
    return { kind: "may", principal: name, action, decision: may(rows, name, action), four: may(rows, name, action).four };
  },
  withhold(session, [name, action]) {
    requireArg(name, "withhold <principal> <action>");
    requireArg(action, "withhold <principal> <action>");
    const row = withholdsAuthority(actorName(session), name, action, session.now);
    appendRow(session.trace, row);
    const rows = readTrace(session.trace);
    return { kind: "may", principal: name, action, decision: may(rows, name, action), four: may(rows, name, action).four };
  },

  // --- raw trace inspection --------------------------------------------------------------
  // trace [subject] — dump the raw rows (optionally for one subject). Evidence is linear; this shows it.
  trace(session, [subject]) {
    const rows = readTrace(session.trace);
    return { kind: "trace", rows: subject ? rows.filter((r) => r.e === subject) : rows };
  },

  // help — list the verbs.
  help() {
    return { kind: "help", verbs: Object.keys(VERBS) };
  },
};

export const VERB_NAMES = Object.freeze(Object.keys(VERBS));

// === helpers ===============================================================================
// witnessStamp(session) — the {by, at} witness the principal tool's rows ride in `t`. The acting
// principal is the witness; the act-time is the session clock the continuous-auth/decay fold reads.
function witnessStamp(session) {
  return Object.freeze({ by: actorName(session), at: session.now ?? null });
}
function actorName(session) {
  return session.actingAs ?? "anon";
}
function freezeRow(r) { return Object.freeze(r); }

function requireArg(v, usage) {
  if (v === undefined || v === null || v === "") throw new Error(`usage: ${usage}`);
}

// takeOpts(args, names) — split `--<name> <value>` flags (for the given names) out of an argv, leaving
// the positionals. So `may deploy alice --regime contrarian` -> positional [deploy, alice], {regime}.
function takeOpts(args, names) {
  const set = new Set(names.map((n) => `--${n}`));
  const positional = [];
  const opts = {};
  for (let i = 0; i < args.length; i++) {
    if (set.has(args[i])) opts[args[i].slice(2)] = args[++i];
    else positional.push(args[i]);
  }
  return { positional, opts };
}

// tokenize(line) — a coreutils-ish split: whitespace-separated, with "double-quoted" runs kept whole.
function tokenize(line) {
  const out = [];
  const re = /"([^"]*)"|(\S+)/g;
  let m;
  while ((m = re.exec(line)) !== null) out.push(m[1] !== undefined ? m[1] : m[2]);
  return out;
}

// parseValue(s) — a row's object `v` is a first-class value. We read JSON literals (numbers, true/false,
// null, objects, arrays) and fall back to the bare string. So `believe x age 5` stores the NUMBER 5.
function parseValue(s) {
  if (s === undefined || s === "") return "";
  try { return JSON.parse(s); } catch { return s; }
}

function buildWitnessIndex(rows) {
  const idx = new Map();
  for (const r of rows) {
    const t = r.t;
    const by = t && typeof t === "object" ? t.by : undefined;
    idx.set(rowId(r), { by });
  }
  return idx;
}
function partiesFor(ids, idx) {
  const out = new Set();
  for (const id of ids) { const w = idx.get(id); if (w?.by) out.add(w.by); }
  return [...out].sort();
}

// === rendering — turn a verb result into the projected text the REPL prints ================
// The medium is rows/sections; this is only the final projection to glyphs for a human. ⊤ is SHOWN
// (both witnesses); ⊥/pending is shown as pending; FOUR decisions print their glyph, never a boolean.
export function render(result) {
  switch (result?.kind) {
    case "noop": return "";
    case "error": return `! ${result.message}`;
    case "help": return `verbs: ${result.verbs.join(" ")}`;
    case "section":
    case "appended": {
      const lines = [];
      if (result.kind === "appended") lines.push(`+ ${fmtRow(result.row)}`);
      lines.push(`= ${result.subject}`);
      lines.push(...renderProjection(result.projection));
      return lines.join("\n");
    }
    case "relate":
      return `${result.subjects.length ? result.subjects.join(" ") : "(none)"}  <- ${result.predicate} ${fmtVal(result.object)}`;
    case "relate-from":
      return `${result.subject} ${result.predicate} -> ${result.objects.length ? result.objects.map(fmtVal).join(" ") : "(none)"}`;
    case "whois": return renderWhois(result.whois);
    case "login":
      return `login ${result.principal}: ${fourGlyph(result.auth.value)} ${result.auth.reason}`;
    case "who":
      if (!result.principal) return "(not acting as any principal — use: login <principal>)";
      return `${result.principal}: ${fourGlyph(result.auth.value)} ${result.auth.reason}`;
    case "may": {
      const g = fourGlyph(result.four ?? result.decision.value);
      return `may ${result.principal} ${result.action}? ${g}  (${result.decision.reason ?? result.decision.regime ?? "governed"})`;
    }
    case "can": {
      const c = result.capability;
      const extra = c.value === "stable"
        ? `  granted-by ${c.grantedBy.join(",")} / revoked-by ${c.revokedBy.join(",")} — HELD`
        : c.grantedBy?.length ? `  granted-by ${c.grantedBy.join(",")}` : "";
      return `can ${c.principal} ${c.action}? ${fourGlyph(c.value)}${extra}`;
    }
    case "trace":
      return result.rows.length ? result.rows.map(fmtRow).join("\n") : "(empty trace)";
    default:
      return JSON.stringify(result);
  }
}

function renderProjection(p) {
  const lines = [];
  for (const c of p.affirmed) lines.push(`  t  ${c.predicate} ${fmtVal(c.object)}${c.by?.length ? `  by ${c.by.join(",")}` : ""}`);
  for (const c of p.denied) lines.push(`  f  ${c.predicate} ${fmtVal(c.object)}${c.by?.length ? `  by ${c.by.join(",")}` : ""}`);
  // ⊤ — HELD. Surface BOTH witness sets; never resolve.
  for (const c of p.contradicted) {
    lines.push(`  ${CHARGE_GLYPHS.stable ?? "⊤"}  ${c.predicate} ${fmtVal(c.object)}  HELD — recognized-by ${c.recognizedBy.join(",") || "?"} / disputed-by ${c.disputedBy.join(",") || "?"}`);
  }
  if (!lines.length) lines.push(`  ${CHARGE_GLYPHS.absurd ?? "⊥"}  (pending — no settled fact)`);
  return lines;
}

function renderWhois(id) {
  const lines = [`who is ${id.principal}?`];
  for (const r of id.recognizedAs) lines.push(`  t  ${fmtVal(r.claim)}  by ${r.by.join(",")}`);
  for (const d of id.disputed) lines.push(`  ${CHARGE_GLYPHS.stable ?? "⊤"}  ${fmtVal(d.claim)}  HELD — recognized-by ${d.recognizedBy.join(",") || "?"} / disputed-by ${d.disputedBy.join(",") || "?"}`);
  for (const a of id.attestations) lines.push(`  ·  ${a.attribute}=${fmtVal(a.value)} by ${a.by.join(",")}${a.contested ? " (contested)" : ""}`);
  if (id.recognizedAs.length === 0 && id.disputed.length === 0 && id.attestations.length === 0) {
    lines.push(`  ${CHARGE_GLYPHS.absurd ?? "⊥"}  (no evidence names this principal yet)`);
  }
  return lines.join("\n");
}

function fourGlyph(v) {
  if (v === "potential") return `${CHARGE_GLYPHS.potential ?? "t"} (t)`;
  if (v === "active") return `${CHARGE_GLYPHS.active ?? "f"} (f)`;
  if (v === "stable") return `${CHARGE_GLYPHS.stable ?? "⊤"} (⊤ contested — HELD)`;
  return `${CHARGE_GLYPHS.absurd ?? "⊥"} (⊥ no basis — pending)`;
}

function fmtVal(v) { return typeof v === "string" ? v : jcs(v); }
function fmtRow(r) {
  const by = r.t && typeof r.t === "object" ? r.t.by : r.t;
  return `(${r.e}, ${r.a}, ${fmtVal(r.v)})${by ? ` @${by}` : ""}`;
}

// promptLine(session) — the live prompt: the acting principal + its CONTINUOUS-fold standing glyph,
// recomputed from the trace every loop (no session-bit). ⊤ if authentication is contested.
export function promptLine(session) {
  const name = session.actingAs;
  if (!name) return "anon ⊥ > ";
  const rows = readTrace(session.trace);
  const auth = authenticated(rows, name, { now: session.now, challenge: session.challenge, halfLife: session.halfLife ?? Infinity });
  const g = auth.value === "potential" ? (CHARGE_GLYPHS.potential ?? "t")
    : auth.value === "stable" ? (CHARGE_GLYPHS.stable ?? "⊤")
    : auth.value === "active" ? (CHARGE_GLYPHS.active ?? "f")
    : (CHARGE_GLYPHS.absurd ?? "⊥");
  return `${name} ${g} > `;
}

export { CHARGE_GLYPHS, principal };
export default { run, render, readTrace, appendRow, settleSubject, projectCells, makeSession, promptLine, VERB_NAMES };
