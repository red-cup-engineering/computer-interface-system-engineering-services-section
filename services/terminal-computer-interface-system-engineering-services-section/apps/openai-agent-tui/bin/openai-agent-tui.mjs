#!/usr/bin/env node

import { runOpenAiAgentTui } from "../src/app.mjs";

const argv = process.argv.slice(2);

function usage(code = 0) {
  const stream = code === 0 ? process.stdout : process.stderr;
  stream.write([
    "usage: openai-agent-tui [--provider ID] [--model ID] [--system TEXT] [--session NAME] [--max-output-tokens N] [--resource-root PATH]",
    "",
    "Starts one persistent conversation over the selected provider catalog entry.",
    "Provider policy, credentials, rate limits, and exchange records are handled by @red-cup-engineering/computer-inference-engine.",
    "The default provider is openrouter; use --provider ollama-local for a local OpenAI-compatible server.",
    "",
  ].join("\n"));
  process.exit(code);
}

const options = { provider: "openrouter" };
for (let index = 0; index < argv.length; index += 1) {
  const flag = argv[index];
  if (flag === "-h" || flag === "--help") usage();
  const value = argv[index + 1];
  if (!value || value.startsWith("--")) usage(2);
  if (flag === "--provider") options.provider = value;
  else if (flag === "--model") options.model = value;
  else if (flag === "--system") options.system = value;
  else if (flag === "--session") options.agent = value;
  else if (flag === "--max-output-tokens") options.maximumOutputTokens = Number(value);
  else if (flag === "--resource-root") options.resourceRoot = value;
  else usage(2);
  index += 1;
}

runOpenAiAgentTui(options);
