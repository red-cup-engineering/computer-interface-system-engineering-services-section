#!/usr/bin/env node
import { fileURLToPath } from "node:url";
import { listKnowledgeVaultAgentEndpoints, runKnowledgeVaultAgent, streamKnowledgeVaultAgent } from "../agent.mjs";
import type { Conversation } from "@emsenn/organizing-with-llm-agents/algebra";

const VALUE_FLAGS = new Set(["--endpoint", "--model", "--system", "--session", "--prompt", "--conversation-json"]);
const BOOL_FLAGS = new Set(["--json", "--stream", "--list", "--help", "-h"]);

type ParsedArgs = Readonly<{
  values: Readonly<Record<string, string>>;
  bools: ReadonlySet<string>;
  positionals: readonly string[];
}>;

function usage(): never {
  process.stderr.write([
    "usage: obsidian-knowledge-agent [--endpoint id] [--model m] [--system t]",
    "                                [--session id] [--conversation-json json] [--json | --stream]",
    "                                (--prompt p | -- prompt... | stdin)",
    "       obsidian-knowledge-agent --list",
    "",
  ].join("\n"));
  process.exit(2);
}

function parse(argv: readonly string[]): ParsedArgs {
  const values: Record<string, string> = {};
  const bools = new Set<string>();
  const positionals: string[] = [];
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === undefined) continue;
    if (arg === "--") {
      positionals.push(...argv.slice(i + 1));
      break;
    }
    if (BOOL_FLAGS.has(arg)) {
      bools.add(arg);
      continue;
    }
    if (VALUE_FLAGS.has(arg)) {
      const value = argv[i + 1];
      if (value === undefined) usage();
      values[arg] = value;
      i += 1;
      continue;
    }
    if (arg.startsWith("-")) usage();
    positionals.push(arg);
  }
  return Object.freeze({ values, bools, positionals });
}

async function readStdin(): Promise<string> {
  if (process.stdin.isTTY) return "";
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks).toString("utf8");
}

async function main(): Promise<number> {
  const parsed = parse(process.argv.slice(2));
  if (parsed.bools.has("--help") || parsed.bools.has("-h")) usage();
  if (parsed.bools.has("--list")) {
    process.stdout.write(`${listKnowledgeVaultAgentEndpoints()}\n`);
    return 0;
  }
  const prompt = parsed.values["--prompt"] ?? (parsed.positionals.length > 0 ? parsed.positionals.join(" ") : await readStdin());
  const conversation = parseConversation(parsed.values["--conversation-json"]);
  if (parsed.bools.has("--stream") && parsed.bools.has("--json")) usage();
  const baseOptions = {
    prompt,
    ...(parsed.values["--endpoint"] === undefined ? {} : { endpoint: parsed.values["--endpoint"] }),
    ...(parsed.values["--model"] === undefined ? {} : { model: parsed.values["--model"] }),
    ...(parsed.values["--system"] === undefined ? {} : { system: parsed.values["--system"] }),
    ...(parsed.values["--session"] === undefined ? {} : { session: parsed.values["--session"] }),
    ...(conversation === undefined ? {} : { conversation }),
  };
  const result = parsed.bools.has("--stream")
    ? await streamKnowledgeVaultAgent({
      ...baseOptions,
      onToken: (token) => process.stdout.write(token),
    })
    : await runKnowledgeVaultAgent({
      ...baseOptions,
      json: parsed.bools.has("--json"),
    });
  if (parsed.bools.has("--stream") && result.code === 0 && !result.stdout.endsWith("\n")) process.stdout.write("\n");
  else if (result.stdout !== "" && !parsed.bools.has("--stream")) process.stdout.write(result.stdout);
  if (result.stderr !== "") process.stderr.write(result.stderr);
  return result.code;
}

function parseConversation(input: string | undefined): Conversation | undefined {
  if (input === undefined || input.trim() === "") return undefined;
  const parsed: unknown = JSON.parse(input);
  if (!Array.isArray(parsed)) throw new Error("--conversation-json must be an array");
  return Object.freeze(parsed.map((item) => {
    if (item === null || typeof item !== "object" || Array.isArray(item)) throw new Error("--conversation-json messages must be objects");
    const record = item as Record<string, unknown>;
    const role = record["role"];
    const content = record["content"];
    if ((role !== "system" && role !== "user" && role !== "assistant" && role !== "tool") || typeof content !== "string") {
      throw new Error("--conversation-json messages require role and content");
    }
    return Object.freeze({
      role,
      content,
      ...(typeof record["name"] === "string" ? { name: record["name"] } : {}),
      ...(typeof record["toolCallId"] === "string" ? { toolCallId: record["toolCallId"] } : {}),
    });
  }));
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main()
    .then((code) => process.exit(code))
    .catch((error) => {
      process.stderr.write(`obsidian-knowledge-agent: ${error instanceof Error ? error.message : String(error)}\n`);
      process.exit(1);
    });
}
