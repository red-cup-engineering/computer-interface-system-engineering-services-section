#!/usr/bin/env node
import { fileURLToPath } from "node:url";
import { createKnowledgeVaultApplication, resolveCorpusPath } from "../app.mjs";

type ServeArgs = Readonly<{
  port: number;
  path?: string;
}>;

async function main(): Promise<number> {
  const args = parseArgs(process.argv.slice(2));
  const corpusPath = resolveCorpusPath(args.path);
  const application = createKnowledgeVaultApplication({
    path: corpusPath,
    ...(process.env["ORGANIZING_KNOWLEDGE_VAULT_DATA"] === undefined ? {} : { dataRoot: process.env["ORGANIZING_KNOWLEDGE_VAULT_DATA"] }),
  });
  const server = application.server();
  server.listen(args.port, () => {
    process.stdout.write(`obsidian-knowledge-vault-serve: ${JSON.stringify(corpusPath)} on http://localhost:${args.port}/\n`);
  });
  return 0;
}

function parseArgs(argv: readonly string[]): ServeArgs {
  let port = Number(process.env["PORT"] ?? 8790);
  let vaultPath: string | undefined;
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]!;
    if (arg === "--port") port = Number(argv[index + 1] ?? port);
    else if (arg.startsWith("--port=")) port = Number(arg.slice("--port=".length));
    else if (arg === "--path") vaultPath = argv[index + 1];
    else if (arg.startsWith("--path=")) vaultPath = arg.slice("--path=".length);
  }
  if (!Number.isFinite(port) || port <= 0) port = 8790;
  return { port: Math.floor(port), ...(vaultPath === undefined ? {} : { path: vaultPath }) };
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    process.stderr.write(`obsidian-knowledge-vault-serve: ${error instanceof Error ? error.message : String(error)}\n`);
    process.exit(1);
  });
}
