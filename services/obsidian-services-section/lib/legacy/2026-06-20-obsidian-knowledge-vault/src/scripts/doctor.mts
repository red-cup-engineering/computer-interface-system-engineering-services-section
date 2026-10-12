#!/usr/bin/env node
import { fileURLToPath } from "node:url";
import {
  knowledgeVaultDoctor,
  renderKnowledgeVaultDoctorMarkdown,
} from "../doctor.mjs";

type DoctorCliOptions = Readonly<{
  vaultRoot?: string;
  markdown: boolean;
  obsidianExecutable?: string;
}>;

async function main(): Promise<number> {
  const options = parseArgs(process.argv.slice(2));
  const report = knowledgeVaultDoctor({
    ...(options.vaultRoot === undefined ? {} : { vaultRoot: options.vaultRoot }),
    ...(options.obsidianExecutable === undefined ? {} : { obsidianExecutable: options.obsidianExecutable }),
  });
  process.stdout.write(options.markdown
    ? renderKnowledgeVaultDoctorMarkdown(report)
    : `${JSON.stringify(report, null, 2)}\n`);
  return report.probes.every((probe) => probe.code === 0) ? 0 : 1;
}

function parseArgs(argv: readonly string[]): DoctorCliOptions {
  let vaultRoot: string | undefined;
  let obsidianExecutable: string | undefined;
  let markdown = false;
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--markdown") {
      markdown = true;
      continue;
    }
    if (arg === "--obsidian") {
      obsidianExecutable = argv[index + 1];
      index += 1;
      continue;
    }
    if (arg === "--path" || arg === "--vault" || arg === "--vault-root") {
      vaultRoot = argv[index + 1];
      index += 1;
      continue;
    }
    if (arg !== undefined && !arg.startsWith("-") && vaultRoot === undefined) vaultRoot = arg;
  }
  return Object.freeze({
    ...(vaultRoot === undefined ? {} : { vaultRoot }),
    ...(obsidianExecutable === undefined ? {} : { obsidianExecutable }),
    markdown,
  });
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main()
    .then((code) => process.exit(code))
    .catch((error) => {
      process.stderr.write(`obsidian-knowledge-doctor: ${error instanceof Error ? error.message : String(error)}\n`);
      process.exit(1);
    });
}
