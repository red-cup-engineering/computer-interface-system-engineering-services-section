/**
 * actions — the package's registered operations, each a cocone leg.
 *
 * The morphisms present the cockpit topology at the boundary: enumerate the agents
 * a config offers, open a fresh persona-bound session (the unit that makes each
 * launch its own character), resolve a request into a window plan, and compute the
 * Emacs launch invocation. `induceBins` over this list assembles the discovery
 * apex; the `cwe` dispatcher (and `cwe-serve`) project it to CLI/OpenAPI/MCP/web.
 * None of these files binds stdin or argv.
 */
import { randomUUID } from "node:crypto";
import { action, type Action } from "@emsenn/relating";
import { requireJsonValue, type JsonValue, type JsonRecord } from "@emsenn/relating/writing";
import {
  asCockpitConfig,
  defaultAgent,
  agentById,
  assignPersona,
  personaByName,
  resolveCockpit,
  emacsInvocation,
  DEFAULT_PERSONAS,
  type CockpitSession,
} from "./cockpit/index.mjs";

/** list-agents — a cockpit config in, the offered agents out (the chooser's source). */
export const listAgentsAction: Action = action({
  verb: "list-agents",
  inputFormat: "json",
  outputFormat: "json",
  summary: "Enumerate the chat agents a cockpit config offers.",
  description: "Domain: a CockpitConfig JSON document. Codomain: the array of agent endpoints, with the default flagged.",
  run: (input: unknown): JsonValue => {
    const config = asCockpitConfig(input);
    const defaultId = config.defaultAgentId ?? config.agents[0]?.id;
    return config.agents.map((agent) => ({
      id: agent.id,
      label: agent.label,
      kind: agent.kind,
      ...(agent.description === undefined ? {} : { description: agent.description }),
      isDefault: agent.id === defaultId,
    }));
  },
});

/** open-session — mint a fresh persona-bound session and resolve its cockpit plan.
 *  `--agent` selects the agent (default when omitted); `--session`/`--persona` pin
 *  an explicit id/character; `--cwd` sets the working directory. Each call without
 *  `--session` is a NEW session with its own character. */
export const openSessionAction: Action = action({
  verb: "open-session",
  inputFormat: "json",
  outputFormat: "json",
  options: ["agent", "cwd", "session", "persona"],
  summary: "Open a fresh persona-bound cockpit session and resolve its window plan.",
  description: "Domain: a CockpitConfig JSON on stdin. Options: --agent ID, --cwd DIR, --session ID (else minted), --persona NAME (else assigned from the pool by session id). Codomain: a session-scoped CockpitPlan as JSON.",
  run: (input: unknown, args: Record<string, unknown>): JsonValue => {
    const config = asCockpitConfig(input);
    const requestedAgent = typeof args["agent"] === "string" ? args["agent"] : undefined;
    const agent = requestedAgent === undefined ? defaultAgent(config) : agentById(config, requestedAgent);
    if (agent === undefined) throw new RangeError("open-session: no agent to open");
    const cwd = typeof args["cwd"] === "string" ? args["cwd"] : process.cwd();
    const sessionId = typeof args["session"] === "string" && args["session"] !== "" ? args["session"] : randomUUID();
    const pool = config.personas ?? DEFAULT_PERSONAS;
    const persona =
      typeof args["persona"] === "string" && args["persona"] !== ""
        ? personaByName(args["persona"], pool)
        : assignPersona(sessionId, pool);
    const session: CockpitSession = { id: sessionId, agentId: agent.id, persona };
    return resolveCockpit(config, { agentId: agent.id, cwd, session }) as unknown as JsonValue;
  },
});

/** resolve-cockpit — a config in (stdin) and an agent (`--agent`) into a sessionless
 *  window plan (no persona). For a persona-bound session, use open-session. */
export const resolveCockpitAction: Action = action({
  verb: "resolve-cockpit",
  inputFormat: "json",
  outputFormat: "json",
  options: ["agent", "cwd"],
  summary: "Resolve a chosen agent into a sessionless cockpit window plan.",
  description: "Domain: a CockpitConfig JSON on stdin; `--agent ID` selects the agent (default when omitted); `--cwd DIR` sets the cockpit working directory. Codomain: the CockpitPlan as JSON.",
  run: (input: unknown, args: Record<string, unknown>): JsonValue => {
    const config = asCockpitConfig(input);
    const agentId = typeof args["agent"] === "string" ? args["agent"] : undefined;
    const cwd = typeof args["cwd"] === "string" ? args["cwd"] : process.cwd();
    return resolveCockpit(config, { ...(agentId === undefined ? {} : { agentId }), cwd }) as unknown as JsonValue;
  },
});

/** emacs-invocation — an invocation request into the argv that launches the cockpit host. */
export const emacsInvocationAction: Action = action({
  verb: "emacs-invocation",
  inputFormat: "json",
  outputFormat: "json",
  summary: "Compute the argv (after `emacs`) that launches a package as an Emacs cockpit.",
  description: "Domain: a JSON object { initDirectory, cwd?, eval?, args? }. Codomain: the argv array as JSON.",
  run: (input: unknown): JsonValue => {
    const json = requireJsonValue(input, "emacs invocation request");
    if (json === null || typeof json !== "object" || Array.isArray(json)) {
      throw new TypeError("emacs-invocation: expected a JSON object { initDirectory, ... }");
    }
    const record = json as JsonRecord;
    const initDirectory = record["initDirectory"];
    if (typeof initDirectory !== "string") throw new TypeError("emacs-invocation: initDirectory is required");
    const toStrings = (value: JsonValue | undefined): readonly string[] | undefined =>
      Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : undefined;
    return [
      ...emacsInvocation({
        initDirectory,
        ...(typeof record["cwd"] === "string" ? { cwd: record["cwd"] } : {}),
        ...(toStrings(record["eval"]) === undefined ? {} : { eval: toStrings(record["eval"]) as readonly string[] }),
        ...(toStrings(record["args"]) === undefined ? {} : { args: toStrings(record["args"]) as readonly string[] }),
      }),
    ];
  },
});

/** The package's actions — the source `induceBins` reads. */
export const actions: readonly Action[] = Object.freeze([
  listAgentsAction,
  openSessionAction,
  resolveCockpitAction,
  emacsInvocationAction,
]);
