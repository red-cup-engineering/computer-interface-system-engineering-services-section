// The OpenAI-agent interface is a Wheatstone local-world adapter.  It owns the
// conversation and projects each settled exchange as ordinary terminal output;
// provider credentials, admission, rate limits, and the HTTP exchange remain
// owned by computer-inference-engine.

import { providerConfiguration, runProviderExchange } from "@red-cup-engineering/computer-inference-engine/openai/provider-runtime";
import { run as runWheatstone } from "@red-cup-engineering/wheatstone/app";
import { localWorld } from "@red-cup-engineering/wheatstone/world";

function requiredText(value, name) {
  if (typeof value !== "string" || !value.trim()) throw new TypeError(`${name} must be nonempty text`);
  return value.trim();
}

function message(role, content) {
  return Object.freeze({ role, content });
}

function traceOf(record, provider, model) {
  return Object.freeze({
    provider,
    model: record.completion?.model || model,
    exchange: record.id,
    recordedAt: record.recordedAt,
    finishReason: record.completion?.["finish-reason"] || null,
    usage: record.usage || {},
    cost: record.cost || {},
  });
}

function traceLine(trace) {
  const usage = trace.usage;
  const tokens = [usage.input?.quantity, usage.output?.quantity].filter((value) => Number.isFinite(value));
  return `— ${trace.provider}/${trace.model}; exchange ${trace.exchange}; ${trace.finishReason || "finished"}${tokens.length ? `; ${tokens.join("/")} tokens` : ""} —`;
}

/**
 * Creates the agent-specific world carrier.  The returned carrier is still a
 * normal Wheatstone world: its lines are the assistant replies, and its GMCP
 * projection gives the shared status/panel model a name, provider, and the
 * complete exchange trace.
 */
export function openAiAgentWorld(options = {}) {
  const provider = requiredText(options.provider, "provider");
  const configuration = providerConfiguration(provider);
  const model = typeof options.model === "string" && options.model.trim()
    ? options.model.trim()
    : requiredText(configuration.defaultModel, `provider ${provider} defaultModel`);
  const agent = typeof options.agent === "string" && options.agent.trim() ? options.agent.trim() : "openai-agent";
  const system = typeof options.system === "string" && options.system.trim() ? options.system.trim() : null;
  const maximumOutputTokens = options.maximumOutputTokens;
  if (maximumOutputTokens !== undefined && (!Number.isSafeInteger(maximumOutputTokens) || maximumOutputTokens < 1)) {
    throw new TypeError("maximumOutputTokens must be a positive safe integer");
  }

  let conversation = system ? [message("system", system)] : [];
  let busy = false;
  return localWorld({
    kind: "openai-agent",
    onConnect(emit) {
      emit.gmcp("Char.Status", { name: agent });
      emit.gmcp("Room.Info", { name: provider, area: model });
      emit.gmcp("Agent.State", { agent, provider, model, conversation: conversation.length });
    },
    async onSend(text, emit) {
      const prompt = String(text ?? "").trim();
      if (!prompt) return;
      if (busy) { emit.line("— the agent is still answering —"); return; }
      busy = true;
      const candidate = [...conversation, message("user", prompt)];
      emit.line("— thinking —");
      try {
        const record = await runProviderExchange(provider, {
          model,
          messages: candidate,
          ...(maximumOutputTokens === undefined ? {} : { "max-tokens": maximumOutputTokens }),
        }, {
          ...(options.resourceRoot === undefined ? {} : { resourceRoot: options.resourceRoot }),
          ...(options.request === undefined ? {} : { request: options.request }),
        });
        if (record.outcome !== "completion") {
          const grounds = record.refusal?.grounds || "provider refused the exchange";
          emit.line(`— the agent could not answer: ${grounds} —`);
          emit.gmcp("Agent.State", { agent, provider, model, refusal: record.refusal || {}, exchange: record.id });
          return;
        }
        const reply = record.completion.text;
        conversation = [...candidate, message("assistant", reply)];
        const trace = traceOf(record, provider, model);
        emit.line(reply);
        emit.line(traceLine(trace));
        emit.gmcp("Agent.State", { agent, conversation: conversation.length, trace });
      } catch (error) {
        const reason = error instanceof Error ? error.message : String(error);
        emit.line(`— the agent could not answer: ${reason} —`);
        emit.gmcp("Agent.State", { agent, provider, model, error: reason });
      } finally {
        busy = false;
      }
    },
  });
}

/** Start the canonical OpenAI-compatible agent terminal application. */
export function runOpenAiAgentTui(options = {}) {
  const world = options.world || openAiAgentWorld(options);
  return runWheatstone({
    ...options,
    name: options.name || "openai-agent-tui",
    world,
    target: options.target || options.provider,
    showPanel: options.showPanel ?? true,
  });
}
