#!/usr/bin/env node
// wheatstone — the runnable bin. Connect to a MUD and drop into the TUI.
//
//   wheatstone <host> <port>           connect to host:port over telnet
//   wheatstone                         start idle (use /connect host port inside)
//
// in-app: /help  /connect host port  /quit  /alias  /trigger  /audit
// keys:   PgUp/PgDn scroll  Ctrl-L to tail  Ctrl-B side panel  Up/Down history  Ctrl-C quit
//
// For a demonstration of the telnet CLIENT codec against a real socket with no external MUD
// required, see `node bin/demo-telnet.mjs` — a scripted fake server, IAC negotiation transcript
// captured.

import { run } from "../src/app.mjs";

const argv = process.argv.slice(2);

function usage() {
  process.stderr.write([
    "usage: wheatstone <host> <port>",
    "       wheatstone                       start idle (/connect host port inside)",
    "",
    "in-app: /help  /connect host port  /quit  /alias  /trigger  /audit",
    "keys:   PgUp/PgDn scroll  Ctrl-L to tail  Ctrl-B side panel  Up/Down history  Ctrl-C quit",
    "",
    "see also: node bin/demo-telnet.mjs — a headless negotiation-transcript demo, no MUD required",
    "",
  ].join("\n"));
}

if (argv.includes("-h") || argv.includes("--help")) { usage(); process.exit(0); }

const [host, portStr] = argv;
if (host && !portStr) { usage(); process.exit(2); }
const port = portStr ? Number(portStr) : undefined;
run({ host, port, ttype: "WHEATSTONE" });
