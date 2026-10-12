// world — the pluggable CARRIER seam. A "world" is the thing wheatstone talks to. It is, by
// design, an interface — NOT a telnet socket. Today the only carrier is telnet (telnetWorld
// below); tomorrow a local/SSE carrier can slot in WITHOUT the TUI changing, because the TUI only
// ever speaks this interface. The motivating case: once SWARM exposes a MUD-like face, "talking to
// your agents" is just wheatstone connecting to one more world — a swarmWorld carrier with the
// same shape, no telnet socket underneath.
//
// A world is:
//   connect()                 -> begin the session (open the socket / SSE / local pipe). Returns
//                                a promise that resolves when connected (or rejects on failure).
//   send(text)                -> send one player command/line to the world.
//   onLine(cb)                -> subscribe to output lines (cb(line)). Returns an unsubscribe.
//   onGMCP(cb)                -> subscribe to GMCP/structured data (cb(pkg, data)). Unsubscribe.
//   onMSDP(cb)                -> subscribe to MSDP structured data (cb(obj)). Optional.
//   onPrompt(cb)              -> subscribe to prompt marks (cb(text)). Optional.
//   onStatus(cb)              -> subscribe to carrier status changes (cb({state, detail})).
//   close()                   -> end the session.
//   supports                  -> a read-only view of negotiated capabilities (telnet) or {} .
//
// Every carrier returns this shape. The TUI (app.mjs) wires its panes to onLine/onGMCP/onMSDP and
// its input to send — so a new carrier is a drop-in.

import { createConnection } from "node:net";
import { clientTelnet } from "./telnet.mjs";

// telnetWorld({ host, port, naws, ttype }) — the telnet/TCP carrier. It opens a node:net socket,
// runs the CLIENT telnet codec over it (telnet.mjs), and exposes the world interface. Line and
// GMCP/MSDP handlers come straight off the codec; send() goes through the codec's IAC-escaping
// sendLine; supports is the codec's negotiated view.
export function telnetWorld(opts = {}) {
  const host = opts.host || "127.0.0.1";
  const port = opts.port | 0;
  const connectFn = opts.createConnection || createConnection; // injectable for tests

  let socket = null;
  let tel = null;
  const statusHandlers = new Set();
  const emitStatus = (state, detail) => { for (const cb of statusHandlers) { try { cb({ state, detail }); } catch { /* */ } } };

  // The codec is created up front so onLine/onGMCP can be registered BEFORE connect (the TUI wires
  // handlers, then connects). Its write sink targets the socket once connected; before that, bytes
  // are dropped (nothing is sent before connect anyway).
  tel = clientTelnet({
    write: (bytes) => { try { socket?.write(bytes); } catch { /* dead socket */ } },
    naws: opts.naws,
    ttype: opts.ttype,
    acceptCompression: opts.acceptCompression,
    onError: (err) => emitStatus("error", { message: err?.message || String(err), protocol: "mccp2" }),
  });

  function connect() {
    return new Promise((resolve, reject) => {
      emitStatus("connecting", { host, port });
      socket = connectFn({ host, port }, () => {
        emitStatus("connected", { host, port });
        resolve();
      });
      socket.on("data", (chunk) => tel.feed(chunk));
      socket.on("error", (err) => { emitStatus("error", { message: err?.message || String(err) }); reject(err); });
      socket.on("close", () => emitStatus("closed", { host, port }));
    });
  }

  function send(text) { tel.sendLine(text); }
  function close() {
    tel.end();
    try { socket?.destroy?.(); } catch { /* gone */ }
    emitStatus("closed", { host, port });
  }

  return {
    kind: "telnet",
    connect, send, close,
    onLine: (cb) => tel.onLine(cb),
    onPrompt: (cb) => tel.onPrompt(cb),
    onGMCP: (cb) => tel.onGMCP(cb),
    onMSDP: (cb) => tel.onMSDP(cb),
    onNegotiate: (cb) => tel.onNegotiate(cb),
    onStatus: (cb) => { statusHandlers.add(cb); return () => statusHandlers.delete(cb); },
    get supports() { return tel.supports; },
    _telnet: tel, // exposed for tests/drivers that want to push bytes directly
  };
}

// localWorld({ onConnect, onSend }) — a non-telnet carrier scaffold: a world backed by plain
// callbacks instead of a socket. This is the shape the swarm-as-MUD carrier will take — a world
// whose onLine fires when the swarm emits a line, whose onGMCP fires when the swarm emits
// structured state, and whose send() hands a command to the swarm. It carries NO telnet wire; the
// "world is pluggable" promise is exactly that this implements the same interface as telnetWorld.
// Provide:
//   onConnect()               -> () => Promise|void, called on connect()
//   onSend(text, emit)        -> handle a player command; `emit` is { line, gmcp, msdp, prompt }.
//   onClose()                 -> optional teardown.
// The carrier hands you `emit` so your backend can push output lines and structured data UP into
// the same panes a telnet world feeds. Synchronous and dependency-free; a real swarm carrier would
// wire onSend to a swarm RPC and call emit.line / emit.gmcp from the swarm's event stream.
export function localWorld(spec = {}) {
  const lineHandlers = new Set();
  const gmcpHandlers = new Set();
  const msdpHandlers = new Set();
  const promptHandlers = new Set();
  const statusHandlers = new Set();
  const fan = (set, ...args) => { for (const cb of set) { try { cb(...args); } catch { /* */ } } };
  const emit = {
    line: (l) => fan(lineHandlers, l),
    gmcp: (pkg, data) => fan(gmcpHandlers, pkg, data),
    msdp: (obj) => fan(msdpHandlers, obj),
    prompt: (t) => fan(promptHandlers, t),
  };
  const emitStatus = (state, detail) => fan(statusHandlers, { state, detail });

  async function connect() {
    emitStatus("connecting", {});
    await spec.onConnect?.(emit);
    emitStatus("connected", {});
  }
  function send(text) { spec.onSend?.(text, emit); }
  function close() { try { spec.onClose?.(); } catch { /* */ } emitStatus("closed", {}); }

  return {
    kind: spec.kind || "local",
    connect, send, close,
    onLine: (cb) => { lineHandlers.add(cb); return () => lineHandlers.delete(cb); },
    onGMCP: (cb) => { gmcpHandlers.add(cb); return () => gmcpHandlers.delete(cb); },
    onMSDP: (cb) => { msdpHandlers.add(cb); return () => msdpHandlers.delete(cb); },
    onPrompt: (cb) => { promptHandlers.add(cb); return () => promptHandlers.delete(cb); },
    onNegotiate: () => () => {},
    onStatus: (cb) => { statusHandlers.add(cb); return () => statusHandlers.delete(cb); },
    supports: {},
    emit, // exposed so a driver/backend can push without going through send()
  };
}
