#!/usr/bin/env node
/**
 * tui-render — compose a stream of (possibly ANSI-styled) lines into a fixed
 * terminal viewport and emit the rendered plain text.
 *
 * The canonical buffer operation of @emsenn/computing-with-terminal made pipeable: reads text
 * (stdin, or a path positional), parses each line's ANSI to styled segments,
 * draws them into a `CellBuffer` of `--width` x `--height`, and writes the
 * buffer's flattened text to stdout — every row padded to width, clipped to the
 * viewport. This is the artifact you capture when you want to see what a stream
 * looks like ON a terminal of a known size, as data.
 *
 * Text is DATA: this always exits 0 when a render was produced; non-zero is
 * reserved for operational failure.
 *
 *   cat banner.ansi | tui-render --width=40 --height=10
 *   tui-render --width=80 log.txt
 *
 * Parameters: --width=N (default 80), --height=N (default the line count,
 *             clamped to >=1), --trim (drop trailing all-blank rows).
 */
import { fileURLToPath } from "node:url";
import { readFile } from "node:fs/promises";
import { parseAnsi } from "@emsenn/computing-with-terminal/ansi";
import { CellBuffer } from "@emsenn/computing-with-terminal/buffer";
import { parseArgs, readStdin, lines, intFlag, type Args } from "@emsenn/computing-with-cli";

async function main(argv: readonly string[]): Promise<number> {
  const args: Args = parseArgs(argv);
  const path = args.positionals[0];
  const width = intFlag(args, "width", 80);

  const text = path !== undefined ? await readFile(path, "utf8") : await readStdin();
  const input = lines(text);
  const height = intFlag(args, "height", Math.max(1, input.length));

  const buf = new CellBuffer(width, height);
  for (let row = 0; row < height; row += 1) {
    const line = input[row];
    if (line === undefined) break;
    buf.drawSegments(row, 0, width, parseAnsi(line).segments);
  }

  let out = buf.text();
  if (args.flags.has("trim")) out = out.replace(/(?:\n[ ]*)+$/u, "");
  process.stdout.write(out + "\n");
  return 0;
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main(process.argv.slice(2))
    .then((code) => process.exit(code))
    .catch((error: unknown) => {
      process.stderr.write(`tui-render: ${error instanceof Error ? error.message : String(error)}\n`);
      process.exit(1);
    });
}
