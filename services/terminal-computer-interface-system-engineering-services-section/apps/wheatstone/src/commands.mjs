// commands — the input layer's pure logic: command HISTORY, ALIASES, TRIGGERS, and the parse of a
// raw input line into either a LOCAL slash-command or world text to send. No I/O, no drawing; the
// TUI calls these and acts on the returned intent. This keeps "what does pressing Enter mean?" a
// pure, testable function separate from sockets and the screen.

// === history ================================================================================
// A ring of submitted lines with an up/down cursor. recall(-1) walks back, recall(+1) forward; the
// cursor resets to the end (a fresh blank line) on each submit.
export class History {
  constructor(cap = 500) { this.items = []; this.cap = cap; this.cursor = 0; }
  submit(line) {
    if (line && this.items[this.items.length - 1] !== line) this.items.push(line);
    if (this.items.length > this.cap) this.items.splice(0, this.items.length - this.cap);
    this.cursor = this.items.length;
    return this;
  }
  // recall(dir) — dir -1 = older, +1 = newer. Returns the recalled line (or "" past the newest).
  recall(dir) {
    if (this.items.length === 0) return "";
    this.cursor = Math.max(0, Math.min(this.items.length, this.cursor + dir));
    return this.cursor < this.items.length ? this.items[this.cursor] : "";
  }
}

// === aliases ================================================================================
// An alias maps a first-word command to a replacement template. "$*" in the template is replaced by
// the rest of the input; "$1".."$9" by positional words. Aliases expand BEFORE triggers/sending.
export function expandAlias(aliases, line) {
  const trimmed = line.trim();
  if (!trimmed) return line;
  const [head, ...rest] = trimmed.split(/\s+/);
  const tmpl = aliases[head];
  if (tmpl === undefined) return line;
  let out = tmpl.replace(/\$\*/g, rest.join(" "));
  out = out.replace(/\$([1-9])/g, (_, n) => rest[Number(n) - 1] ?? "");
  return out;
}

// === triggers ===============================================================================
// A trigger watches INCOMING world lines: if a line matches the pattern, the trigger fires its
// action. A pattern is a string (substring match) or a RegExp. matchTriggers returns the list of
// fired { trigger, line, groups } so the TUI can run each action (send text, highlight, notify).
export function matchTriggers(triggers, line) {
  const fired = [];
  for (const t of triggers) {
    if (t.pattern instanceof RegExp) {
      const m = t.pattern.exec(line);
      if (m) fired.push({ trigger: t, line, groups: m.slice(1) });
    } else if (typeof t.pattern === "string") {
      if (line.includes(t.pattern)) fired.push({ trigger: t, line, groups: [] });
    }
  }
  return fired;
}

// === parse ==================================================================================
// parseInput(line) — classify a submitted input line. A line starting with "/" is a LOCAL
// slash-command: { kind: "command", name, args }. Anything else is world text:
// { kind: "send", text }. An empty line is { kind: "send", text: "" } (MUDs treat a bare Enter as
// a command — e.g. clearing a prompt — so we still send it).
export function parseInput(line) {
  if (line.startsWith("/")) {
    const body = line.slice(1);
    const sp = body.indexOf(" ");
    const name = (sp === -1 ? body : body.slice(0, sp)).toLowerCase();
    const args = sp === -1 ? "" : body.slice(sp + 1);
    return { kind: "command", name, args };
  }
  return { kind: "send", text: line };
}

// SLASH_COMMANDS — the local command vocabulary, as data (name → { help }). The TUI dispatches on
// `name`; this table is what /help prints and what a completion UI would read.
export const SLASH_COMMANDS = {
  connect: { help: "/connect [host] [port] — (re)connect to a world" },
  quit: { help: "/quit — leave wheatstone" },
  alias: { help: "/alias <name> <template> — define an alias (no args: list)" },
  unalias: { help: "/unalias <name> — remove an alias" },
  trigger: { help: "/trigger <pattern> <command> — fire <command> when an incoming line matches" },
  clear: { help: "/clear — clear the scrollback" },
  audit: { help: "/audit — toggle the audit side panel (GMCP/MSDP/world state)" },
  help: { help: "/help — list the local commands" },
};
