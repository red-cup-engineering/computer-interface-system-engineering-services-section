import { availableEndpoints, defaultModelFor, firstAvailableEndpoint, resolveEndpoint } from "@emsenn/organizing-with-openai-agents/endpoints";
import { openaiAgentInfer } from "@emsenn/organizing-with-openai-agents/inference";
import { runChat } from "@emsenn/organizing-with-openai-agents/run";
import { endpointUrl } from "@emsenn/organizing-with-llm-agents/algebra";
import { encodeRequestBody } from "@emsenn/organizing-with-llm-agents/codecs/openai";
import type { Conversation, EndpointSpec, InferenceRequest } from "@emsenn/organizing-with-llm-agents/algebra";

type EnvLike = Readonly<Record<string, string | undefined>>;

export type KnowledgeVaultAgentRunOptions = Readonly<{
  prompt: string;
  endpoint?: string;
  model?: string;
  system?: string;
  session?: string;
  conversation?: Conversation;
  json?: boolean;
}>;

export type KnowledgeVaultAgentStreamOptions = Readonly<Omit<KnowledgeVaultAgentRunOptions, "json"> & {
  onToken?: (token: string) => void;
  fetch?: typeof fetch;
  env?: EnvLike;
}>;

export type KnowledgeVaultAgentRunResult = Readonly<{
  code: number;
  stdout: string;
  stderr: string;
}>;

const DEFAULT_SYSTEM = [
  "You are an agent mounted from the 561 Group Obsidian Knowledge Vault cockpit.",
  "Use the supplied mission and tool evidence as bounded corpus evidence.",
  "Preserve corpus-relative paths, name uncertainty, and propose dry-run writes before any external mutation.",
].join("\n");

export function listKnowledgeVaultAgentEndpoints(): string {
  return availableEndpoints()
    .map((endpoint) => `${endpoint.apiKey.present ? "present" : "missing"}\t${endpoint.endpoint}\t${endpoint.baseUrl}${endpoint.defaultModel === undefined ? "" : `\t${endpoint.defaultModel}`}`)
    .join("\n");
}

export async function runKnowledgeVaultAgent(options: KnowledgeVaultAgentRunOptions): Promise<KnowledgeVaultAgentRunResult> {
  const prompt = options.prompt.trim();
  if (prompt === "") return { code: 2, stdout: "", stderr: "obsidian-knowledge-agent: no prompt given\n" };
  const endpointId = options.endpoint ?? firstAvailableEndpoint()?.endpoint;
  if (endpointId === undefined) {
    return {
      code: 1,
      stdout: "",
      stderr: "obsidian-knowledge-agent: no endpoint key present (set NVIDIA_API_KEY/GROQ_API_KEY/CEREBRAS_API_KEY/OPENAI_API_KEY or pass --endpoint)\n",
    };
  }
  const endpoint = resolveEndpoint(endpointId);
  const outcome = await runChat(openaiAgentInfer(endpoint), {
    id: options.session ?? `obsidian-knowledge-agent:${endpoint.id}`,
    prompt,
    system: options.system?.trim() === "" || options.system === undefined ? DEFAULT_SYSTEM : options.system,
    ...(options.conversation === undefined ? {} : { conversation: options.conversation }),
    ...(options.model === undefined || options.model.trim() === "" ? {} : { model: options.model }),
  });
  if (options.json === true) {
    return {
      code: 0,
      stdout: `${JSON.stringify({
        endpoint: outcome.result.endpoint,
        model: outcome.result.model,
        regime: outcome.classification.regime,
        settled: outcome.classification.settled,
        usage: outcome.result.usage ?? null,
        cost: outcome.cost,
        text: outcome.result.text,
      }, null, 2)}\n`,
      stderr: "",
    };
  }
  return { code: 0, stdout: `${outcome.result.text}\n`, stderr: "" };
}

export async function streamKnowledgeVaultAgent(options: KnowledgeVaultAgentStreamOptions): Promise<KnowledgeVaultAgentRunResult> {
  const prompt = options.prompt.trim();
  if (prompt === "") return { code: 2, stdout: "", stderr: "obsidian-knowledge-agent: no prompt given\n" };
  const env = options.env ?? process.env;
  const endpointId = options.endpoint ?? firstAvailableEndpoint({ env })?.endpoint;
  if (endpointId === undefined) {
    return {
      code: 1,
      stdout: "",
      stderr: "obsidian-knowledge-agent: no endpoint key present (set NVIDIA_API_KEY/GROQ_API_KEY/CEREBRAS_API_KEY/OPENAI_API_KEY or pass --endpoint)\n",
    };
  }
  const endpoint = resolveEndpoint(endpointId);
  if (endpoint.dialect !== "openai") {
    return { code: 1, stdout: "", stderr: `obsidian-knowledge-agent: --stream requires an OpenAI-dialect endpoint, got ${endpoint.dialect}\n` };
  }
  const key = resolveApiKey(endpoint, env);
  if (key === null) {
    return {
      code: 1,
      stdout: "",
      stderr: `obsidian-knowledge-agent: no API key for ${endpoint.id} in ${(endpoint.apiKeyEnv ?? []).join(", ") || "(no env vars configured)"}\n`,
    };
  }
  const model = options.model === undefined || options.model.trim() === "" ? defaultModelFor(endpoint) : options.model;
  if (model === "") {
    return { code: 1, stdout: "", stderr: `obsidian-knowledge-agent: no model given and endpoint ${endpoint.id} has no default model\n` };
  }
  const request: InferenceRequest = {
    endpoint,
    model,
    system: options.system?.trim() === "" || options.system === undefined ? DEFAULT_SYSTEM : options.system,
    messages: Object.freeze([
      ...(options.conversation ?? []),
      { role: "user", content: prompt },
    ]),
    extraBody: { stream: true },
  };
  const body = encodeRequestBody(request);
  const fetcher = options.fetch ?? fetch;
  try {
    const response = await fetcher(endpointUrl(endpoint), {
      method: "POST",
      headers: authHeaders(endpoint, key),
      body: JSON.stringify(body),
    });
    if (!response.ok) {
      const text = await response.text();
      return { code: 1, stdout: "", stderr: `obsidian-knowledge-agent: HTTP ${response.status}: ${text}\n` };
    }
    if (response.body === null) {
      return { code: 1, stdout: "", stderr: "obsidian-knowledge-agent: streaming response had no body\n" };
    }
    const text = await consumeOpenaiSse(response.body, options.onToken);
    return { code: 0, stdout: text, stderr: "" };
  } catch (error) {
    return { code: 1, stdout: "", stderr: `obsidian-knowledge-agent: ${error instanceof Error ? error.message : String(error)}\n` };
  }
}

export function decodeOpenaiStreamEvent(data: string): string {
  const trimmed = data.trim();
  if (trimmed === "" || trimmed === "[DONE]") return "";
  let raw: unknown;
  try {
    raw = JSON.parse(trimmed);
  } catch {
    return "";
  }
  if (raw === null || typeof raw !== "object") return "";
  const record = raw as {
    readonly choices?: readonly {
      readonly delta?: { readonly content?: unknown };
      readonly message?: { readonly content?: unknown };
      readonly text?: unknown;
    }[];
    readonly output_text?: unknown;
  };
  const choice = record.choices?.[0];
  const content = choice?.delta?.content ?? choice?.message?.content ?? choice?.text ?? record.output_text;
  return typeof content === "string" ? content : "";
}

async function consumeOpenaiSse(body: ReadableStream<Uint8Array>, onToken: ((token: string) => void) | undefined): Promise<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let pending = "";
  let text = "";
  while (true) {
    const read = await reader.read();
    if (read.done) break;
    pending += decoder.decode(read.value, { stream: true });
    const lines = pending.split(/\r?\n/);
    pending = lines.pop() ?? "";
    for (const line of lines) {
      const token = decodeOpenaiSseLine(line);
      if (token === "") continue;
      text += token;
      onToken?.(token);
    }
  }
  pending += decoder.decode();
  if (pending !== "") {
    const token = decodeOpenaiSseLine(pending);
    if (token !== "") {
      text += token;
      onToken?.(token);
    }
  }
  return text;
}

function decodeOpenaiSseLine(line: string): string {
  const trimmed = line.trim();
  return trimmed.startsWith("data:") ? decodeOpenaiStreamEvent(trimmed.slice("data:".length)) : "";
}

function resolveApiKey(endpoint: EndpointSpec, env: EnvLike): string | null {
  for (const name of endpoint.apiKeyEnv ?? []) {
    const value = env[name];
    if (value !== undefined && value.trim() !== "") return value;
  }
  return null;
}

function authHeaders(endpoint: EndpointSpec, key: string): Record<string, string> {
  return {
    "content-type": "application/json",
    authorization: `Bearer ${key}`,
    ...(endpoint.headers ?? {}),
  };
}
