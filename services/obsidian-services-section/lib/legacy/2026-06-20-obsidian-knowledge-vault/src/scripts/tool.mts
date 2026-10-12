#!/usr/bin/env node
import path from "node:path";
import { fileURLToPath } from "node:url";
import { runKnowledgeVaultAction } from "../tooling.mjs";

async function readStdin(): Promise<string> {
  let text = "";
  process.stdin.setEncoding("utf8");
  for await (const chunk of process.stdin) text += chunk;
  return text;
}

async function main(): Promise<number> {
  const dataRoot = process.env["ORGANIZING_KNOWLEDGE_VAULT_DATA"];
  const result = runKnowledgeVaultAction({
    argv: resolvePathOptions(process.argv.slice(2)),
    stdin: await readStdin(),
    ...(dataRoot === undefined ? {} : { dataRoot }),
  });
  if (result.stdout !== "") process.stdout.write(result.stdout);
  if (result.stderr !== "") process.stderr.write(result.stderr);
  return result.code;
}

function resolvePathOptions(argv: readonly string[]): string[] {
  const base = process.env["INIT_CWD"] ?? process.cwd();
  return argv.map((arg, index) => {
    const previous = argv[index - 1];
    if (previous !== "--path" || arg.trim() === "" || path.isAbsolute(arg)) return arg;
    return path.resolve(base, arg);
  });
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main()
    .then((code) => process.exit(code))
    .catch((error) => {
      process.stderr.write(`obsidian-knowledge-vault: ${error instanceof Error ? error.message : String(error)}\n`);
      process.exit(1);
    });
}
