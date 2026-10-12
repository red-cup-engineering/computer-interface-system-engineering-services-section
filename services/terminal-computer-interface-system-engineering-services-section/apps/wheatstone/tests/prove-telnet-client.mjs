// prove-telnet-client — THE telnet CLIENT codec proof: option negotiation answered from the client
// side, GMCP parse, MSDP parse, prompt marks, IAC-escaped output, and streaming MCCP2 input.
// Drives the pure codec directly (feed bytes in, collect the bytes it writes + the events it fires).

import { ok, eq, done } from "./_harness.mjs";
import {
  clientTelnet,
  IAC, DO, DONT, WILL, WONT, SB, SE, GA, EOR_MARK,
  GMCP, MSDP, COMPRESS2, NAWS, TTYPE, ECHO, bytesOf,
} from "../src/telnet.mjs";
import { MSDP_VAR, MSDP_VAL } from "@red-cup-engineering/computer-networking-engineering-services-section/telnet";
import { deflateSync } from "node:zlib";

// a fresh codec with a byte collector and event collectors.
function mk(opts = {}) {
  const writes = [];
  const lines = [], prompts = [], gmcp = [], msdp = [], negotiations = [];
  const t = clientTelnet({ write: (b) => writes.push(...b), naws: { width: 100, height: 30 }, ttype: "WHEATSTONE", ...opts });
  t.onLine((l) => lines.push(l));
  t.onPrompt((p) => prompts.push(p));
  t.onGMCP((pkg, data) => gmcp.push({ pkg, data }));
  t.onMSDP((o) => msdp.push(o));
  t.onNegotiate((s) => negotiations.push(s));
  return { t, writes, lines, prompts, gmcp, msdp, negotiations };
}
// find an IAC <verb> <option> triple anywhere in the written bytes.
function hasTriple(writes, verb, option) {
  for (let i = 0; i + 2 < writes.length; i++) if (writes[i] === IAC && writes[i + 1] === verb && writes[i + 2] === option) return true;
  return false;
}

// === plain text lines ===
{
  const { t, lines } = mk();
  t.feed(bytesOf("You see a room.\r\nExits: north south\r\n"));
  eq(lines, ["You see a room.", "Exits: north south"], "CRLF-split plain text into lines");
  t.feed(bytesOf("partial")); // no newline yet
  eq(lines.length, 2, "a partial line is buffered, not emitted");
  t.feed(bytesOf(" line\n"));
  eq(lines[2], "partial line", "bare LF completes the buffered line");
}

// === server offers GMCP (WILL) → client accepts (DO) + Core.Hello handshake ===
{
  const { t, writes, gmcp, negotiations } = mk();
  t.feed(Buffer.from([IAC, WILL, GMCP]));
  ok(hasTriple(writes, DO, GMCP), "server WILL GMCP → client answers DO GMCP");
  ok(t.supports.gmcp, "supports.gmcp is true after accepting");
  ok(negotiations.length > 0, "a negotiation change fired onNegotiate");
  // the handshake GMCP (Core.Hello / Core.Supports.Set) was sent as IAC SB GMCP … IAC SE
  const sawSB = (() => { for (let i = 0; i + 2 < writes.length; i++) if (writes[i] === IAC && writes[i + 1] === SB && writes[i + 2] === GMCP) return true; return false; })();
  ok(sawSB, "client sent a GMCP subnegotiation (Core.Hello handshake) on GMCP up");
}

// === server refuses an option we don't drive (WILL ECHO handled; WILL <random> → DONT) ===
{
  const { t, writes } = mk();
  t.feed(Buffer.from([IAC, WILL, 99])); // option 99: not accepted
  ok(hasTriple(writes, DONT, 99), "server WILL <unsupported> → client answers DONT");
}

// === COMPRESS2/MCCP2 is accepted and the post-marker zlib stream is decoded ===
{
  const { t, writes, lines } = mk();
  t.feed(Buffer.from([IAC, WILL, COMPRESS2]));
  ok(hasTriple(writes, DO, COMPRESS2), "server WILL COMPRESS2 → client answers DO COMPRESS2");
  ok(t.supports.compress2, "supports.compress2 records the negotiated option");

  const lineReady = new Promise((resolve) => t.onLine(resolve));
  const compressed = deflateSync(bytesOf("A compressed room.\r\n"));
  const split = Math.floor(compressed.length / 2);
  t.feed(Buffer.concat([
    Buffer.from([IAC, SB, COMPRESS2, IAC, SE]),
    compressed.subarray(0, split),
  ]));
  t.feed(compressed.subarray(split));
  await lineReady;
  ok(t.supports.compressionActive, "COMPRESS2 marker activates streaming decompression");
  eq(lines, ["A compressed room."], "MCCP2 bytes re-enter the ordinary telnet line parser");
  t.end();
}

// === callers can still decline COMPRESS2 explicitly ===
{
  const { t, writes } = mk({ acceptCompression: false });
  t.feed(Buffer.from([IAC, WILL, COMPRESS2]));
  ok(hasTriple(writes, DONT, COMPRESS2), "acceptCompression=false answers WILL COMPRESS2 with DONT");
  ok(!t.supports.compress2, "declined COMPRESS2 stays unsupported");
}

// === server asks us to NAWS (DO NAWS) → we WILL and send our window size ===
{
  const { t, writes } = mk();
  t.feed(Buffer.from([IAC, DO, NAWS]));
  ok(hasTriple(writes, WILL, NAWS), "server DO NAWS → client answers WILL NAWS");
  // and an IAC SB NAWS 0 100 0 30 IAC SE (100×30 big-endian)
  const sbIdx = writes.findIndex((_, i) => writes[i] === IAC && writes[i + 1] === SB && writes[i + 2] === NAWS);
  ok(sbIdx >= 0, "client sent a NAWS subnegotiation");
  eq([writes[sbIdx + 3], writes[sbIdx + 4], writes[sbIdx + 5], writes[sbIdx + 6]], [0, 100, 0, 30], "NAWS carries 100×30 big-endian");
}

// === server TTYPE SEND → client answers TTYPE IS WHEATSTONE ===
{
  const { t, writes } = mk();
  t.feed(Buffer.from([IAC, DO, TTYPE]));
  ok(hasTriple(writes, WILL, TTYPE), "server DO TTYPE → client answers WILL TTYPE");
  t.feed(Buffer.from([IAC, SB, TTYPE, 1 /*SEND*/, IAC, SE]));
  // expect IAC SB TTYPE 0(IS) W H E A T S T O N E IAC SE
  const name = bytesOf("WHEATSTONE");
  const sbIdx = writes.findIndex((_, i) => writes[i] === IAC && writes[i + 1] === SB && writes[i + 2] === TTYPE && writes[i + 3] === 0);
  ok(sbIdx >= 0, "client sent TTYPE IS in response to SEND");
  const got = writes.slice(sbIdx + 4, sbIdx + 4 + name.length);
  eq(got, [...name], "TTYPE IS carries the terminal name");
}

// === GMCP subnegotiation parse: IAC SB GMCP "Char.Vitals {json}" IAC SE ===
{
  const { t, gmcp } = mk();
  t.feed(Buffer.from([IAC, WILL, GMCP])); // bring GMCP up so the handler is meaningful (parse works regardless)
  const payload = bytesOf('Char.Vitals {"hp":42,"maxhp":100}');
  t.feed(Buffer.concat([Buffer.from([IAC, SB, GMCP]), payload, Buffer.from([IAC, SE])]));
  const last = gmcp[gmcp.length - 1];
  eq(last.pkg, "Char.Vitals", "GMCP package name parsed");
  eq(last.data, { hp: 42, maxhp: 100 }, "GMCP JSON payload parsed");
}

// === GMCP with no JSON body (a bare package, e.g. a signal) ===
{
  const { t, gmcp } = mk();
  t.feed(Buffer.concat([Buffer.from([IAC, SB, GMCP]), bytesOf("Core.Ping"), Buffer.from([IAC, SE])]));
  eq(gmcp[gmcp.length - 1], { pkg: "Core.Ping", data: null }, "bare GMCP package parses with null data");
}

// === MSDP subnegotiation parse via tab's parseMSDP (var/val) ===
{
  const { t, msdp } = mk();
  const body = Buffer.concat([
    Buffer.from([MSDP_VAR]), bytesOf("HEALTH"), Buffer.from([MSDP_VAL]), bytesOf("55"),
    Buffer.from([MSDP_VAR]), bytesOf("ROOM_NAME"), Buffer.from([MSDP_VAL]), bytesOf("The Square"),
  ]);
  t.feed(Buffer.concat([Buffer.from([IAC, SB, MSDP]), body, Buffer.from([IAC, SE])]));
  eq(msdp[msdp.length - 1], { HEALTH: "55", ROOM_NAME: "The Square" }, "MSDP var/val pairs parsed");
}

// === a prompt mark (GA / EOR) flushes the partial line as a PROMPT, not a line ===
{
  const { t, lines, prompts } = mk();
  t.feed(bytesOf("HP:42 > "));
  t.feed(Buffer.from([IAC, GA]));
  eq(prompts, ["HP:42 > "], "IAC GA flushes the partial line as a prompt");
  eq(lines.length, 0, "the prompt was NOT emitted as a completed line");
  t.feed(bytesOf("more")); t.feed(Buffer.from([IAC, EOR_MARK]));
  eq(prompts[1], "more", "IAC EOR also marks a prompt");
}

// === IAC IAC in data collapses to ONE byte in the line, not a command ===
// (a lone 0xFF is invalid UTF-8, so it decodes to the replacement char — the point under test is
// that the TWO 255 bytes became ONE data byte and were NOT read as the start of a command.)
{
  const { t, lines } = mk();
  t.feed(Buffer.from([0x41, IAC, IAC, 0x42, 0x0a])); // "A" 255 255 "B" \n
  eq([...lines[0]].length, 3, "IAC IAC collapses to a single data byte (A·B, 3 code points)");
  eq([lines[0][0], lines[0][2]], ["A", "B"], "the surrounding data bytes survive the escaped 255");
}

// === server ECHO WILL → local echo turns OFF (password-prompt convention) ===
{
  const { t } = mk();
  ok(t.supports.localEcho === true, "localEcho starts true");
  t.feed(Buffer.from([IAC, WILL, ECHO]));
  ok(t.supports.localEcho === false, "server WILL ECHO → localEcho off");
  t.feed(Buffer.from([IAC, WONT, ECHO]));
  ok(t.supports.localEcho === true, "server WONT ECHO → localEcho back on");
}

// === output: sendLine CRLF-terminates and routes player text to the wire ===
{
  const { t, writes } = mk();
  writes.length = 0;
  t.sendLine("look");
  const out = Buffer.from(writes);
  eq([out[out.length - 2], out[out.length - 1]], [13, 10], "sendLine ends with CRLF");
  eq([...out.slice(0, 4)], [...bytesOf("look")], "sendLine writes the player text bytes");
}

// === output: the escapeIAC path doubles a literal 255 byte (used for any binary in output) ===
{
  const { escapeIAC } = await import("../src/telnet.mjs");
  const escaped = escapeIAC(Buffer.from([0x41, 255, 0x42]));
  eq([...escaped], [0x41, 255, 255, 0x42], "escapeIAC doubles a literal 255 byte on the wire");
}

done("prove-telnet-client");
