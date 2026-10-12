// annotate-telnet — decode a raw telnet byte stream into human-readable transcript lines: one per
// IAC command/negotiation/subnegotiation, one per run of plain text between them. Shared by
// bin/demo-telnet.mjs (prints it) and tests/prove-telnet-transcript.mjs (asserts on it exactly) so
// the demo and the byte-proof read the SAME bytes the same way — no drift between what a human sees
// running the demo and what the test locks in.

import {
  IAC, WILL, WONT, DO, DONT, SB, SE, GA, EOR_MARK,
  GMCP, MSDP, MXP, ECHO, SGA, EOR, TTYPE, NAWS, CHARSET, COMPRESS2,
} from "../../src/telnet.mjs";

const VERB_NAME = { [WILL]: "WILL", [WONT]: "WONT", [DO]: "DO", [DONT]: "DONT" };
const OPTION_NAME = {
  [GMCP]: "GMCP", [MSDP]: "MSDP", [MXP]: "MXP", [ECHO]: "ECHO", [SGA]: "SGA",
  [EOR]: "EOR", [TTYPE]: "TTYPE", [NAWS]: "NAWS", [CHARSET]: "CHARSET", [COMPRESS2]: "COMPRESS2",
};
const dec = new TextDecoder("utf8");

// annotate(buf) -> string[] — see module header.
export function annotate(buf) {
  const out = [];
  let i = 0;
  let textStart = -1;
  const flushText = (end) => {
    if (textStart < 0) return;
    const text = dec.decode(buf.subarray(textStart, end));
    if (text.length) out.push(`TEXT ${JSON.stringify(text)}`);
    textStart = -1;
  };
  while (i < buf.length) {
    const b = buf[i];
    if (b !== IAC) { if (textStart < 0) textStart = i; i++; continue; }
    flushText(i);
    const verb = buf[i + 1];
    if (verb === WILL || verb === WONT || verb === DO || verb === DONT) {
      const opt = buf[i + 2];
      out.push(`IAC ${VERB_NAME[verb]} ${OPTION_NAME[opt] ?? opt}`);
      i += 3;
    } else if (verb === SB) {
      let j = i + 2;
      const opt = buf[j]; j++;
      const payloadStart = j;
      while (j < buf.length - 1 && !(buf[j] === IAC && buf[j + 1] === SE)) j++;
      const payload = dec.decode(buf.subarray(payloadStart, j));
      out.push(`IAC SB ${OPTION_NAME[opt] ?? opt} ${JSON.stringify(payload)} IAC SE`);
      i = j + 2;
    } else if (verb === GA) { out.push("IAC GA (prompt)"); i += 2; }
    else if (verb === EOR_MARK) { out.push("IAC EOR (prompt)"); i += 2; }
    else if (verb === IAC) { if (textStart < 0) textStart = i; i += 2; } // escaped literal 255
    else { out.push(`IAC <0x${verb.toString(16)}>`); i += 2; }
  }
  flushText(buf.length);
  return out;
}
