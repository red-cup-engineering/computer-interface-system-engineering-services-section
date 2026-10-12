// fake-mud-server — a tiny, SCRIPTED server-perspective telnet responder for testing/demoing
// wheatstone's CLIENT codec (src/telnet.mjs) against a real socket, without depending on the full
// @red-cup-engineering/feltos MUD engine. This is intentionally minimal: it offers GMCP, greets,
// echoes lines back (with one scripted special case for "look"), and — once the CLIENT has actually
// accepted GMCP (IAC DO GMCP observed on the wire, not a timer) — pushes one GMCP Char.Vitals
// update. It is not a general telnet server; it is a fixture that speaks exactly the subset of the
// protocol this port's tests and demo need, built from the same wire-alphabet constants
// wheatstone's client uses (`../../src/telnet.mjs`, itself re-exporting feltos's
// @red-cup-engineering/feltos/telnet — server and client share the same IAC/verb/option byte
// values; RFC 854 does not have separate alphabets for the two roles, only separate ANSWER RULES,
// which is what telnet.mjs vs. this file each encode from their own side).
//
// Every byte this server writes and every byte it receives is recorded (opts.onWrite/opts.onRead
// callbacks) so a caller (the demo bin, or a test) can render the exact IAC negotiation transcript.

import { createServer } from "node:net";
import {
  IAC, WILL, WONT, DO, DONT, SB, SE, GMCP,
  bytesOf, escapeIAC,
} from "../../src/telnet.mjs";

// startFakeServer(opts) -> { port, close() } — listens on 127.0.0.1:0 (an OS-assigned free port).
// opts.onWrite(buf) / opts.onRead(buf) — raw byte taps, called for every write/read on the accepted
// socket (used to build the negotiation transcript). opts.scriptedLines — a map of exact input line
// -> reply text (default: echoes "echo: <line>" for anything not in the map).
export function startFakeServer(opts = {}) {
  const onWrite = opts.onWrite ?? (() => {});
  const onRead = opts.onRead ?? (() => {});
  const scriptedLines = opts.scriptedLines ?? { look: "You see the test room." };

  const server = createServer((sock) => {
    const write = (buf) => { onWrite(buf); sock.write(buf); };
    const cmd = (verb, option) => write(Buffer.from([IAC, verb, option]));
    const sub = (option, payload) => {
      const p = Buffer.isBuffer(payload) ? payload : bytesOf(payload);
      write(Buffer.concat([Buffer.from([IAC, SB, option]), escapeIAC(p), Buffer.from([IAC, SE])]));
    };
    const sendLine = (text) => write(bytesOf(`${text}\r\n`));
    const sendGMCP = (pkg, data) => sub(GMCP, `${pkg} ${JSON.stringify(data)}`);

    let clientAcceptsGMCP = false;
    let vitalsSent = false;
    const maybeSendVitals = () => {
      if (clientAcceptsGMCP && !vitalsSent) { vitalsSent = true; sendGMCP("Char.Vitals", { hp: 99, maxhp: 100 }); }
    };

    // a minimal SERVER-perspective input FSM: only what's needed to (a) see the client's DO/DONT
    // answer to our WILL GMCP, (b) skip over any SB block the client sends (its GMCP hello), and
    // (c) accumulate plain text lines to dispatch the scripted replies.
    let state = "data";
    let verb = 0;
    let lineBuf = [];
    const dec = new TextDecoder("utf8");
    const flushLine = () => {
      const line = dec.decode(Buffer.from(lineBuf));
      lineBuf = [];
      if (line === "") return;
      sendLine(Object.prototype.hasOwnProperty.call(scriptedLines, line) ? scriptedLines[line] : `echo: ${line}`);
    };

    sock.on("data", (chunk) => {
      onRead(chunk);
      for (let i = 0; i < chunk.length; i++) {
        const b = chunk[i];
        switch (state) {
          case "data":
            if (b === IAC) state = "iac";
            else if (b === 13) { /* CR: swallow, LF ends the line */ }
            else if (b === 10) flushLine();
            else lineBuf.push(b);
            break;
          case "iac":
            if (b === IAC) { lineBuf.push(IAC); state = "data"; }
            else if (b === WILL || b === WONT || b === DO || b === DONT) { verb = b; state = "verb"; }
            else if (b === SB) state = "sb";
            else state = "data";
            break;
          case "verb":
            if (verb === DO && b === GMCP) clientAcceptsGMCP = true;
            state = "data";
            maybeSendVitals();
            break;
          case "sb": // skip the SB payload; we only care that it ends (IAC SE)
            if (b === IAC) state = "sbiac";
            break;
          case "sbiac":
            if (b === IAC) state = "sb"; // escaped 255 inside SB
            else state = "data";         // SE (or anything else) ends the block
            break;
        }
      }
    });

    // the scripted opening: offer GMCP, then greet. The client answers DO/DONT asynchronously (a
    // real wire hop); vitals are pushed only once that answer is OBSERVED (maybeSendVitals, called
    // from the "verb" case above) — never on a fixed timer, so there is no race to lose.
    cmd(WILL, GMCP);
    sendLine("Connected to the test server.");
  });

  return new Promise((resolve, reject) => {
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      // TEST-FIXTURE-ONLY accommodation: in some sandboxed/containerized environments a freshly
      // bound ephemeral TCP listener has a brief propagation delay before it is actually
      // connectable (observed here: ECONNREFUSED immediately after the "listening" callback fires,
      // reliably fixed by a short grace delay). This says nothing about telnetWorld's real
      // production connect() behavior, which stays fail-fast — this delay lives only in the test
      // fixture's own listener startup, never in the shipped client codec.
      setTimeout(() => resolve({ port, close: () => new Promise((r) => server.close(() => r())) }), 150);
    });
  });
}
