// prove-raster-demo-stream — end-to-end proof over ACTUAL BYTES: spawn the raster demo as a
// child process with DALESKE_ENCODER=sixel forced, stdout PIPED (not a tty), and decode the raw
// stream that comes back with a tiny hand-written sixel parser (no external deps — this file IS the
// parser). Proves: (1) the stream contains a well-formed DCS..ST sixel envelope, (2) decoding the
// band/run structure of that envelope recovers the exact pixel dimensions of the --pattern test
// image (256x96, chosen in scripts/raster-demo.mjs), matching what encodeImage was actually asked to draw.

import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { ok, eq, done } from "./_harness.mjs";

const ESC = "\x1b";
const here = path.dirname(fileURLToPath(import.meta.url));
const bin = path.join(here, "..", "scripts", "raster-demo.mjs");

// run the real CLI, piped (spawnSync's stdout is always a pipe, never a tty) — this is exactly the
// "forced encoder, piped" shape the byte-proof calls for.
const result = spawnSync(process.execPath, [bin, "--pattern"], {
  env: { ...process.env, DALESKE_ENCODER: "sixel" },
  encoding: "utf8",
});
ok(result.status === 0, "raster demo --pattern (sixel forced) exits 0");
const stdout = result.stdout;

// === locate the DCS..ST envelope in the raw bytes =============================================
const dcsStart = stdout.indexOf(`${ESC}Pq`);
ok(dcsStart !== -1, "the piped stream contains the sixel DCS introducer (ESC P q)");
const stEnd = stdout.indexOf(`${ESC}\\`, dcsStart);
ok(stEnd !== -1, "the envelope closes with ST (ESC \\)");

const envelope = stdout.slice(dcsStart, stEnd + 2);
ok(envelope.startsWith(`${ESC}Pq`), "the envelope's first bytes ARE the DCS introducer, not just present somewhere");
ok(envelope.endsWith(`${ESC}\\`), "the envelope's last bytes are ST");

// === tiny sixel-header parser (hand-written, zero deps) ========================================
// body = everything between "ESC P q" and "ESC \". It is: palette defs `#<i>;2;<r>;<g>;<b>`
// (no '-' or '$' in them), then one or more BANDS. A band is one or more color-runs `#<ci><run>`
// separated by `$` (palette re-select / carriage return), and bands are separated by `-` (line feed).
function decodeSixelDims(envelopeStr) {
  let body = envelopeStr.slice(2, -2); // strip "ESC P q" ... wait, strip DCS(2 bytes: ESC P) + "q"(1) and ST(2)
  // envelopeStr = ESC + "P" + "q" + <data> + ESC + "\\"  -> strip 3 leading, 2 trailing
  body = envelopeStr.slice(3, -2);

  // strip leading palette definitions: repeated "#<digits>;2;<digits>;<digits>;<digits>"
  const paletteDefRe = /^#\d+;2;\d+;\d+;\d+/;
  while (paletteDefRe.test(body)) body = body.replace(paletteDefRe, "");

  // now body is pure band data. Split into bands on '-'; drop any trailing empty segment.
  const bands = body.split("-").filter((b) => b.length > 0);

  // width: expand the RLE of the first color-run in the first band.
  const firstBand = bands[0];
  const firstRun = firstBand.split("$")[0].replace(/^#\d+/, ""); // strip the "#<ci>" selector
  let width = 0;
  let i = 0;
  while (i < firstRun.length) {
    if (firstRun[i] === "!") {
      const m = /^!(\d+)./.exec(firstRun.slice(i));
      width += Number(m[1]);
      i += m[0].length;
    } else {
      width += 1;
      i += 1;
    }
  }

  // height: each band encodes exactly 6 pixel-rows (a sixel "band"); the pattern's height (96) is
  // an exact multiple of 6, so band-count * 6 recovers it precisely.
  const height = bands.length * 6;

  return { width, height, bandCount: bands.length };
}

const dims = decodeSixelDims(envelope);
eq(dims.width, 256, "decoded sixel width matches the --pattern image's actual width (256px)");
eq(dims.height, 96, "decoded sixel height (bandCount*6) matches the --pattern image's actual height (96px)");
eq(dims.bandCount, 16, "96px / 6 rows-per-band = 16 bands, exactly as decoded");

// the caption line (always printed, ahead of the raster) names the same dimensions independently —
// cross-check against the decoded stream so this isn't just trusting the caption's own text.
ok(stdout.includes("frame: 256x96px"), "the caption independently reports the same 256x96 frame size");

done("prove-raster-demo-stream");
