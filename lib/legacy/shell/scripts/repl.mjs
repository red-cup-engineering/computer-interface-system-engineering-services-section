// repl — the interactive read -> SETTLE -> project -> loop over a trace root, via node:readline. This is
// the runnable shell: each typed line is a PREDICATION/command appended-or-read; the world SETTLES; the
// OUTPUT is the projected settled section (⊤ shown, ⊥ pending). The PROMPT shows your current standing
// folded LIVE (continuous-auth fold, no session-bit). A THIN DRIVER: all logic is shell.mjs over
// computer's tools; this file is only the readline loop + clock.

import readline from "node:readline";
import { run, render, makeSession, promptLine, VERB_NAMES } from "./shell.mjs";

// startRepl({ trace, input, output, principal, now, halfLife }) — start the loop. `trace` is the path to
// the append-only jsonl EAVT log (the world). `now` is the act-time the continuous-auth fold reads; by
// default it is a monotonically increasing logical clock that advances each command (so decay/freshness
// is well-defined without a wall clock — the bytes/clock are the caller's, per the OS law).
export function startRepl(opts = {}) {
  const trace = opts.trace;
  if (!trace) throw new Error("startRepl: a trace root path is required (the append-only jsonl world)");

  const input = opts.input ?? process.stdin;
  const output = opts.output ?? process.stdout;
  // a logical clock: monotone act-time. Each command advances it by one tick, so freshness/decay folds
  // are total without a wall clock. A caller may pass a fixed `now` (tests) to pin the clock.
  let clock = typeof opts.now === "number" ? opts.now : 0;
  const session = makeSession({
    trace,
    principal: opts.principal ?? null,
    now: clock,
    challenge: null,
  });
  session.halfLife = opts.halfLife ?? Infinity;

  const rl = readline.createInterface({ input, output, prompt: promptLine(session), terminal: !!output.isTTY });

  output.write(banner());
  rl.prompt();

  rl.on("line", (line) => {
    const text = line.trim();
    if (text === "exit" || text === "quit") { rl.close(); return; }
    clock += 1;
    session.now = clock;                 // advance the act-time the auth fold reads
    const result = run(session, text);   // read -> append -> SETTLE -> project (all in shell.mjs/computer)
    const out = render(result);          // project the settled section to glyphs (⊤ shown)
    if (out) output.write(out + "\n");
    rl.setPrompt(promptLine(session));   // the prompt re-folds standing LIVE
    rl.prompt();
  });

  rl.on("close", () => { output.write("\n"); });
  return { session, rl };
}

function banner() {
  return [
    "561-group shell — the settling REPL (read -> SETTLE -> project -> loop).",
    `a command is a PREDICATION appended; the output is the settled section (⊤ shown, ⊥ pending).`,
    `verbs: ${VERB_NAMES.join(" ")}   (login <principal> to act as someone; exit to leave)`,
    "",
  ].join("\n");
}

export default { startRepl };
