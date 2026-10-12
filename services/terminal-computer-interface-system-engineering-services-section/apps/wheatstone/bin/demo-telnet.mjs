#!/usr/bin/env node
// demo-telnet — drive wheatstone's telnet CLIENT state machine (src/telnet.mjs) against a scripted
// fake server (bin/lib/fake-mud-server.mjs) over a REAL local TCP socket, and print the exact IAC
// negotiation transcript both sides exchanged. No live MUD, no @561-group/tab, no interactive
// terminal required — this is the headless, fully-real proof that the client codec negotiates
// (WILL/DO GMCP), sends the Core.Hello handshake, exchanges a line of game text, and receives a
// server-pushed GMCP update, byte-for-byte, over an actual socket.
//
// Run: node bin/demo-telnet.mjs

import { clientTelnet } from "../src/telnet.mjs";
import { startFakeServer } from "./lib/fake-mud-server.mjs";
import { annotate } from "./lib/annotate-telnet.mjs";

async function main() {
  const transcript = [];
  const { port, close } = await startFakeServer({
    onWrite: (buf) => { for (const line of annotate(buf)) transcript.push(`  S→C  ${line}`); },
    onRead: (buf) => { for (const line of annotate(buf)) transcript.push(`  C→S  ${line}`); },
  });

  const receivedLines = [];
  const gmcpUpdates = [];
  const { createConnection } = await import("node:net");
  const socket = createConnection({ host: "127.0.0.1", port });

  const tel = clientTelnet({
    write: (bytes) => socket.write(bytes),
    ttype: "WHEATSTONE",
  });
  tel.onLine((line) => receivedLines.push(line));
  tel.onGMCP((pkg, data) => gmcpUpdates.push({ pkg, data }));
  socket.on("data", (chunk) => tel.feed(chunk));

  await new Promise((resolve, reject) => {
    socket.on("connect", resolve);
    socket.on("error", reject);
  });

  await waitFor(() => receivedLines.includes("Connected to the test server."));
  socket.write(Buffer.from("look\r\n"));
  await waitFor(() => receivedLines.includes("You see the test room."));
  await waitFor(() => gmcpUpdates.length > 0);

  socket.destroy();
  await close();

  console.log("── wheatstone demo-telnet: IAC negotiation transcript (scripted fake server, real socket) ──\n");
  for (const line of transcript) console.log(line);

  console.log("\n── decoded results ──");
  console.log(`lines received:  ${JSON.stringify(receivedLines)}`);
  console.log(`gmcp received:   ${JSON.stringify(gmcpUpdates)}`);
  console.log(`client.supports: ${JSON.stringify(tel.supports)}`);
  console.log(`\n(GMCP negotiated up: ${tel.supports.gmcp}. The server pushed Char.Vitals only after`);
  console.log(` OBSERVING the client's "IAC DO GMCP" on the wire — no timer, see bin/lib/fake-mud-server.mjs.)`);
}

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

main().catch((err) => { console.error(err); process.exit(1); });
