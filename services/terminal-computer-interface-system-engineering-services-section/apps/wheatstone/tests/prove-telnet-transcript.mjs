// prove-telnet-transcript — a FULL scripted IAC negotiation + GMCP exchange, driven over a real
// local TCP socket against bin/lib/fake-mud-server.mjs, with the exact byte-level transcript (both
// directions, decoded by the same annotate() the demo prints) asserted. Where prove-smoke.mjs's
// real-socket block asserts on the app's RENDERED frames, this asserts on the WIRE ITSELF — every
// S→C and C→S negotiation/subnegotiation/text run, byte-exact.
//
// One ordering carve-out: the CLIENT's reaction to the server's WILL GMCP is three separate
// socket.write() calls in one synchronous turn — DO GMCP, then the Core.Hello handshake, then
// Core.Supports.Set (see telnet.mjs's helloGMCP, called synchronously from the DO-GMCP negotiation
// handler) — and TCP preserves THAT side's own write order. But the fake server reacts to seeing
// "IAC DO GMCP" by pushing Char.Vitals immediately, on its OWN independent write schedule, before
// it has necessarily even received the client's later Hello/Supports.Set bytes. There is no
// cross-socket ordering guarantee between "the client's next write" and "the server's reactive
// push", so the RELATIVE order of the client's two GMCP subnegotiations versus the server's
// Char.Vitals push is genuinely non-deterministic — GMCP's real asynchronous nature over telnet.
// This test pins down every message's EXACT bytes and every ordering constraint that actually
// holds (WILL GMCP first; the greeting next; DO GMCP next, always before either GMCP
// subnegotiation or the push; the client's own two writes stay in their own relative order; "look"
// is sent only once GMCP has already landed, so it and the server's reply are always last) while
// treating the {Core.Hello, Core.Supports.Set, Char.Vitals} cluster as a set, not a fixed sequence.

import { createConnection } from "node:net";
import { clientTelnet } from "../src/telnet.mjs";
import { startFakeServer } from "../bin/lib/fake-mud-server.mjs";
import { annotate } from "../bin/lib/annotate-telnet.mjs";
import { eq, ok, done } from "./_harness.mjs";

function waitFor(pred, ms = 2000) {
  return new Promise((resolve, reject) => {
    const t0 = Date.now();
    const tick = () => {
      if (pred()) return resolve();
      if (Date.now() - t0 > ms) return reject(new Error("waitFor timed out"));
      setTimeout(tick, 10);
    };
    tick();
  });
}

const transcript = [];
const { port, close } = await startFakeServer({
  onWrite: (buf) => { for (const line of annotate(buf)) transcript.push(`S→C  ${line}`); },
  onRead: (buf) => { for (const line of annotate(buf)) transcript.push(`C→S  ${line}`); },
});

const receivedLines = [];
const gmcpUpdates = [];
const socket = createConnection({ host: "127.0.0.1", port });
const tel = clientTelnet({ write: (bytes) => socket.write(bytes), ttype: "WHEATSTONE" });
tel.onLine((line) => receivedLines.push(line));
tel.onGMCP((pkg, data) => gmcpUpdates.push({ pkg, data }));
socket.on("data", (chunk) => tel.feed(chunk));

try {
  await new Promise((resolve, reject) => {
    socket.on("connect", resolve);
    socket.on("error", reject);
  });

  await waitFor(() => receivedLines.includes("Connected to the test server."));
  // Wait for the server's GMCP push to complete BEFORE sending "look". The server sends Char.Vitals
  // as soon as it observes "IAC DO GMCP" on the wire (no fixed timer — see fake-mud-server.mjs), but
  // that push and this test's own "look" write are two independent event-loop actions with no
  // ordering relationship unless this test enforces one. Waiting here makes the transcript's ORDER
  // — not just its final content — deterministic, which is what a byte-exact assertion requires.
  await waitFor(() => gmcpUpdates.length > 0);
  socket.write(Buffer.from("look\r\n"));
  await waitFor(() => receivedLines.includes("You see the test room."));

  // === the exact SET of 8 messages exchanged, every one byte-verified (via annotate()'s decode of
  // the actual raw bytes) — no message is missing, extra, or garbled, regardless of interleave order.
  const EXPECTED = [
    "S→C  IAC WILL GMCP",
    'S→C  TEXT "Connected to the test server.\\r\\n"',
    "C→S  IAC DO GMCP",
    'C→S  IAC SB GMCP "Core.Hello {\\"client\\":\\"wheatstone\\",\\"version\\":\\"0.3.0\\"}" IAC SE',
    'C→S  IAC SB GMCP "Core.Supports.Set [\\"Char 1\\",\\"Room 1\\",\\"Comm 1\\"]" IAC SE',
    'S→C  IAC SB GMCP "Char.Vitals {\\"hp\\":99,\\"maxhp\\":100}" IAC SE',
    'C→S  TEXT "look\\r\\n"',
    'S→C  TEXT "You see the test room.\\r\\n"',
  ];
  eq(transcript.length, EXPECTED.length, `exactly ${EXPECTED.length} messages crossed the wire`);
  eq([...transcript].sort(), [...EXPECTED].sort(), "the exact 8 messages (byte-exact, via annotate()) were exchanged — as a set, since one 3-way interleave (below) isn't ordering-guaranteed");

  // === the ordering constraints that ARE actually guaranteed (checked individually, not as one
  // fixed sequence — see this file's header for exactly which 3 messages have no guaranteed
  // relative order, and why that is a real protocol property, not a test gap) ====================
  const idx = (s) => transcript.indexOf(s);
  ok(idx("S→C  IAC WILL GMCP") === 0, "the server's GMCP offer is always the first byte on the wire");
  ok(idx('S→C  TEXT "Connected to the test server.\\r\\n"') === 1, "the greeting always follows immediately");
  ok(idx("C→S  IAC DO GMCP") === 2, "the client answers DO GMCP third, before anything GMCP-related follows");
  // the client's OWN two writes keep their own relative order (guaranteed: same socket, same
  // synchronous turn in helloGMCP) — but either or both may fall before or after the server's push.
  ok(
    idx('C→S  IAC SB GMCP "Core.Hello {\\"client\\":\\"wheatstone\\",\\"version\\":\\"0.3.0\\"}" IAC SE')
      < idx('C→S  IAC SB GMCP "Core.Supports.Set [\\"Char 1\\",\\"Room 1\\",\\"Comm 1\\"]" IAC SE'),
    "the client's own Core.Hello write lands before its own Core.Supports.Set write (one socket, one synchronous turn)"
  );
  ok(idx('C→S  TEXT "look\\r\\n"') === 6, "\"look\" is sent only after all of DO GMCP + both client GMCP writes + the server's Char.Vitals push have already landed (this test waits on gmcpUpdates before writing it)");
  ok(idx('S→C  TEXT "You see the test room.\\r\\n"') === 7, "the reply to \"look\" is always last");

  // === cross-checks: the decoded app-level results agree with the transcript's raw content ======
  eq(receivedLines, ["Connected to the test server.", "You see the test room."], "decoded lines match the transcript's TEXT entries");
  eq(gmcpUpdates, [{ pkg: "Char.Vitals", data: { hp: 99, maxhp: 100 } }], "decoded GMCP matches the transcript's SB GMCP payload");
  ok(tel.supports.gmcp, "GMCP was negotiated up (client answered DO to the server's WILL)");
} finally {
  socket.destroy();
  await close();
}

done("prove-telnet-transcript");
process.exit(0);
