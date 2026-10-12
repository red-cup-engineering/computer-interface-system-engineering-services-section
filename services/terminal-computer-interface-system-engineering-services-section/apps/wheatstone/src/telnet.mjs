// telnet — the CLIENT side of the MUD telnet protocol. This is the mirror of
// @red-cup-engineering/feltos's src/telnet.mjs, which is written from the SERVER's perspective (it
// WILLs the server-driven options and answers a client's DO/DONT). A client cannot reuse that state
// machine directly: the roles are reversed. The server OFFERS (IAC WILL GMCP); the client must
// ANSWER (IAC DO GMCP to accept, IAC DONT to decline) and then RECEIVE the out-of-band channels the
// server drives. So we REUSE feltos's wire alphabet — the IAC/verb/option constants and the byte
// helpers (bytesOf, escapeIAC, parseMSDP) — directly from @red-cup-engineering/computer-networking-engineering-services-section/telnet (no
// longer a local shim: both sides trace to the same legacy `tab` wire alphabet, and feltos is the
// engine that publishes it) — and implement the client-perspective negotiation + input state
// machine cleanly here.
//
// The wire (RFC 854 + MUD extensions): a byte stream punctuated by IAC (255). A command is
// IAC <verb> [<option>]; a subnegotiation is IAC SB <option> <payload…> IAC SE; a literal 255 in
// data is escaped IAC IAC. We run the standard input state machine
// (data → iac → verb → sb-opt → sb → sbiac), answer the server's option offers per the telnet
// rule ("answer WILL with DO/DONT, DO with WILL/WONT"), capture SB payloads (dispatching GMCP and
// MSDP to handlers), and surface everything else as clean text lines with CR/LF normalized and
// stray IAC commands (GA/EOR — the prompt marks) reported via onPrompt so a UI can show a prompt.
//
// We accept the channels a MUD client wants to RECEIVE: GMCP and MSDP (structured data the UI
// renders), MXP (markup — we accept the option but render the tags as text for now), MCCP2
// (streaming zlib decompression after the COMPRESS2 marker), and NAWS/TTYPE (we tell the server
// our window size + terminal type when it asks). ECHO: if the server says it WILL ECHO (it will
// echo our input, e.g. a password prompt), we note local-echo-off so the UI can stop echoing input.
//
// Determinism: the protocol logic uses no Date.now()/Math.random(); the bytes/lines a given input
// produces are a pure function of the input. Zero deps beyond node built-ins and tab's constants.
//
//   const t = clientTelnet({ write, naws, ttype })
//   t.feed(bytes)             -> push raw server bytes through the input machine
//   t.onLine(cb)              -> cb(line) per COMPLETE input line (IAC-stripped, CR/LF handled)
//   t.onPrompt(cb)            -> cb(text) when the server marks a prompt (GA/EOR) mid-line
//   t.onGMCP(cb)              -> cb(pkg, data) per GMCP subnegotiation (data = parsed JSON)
//   t.onMSDP(cb)              -> cb(obj) per MSDP subnegotiation
//   t.onNegotiate(cb)         -> cb(supports) whenever a negotiation changes the supports view
//   t.send(text)              -> wire bytes for game text (IAC-escaped, CRLF-normalized)
//   t.sendLine(text)          -> wire bytes for one game line (CRLF-terminated)
//   t.sendGMCP(pkg, data)     -> IAC SB GMCP "<pkg> <json>" IAC SE (e.g. Core.Hello on connect)
//   t.supports                -> negotiated options plus compressionActive and localEcho
//
// `write(bytes)` is the byte sink the codec emits negotiation/output through; the carrier supplies
// it (a socket write, or a test collector). Everything else is pure over the fed bytes.

import {
  IAC, DONT, DO, WONT, WILL, SB, SE,
  COMPRESS2, MXP, GMCP, MSDP, ECHO, SGA, EOR, TTYPE, NAWS, CHARSET,
  bytesOf, escapeIAC, parseMSDP,
} from "@red-cup-engineering/computer-networking-engineering-services-section/telnet";
import { createInflate } from "node:zlib";

// GA (End-of-prompt "Go Ahead", 249) and EOR_MARK (the data-mark partner of the EOR option, 239)
// are prompt markers only a CLIENT watches for; feltos, as the server side, sends them but never
// itself needs to name them, so they are not part of its shared wire alphabet and stay local here.
const GA = 249;
const EOR_MARK = 239;

export {
  IAC, DONT, DO, WONT, WILL, SB, SE, GA, EOR_MARK,
  COMPRESS2, MXP, GMCP, MSDP, ECHO, SGA, EOR, TTYPE, NAWS, CHARSET,
  bytesOf, escapeIAC, parseMSDP,
};

const dec = new TextDecoder("utf8");
export const WHEATSTONE_VERSION = "0.3.0";

// IS/SEND/REQUEST subnegotiation sub-commands (TTYPE/CHARSET use them).
const SEND = 1, IS = 0;

// clientTelnet — the client-perspective telnet codec. Returns the control object documented above.
// opts:
//   write(bytes)  — REQUIRED byte sink for everything the codec emits (negotiation + output).
//   naws          — { width, height } reported on a DO NAWS (default 80×24).
//   ttype         — terminal-type string reported on TTYPE SEND (default "WHEATSTONE").
//   accept        — partial override of which options to accept (advanced); see ACCEPT below.
//   acceptCompression — set false to answer WILL COMPRESS2 with DONT (default true).
//   onError(err)  — optional sink for asynchronous decompression errors.
export function clientTelnet(opts = {}) {
  const write = opts.write || (() => {});
  const naws = opts.naws || { width: 80, height: 24 };
  const ttype = opts.ttype || "WHEATSTONE";

  // The options we, as a client, AGREE to. A server WILL <opt> we DO; a server DO <opt> we WILL.
  // Everything else is refused. MCCP2 can be disabled explicitly for constrained callers.
  const ACCEPT_SERVER_WILL = new Set([
    GMCP, MSDP, MXP, SGA, EOR, ECHO,
    ...(opts.acceptCompression === false ? [] : [COMPRESS2]),
    ...(opts.accept?.serverWill || []),
  ]);
  const ACCEPT_SERVER_DO = new Set([NAWS, TTYPE, SGA, ...(opts.accept?.serverDo || [])]);

  // negotiated-state — the public read-only view a UI consults. `localEcho` true means WE echo the
  // player's typed input (the normal case); a server ECHO flips it false (e.g. a password prompt).
  const supports = {
    gmcp: false, msdp: false, mxp: false, sga: false, eor: false, echo: false,
    compress2: false, compressionActive: false, localEcho: true,
  };

  // --- low-level wire emitters ----------------------------------------------------------------
  const cmd = (verb, option) => write(Buffer.from([IAC, verb, option]));
  function sub(option, payload) {
    const p = Buffer.isBuffer(payload) ? payload : bytesOf(payload ?? "");
    write(Buffer.concat([Buffer.from([IAC, SB, option]), escapeIAC(p), Buffer.from([IAC, SE])]));
  }

  // --- handler registries ---------------------------------------------------------------------
  const lineHandlers = new Set();
  const promptHandlers = new Set();
  const gmcpHandlers = new Set();
  const msdpHandlers = new Set();
  const negotiateHandlers = new Set();
  const emitNegotiate = () => { for (const cb of negotiateHandlers) { try { cb({ ...supports }); } catch { /* */ } } };

  // --- INPUT state machine --------------------------------------------------------------------
  let lineBuf = [];
  let state = "data";       // data | iac | verb | sb-opt | sb | sbiac
  let verb = 0;
  let sbOption = 0;
  let sbBuf = [];
  let inflater = null;

  function flushLine() {
    const line = dec.decode(Buffer.from(lineBuf));
    lineBuf = [];
    for (const cb of lineHandlers) { try { cb(line); } catch { /* a bad handler must not stall input */ } }
  }
  // a prompt mark (GA / EOR) flushes the pending partial line AS A PROMPT (no trailing newline on
  // the wire), so the UI can render it without waiting for a newline that never comes.
  function flushPrompt() {
    if (lineBuf.length === 0) return;
    const text = dec.decode(Buffer.from(lineBuf));
    lineBuf = [];
    for (const cb of promptHandlers) { try { cb(text); } catch { /* */ } }
  }

  // answer a server's WILL — it offers to drive <option>. DO the ones we accept, DONT the rest.
  function onWill(option) {
    if (!ACCEPT_SERVER_WILL.has(option)) { cmd(DONT, option); return; }
    cmd(DO, option);
    if (option === COMPRESS2) { supports.compress2 = true; emitNegotiate(); }
    else if (option === GMCP) { supports.gmcp = true; emitNegotiate(); helloGMCP(); }
    else if (option === MSDP) { supports.msdp = true; emitNegotiate(); }
    else if (option === MXP) { supports.mxp = true; emitNegotiate(); }
    else if (option === SGA) { supports.sga = true; emitNegotiate(); }
    else if (option === EOR) { supports.eor = true; emitNegotiate(); }
    else if (option === ECHO) { supports.echo = true; supports.localEcho = false; emitNegotiate(); }
  }
  // answer a server's WONT — it will not drive <option>. Clear the matching state.
  function onWont(option) {
    if (option === COMPRESS2 && !supports.compressionActive) supports.compress2 = false;
    else if (option === GMCP) supports.gmcp = false;
    else if (option === MSDP) supports.msdp = false;
    else if (option === MXP) supports.mxp = false;
    else if (option === SGA) supports.sga = false;
    else if (option === EOR) supports.eor = false;
    else if (option === ECHO) { supports.echo = false; supports.localEcho = true; }
    else return;
    emitNegotiate();
  }
  // answer a server's DO — it asks US to drive <option>. WILL the ones we accept, WONT the rest.
  function onDo(option) {
    if (!ACCEPT_SERVER_DO.has(option)) { cmd(WONT, option); return; }
    cmd(WILL, option);
    if (option === NAWS) { supports.naws = true; sendNAWS(); }
    else if (option === SGA) { supports.sga = true; }
    else if (option === TTYPE) { supports.ttype = true; }  // server will SB TTYPE SEND; we answer in dispatchSB
  }
  // answer a server's DONT — it asks US not to drive <option>. Clear state.
  function onDont(option) {
    if (option === NAWS) supports.naws = false;
    else if (option === SGA) supports.sga = false;
    else if (option === TTYPE) supports.ttype = false;
  }

  // dispatch a completed SB block (server → client direction).
  function dispatchSB(option, payload) {
    if (option === COMPRESS2) {
      if (supports.compress2 && !supports.compressionActive) beginCompression();
      return;
    }
    if (option === GMCP) {
      const text = dec.decode(Buffer.from(payload));
      const sp = text.indexOf(" ");
      const pkg = sp === -1 ? text : text.slice(0, sp);
      const json = sp === -1 ? "" : text.slice(sp + 1);
      let data = null;
      if (json.trim()) { try { data = JSON.parse(json); } catch { data = json; } }
      for (const cb of gmcpHandlers) { try { cb(pkg, data); } catch { /* */ } }
      return;
    }
    if (option === MSDP) {
      const obj = parseMSDP(payload);
      for (const cb of msdpHandlers) { try { cb(obj); } catch { /* */ } }
      return;
    }
    if (option === TTYPE && payload[0] === SEND) {
      // server asked for our terminal type: answer IAC SB TTYPE IS <name> IAC SE
      sub(TTYPE, Buffer.concat([Buffer.from([IS]), bytesOf(ttype)]));
      return;
    }
    if (option === CHARSET) { /* charset negotiation not driven in this cut */ }
  }

  // Once IAC SB COMPRESS2 IAC SE arrives, every subsequent server byte belongs to one continuous
  // zlib stream. Decompressed bytes re-enter the same telnet state machine, because IAC commands
  // and subnegotiations remain meaningful inside MCCP2.
  function beginCompression() {
    inflater = createInflate();
    supports.compressionActive = true;
    emitNegotiate();
    inflater.on("data", (chunk) => processTelnetBytes(chunk, false));
    inflater.on("error", (error) => {
      supports.compress2 = false;
      supports.compressionActive = false;
      inflater = null;
      emitNegotiate();
      try { opts.onError?.(error); } catch { /* */ }
    });
  }

  function processTelnetBytes(buf, allowCompressionSwitch) {
    for (let i = 0; i < buf.length; i++) {
      const b = buf[i];
      switch (state) {
        case "data":
          if (b === IAC) state = "iac";
          else if (b === 13) { /* CR: defer — LF (or lone CR) ends the line */ }
          else if (b === 10) flushLine();                 // LF ends a line (CRLF and bare LF)
          else lineBuf.push(b);
          break;
        case "iac":
          if (b === IAC) { lineBuf.push(IAC); state = "data"; }                  // IAC IAC → literal 255
          else if (b === WILL || b === WONT || b === DO || b === DONT) { verb = b; state = "verb"; }
          else if (b === SB) state = "sb-opt";
          else if (b === GA || b === EOR_MARK) { flushPrompt(); state = "data"; } // prompt marks
          else state = "data";                                                    // NOP/etc: strip
          break;
        case "verb": {
          const option = b;
          if (verb === WILL) onWill(option);
          else if (verb === WONT) onWont(option);
          else if (verb === DO) onDo(option);
          else if (verb === DONT) onDont(option);
          state = "data";
          break;
        }
        case "sb-opt": sbOption = b; sbBuf = []; state = "sb"; break;
        case "sb":
          if (b === IAC) state = "sbiac";
          else sbBuf.push(b);
          break;
        case "sbiac":
          if (b === IAC) { sbBuf.push(IAC); state = "sb"; }                       // escaped 255 inside SB
          else if (b === SE) { dispatchSB(sbOption, sbBuf); sbBuf = []; state = "data"; }
          else state = "data";                                                    // malformed: bail
          break;
      }
      // The marker and the first compressed bytes commonly share one socket chunk. Hand the
      // untouched suffix directly to zlib; interpreting even one of those bytes as telnet would
      // corrupt the stream.
      if (allowCompressionSwitch && supports.compressionActive && i + 1 < buf.length) {
        inflater.write(buf.subarray(i + 1));
        return;
      }
    }
  }

  // feed — push raw server bytes through negotiation, then zlib once MCCP2 is active.
  function feed(chunk) {
    const buf = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    if (supports.compressionActive) inflater.write(buf);
    else processTelnetBytes(buf, true);
  }

  function end() {
    try { inflater?.destroy(); } catch { /* */ }
    inflater = null;
    supports.compressionActive = false;
  }

  // --- the things a client proactively sends --------------------------------------------------
  // sendNAWS — IAC SB NAWS <w-hi> <w-lo> <h-hi> <h-lo> IAC SE (each dimension a 16-bit big-endian).
  function sendNAWS(w = naws.width, h = naws.height) {
    const payload = Buffer.from([(w >> 8) & 255, w & 255, (h >> 8) & 255, h & 255]);
    sub(NAWS, payload);
  }
  // helloGMCP — on GMCP up, send Core.Hello + Core.Supports.Set (the conventional client handshake).
  function helloGMCP() {
    sendGMCP("Core.Hello", { client: "wheatstone", version: WHEATSTONE_VERSION });
    sendGMCP("Core.Supports.Set", ["Char 1", "Room 1", "Comm 1"]);
  }

  // --- OUTPUT (player → server) ---------------------------------------------------------------
  function send(text) {
    const s = String(text).replace(/\r?\n/g, "\r\n");
    write(escapeIAC(bytesOf(s)));
  }
  function sendLine(text) {
    const s = String(text).replace(/\r?\n/g, "\r\n");
    write(escapeIAC(bytesOf(s + "\r\n")));
  }
  function sendGMCP(pkg, data) {
    if (!supports.gmcp) return;
    const body = data === undefined ? String(pkg) : `${pkg} ${JSON.stringify(data)}`;
    sub(GMCP, body);
  }

  // --- public surface -------------------------------------------------------------------------
  function onLine(cb) { lineHandlers.add(cb); return () => lineHandlers.delete(cb); }
  function onPrompt(cb) { promptHandlers.add(cb); return () => promptHandlers.delete(cb); }
  function onGMCP(cb) { gmcpHandlers.add(cb); return () => gmcpHandlers.delete(cb); }
  function onMSDP(cb) { msdpHandlers.add(cb); return () => msdpHandlers.delete(cb); }
  function onNegotiate(cb) { negotiateHandlers.add(cb); return () => negotiateHandlers.delete(cb); }

  return {
    feed,
    onLine, onPrompt, onGMCP, onMSDP, onNegotiate,
    send, sendLine, sendGMCP, sendNAWS, end,
    supports,
  };
}

export default clientTelnet;
