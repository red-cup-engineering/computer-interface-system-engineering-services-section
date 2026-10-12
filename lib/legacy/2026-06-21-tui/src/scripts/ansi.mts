#!/usr/bin/env node
/**
 * tui-ansi — the ANSI filter over a stream of terminal text.
 *
 * A pure filter over @emsenn/computing-with-terminal/ansi: reads text (stdin, or a path
 * positional), and per `--mode` either
 *
 *   - strips ANSI escapes to plain text (`--mode=strip`, the default) — the
 *     pipeable artifact for capturing styled output as data;
 *   - decodes each line to styled SEGMENTS as JSONL (`--mode=parse`), one
 *     `{segments, style}` record per input line;
 *   - reports which lines carry ANSI (`--mode=detect`), one `{ansi, line}` per
 *     line.
 *
 * Text is DATA: this always exits 0 when output was produced; non-zero is
 * reserved for operational failure. `--fail-on=ansi` opts into gating (exit 1
 * when any line carried ANSI — e.g. asserting a stream is already clean).
 *
 *   cat styled.log | tui-ansi              # strip to plain text
 *   tui-ansi --mode=parse styled.log       # decode to segment JSONL
 *   make 2>&1 | tui-ansi --mode=detect
 *
 * Parameters: --mode=strip|parse|detect (default strip),
 *             --fail-on=ansi (exit 1 when any line carried ANSI).
 */
import { fileURLToPath } from "node:url";
import { readFile } from "node:fs/promises";
import { hasAnsi, parseAnsi, stripAnsi } from "@emsenn/computing-with-terminal/ansi";
import { parseArgs, readStdin, lines, type Args } from "@emsenn/computing-with-cli";

async function main(argv: readonly string[]): Promise<number> {
  const args: Args = parseArgs(argv);
  const mode = args.flags.get("mode") ?? "strip";
  const failOn = args.flags.get("fail-on");
  const path = args.positionals[0];

  const text = path !== undefined ? await readFile(path, "utf8") : await readStdin();
  const input = lines(text);
  let anyAnsi = false;

  switch (mode) {
    case "strip":
      process.stdout.write(input.map((line) => stripAnsi(line)).join("\n") + (input.length ? "\n" : ""));
      anyAnsi = input.some((line) => hasAnsi(line));
      break;
    case "parse":
      for (const line of input) {
        if (hasAnsi(line)) anyAnsi = true;
        const parsed = parseAnsi(line);
        process.stdout.write(JSON.stringify({ segments: parsed.segments, style: parsed.style }) + "\n");
      }
      break;
    case "detect":
      for (const line of input) {
        const ansi = hasAnsi(line);
        if (ansi) anyAnsi = true;
        process.stdout.write(JSON.stringify({ ansi, line: stripAnsi(line) }) + "\n");
      }
      break;
    default:
      throw new Error(`unknown --mode=${mode} (expected strip, parse, or detect)`);
  }

  if (failOn === "ansi" && anyAnsi) return 1;
  return 0;
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main(process.argv.slice(2))
    .then((code) => process.exit(code))
    .catch((error: unknown) => {
      process.stderr.write(`tui-ansi: ${error instanceof Error ? error.message : String(error)}\n`);
      process.exit(1);
    });
}
