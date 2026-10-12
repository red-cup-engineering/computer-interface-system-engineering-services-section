#!/usr/bin/env node
// shell bin — the runnable entry for the 561-group settling shell/REPL.
//
//   shell [trace.jsonl] [--as <principal>] [--half-life <n>]
//
// `trace.jsonl` is the append-only EAVT world the shell drives (default ./world.jsonl). `--as` starts
// the session acting AS a principal (still no auth bit — standing is a continuous fold). `--half-life`
// sets the decay window for the continuous-auth fold (default Infinity = no decay).
//
// This bin is a THIN launcher: it parses argv and hands off to repl.startRepl, which loops over
// shell.mjs's verbs (which compose computer's tools). No logic lives here.

import { resolve } from "node:path";
import { startRepl } from "../scripts/repl.mjs";

function parseArgv(argv) {
  const out = { trace: null, as: null, halfLife: Infinity };
  const rest = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--as") out.as = argv[++i];
    else if (a === "--half-life") out.halfLife = Number(argv[++i]);
    else if (a === "--help" || a === "-h") out.help = true;
    else rest.push(a);
  }
  out.trace = rest[0] ?? null;
  return out;
}

const opts = parseArgv(process.argv.slice(2));
if (opts.help) {
  process.stdout.write("usage: shell [trace.jsonl] [--as <principal>] [--half-life <n>]\n");
  process.exit(0);
}

const trace = resolve(process.cwd(), opts.trace ?? "world.jsonl");
startRepl({ trace, principal: opts.as, halfLife: opts.halfLife });
