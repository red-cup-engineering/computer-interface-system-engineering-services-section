// coreCapabilityBundle, agentConnectorRegistration, mcpHttpSnippet, and
// vscodeMcpHttpSnippet, recovered local to this package.
//
// @emsenn/organizing-with-agents is gone from the house entirely (its
// source, lib/organizing-with-agents, last existed at 2cbcf1febd1~1); this
// package's src/cockpit.mjs is the only remaining consumer, and it reaches
// the cockpit's static manifest and connector-registration data (both
// eagerly built at module load, so cockpit.mjs cannot even be imported
// without them) rather than a runtime-optional feature, so this is a
// recovery, not an excision.
//
// The original functions carried their inputs through
// @emsenn/relating's schema-carrier admission (`carrierFrom(...).assert(...)`,
// itself part of the nine relationality packages, none of which exist
// anywhere in the house any more — not renamed, not folded, confirmed by
// census). Recovered here as the same plain-data shape and the same
// structural freeze/defaulting behavior, without that validation layer.

/**
 * One core relationality library's capability projection, as a provider's
 * agent surface would describe using it.
 * @typedef {{library: string, packageName: string, capability: string, kinds: readonly string[], actionVerbs: readonly string[], carrierIds: readonly string[], providerUse: string}} CoreCapabilityProjection
 */

/** @type {readonly CoreCapabilityProjection[]} */
export const coreCapabilitySpine = Object.freeze([
  {
    library: "relating",
    packageName: "@emsenn/relating",
    capability: "carrier/action boundary and bilattice evidence",
    kinds: Object.freeze(["carrier", "action", "holography"]),
    actionVerbs: Object.freeze(["dispatch", "witnessInvocation"]),
    carrierIds: Object.freeze(["relating/action", "relating/invocation"]),
    providerUse: "Admit provider events as action-bearing, witnessable relation carriers.",
  },
  {
    library: "communicating",
    packageName: "@emsenn/communicating",
    capability: "message, channel, speech-act, and common-ground surfaces",
    kinds: Object.freeze(["carrier", "codec", "action"]),
    actionVerbs: Object.freeze(["communicating.admit", "communicating.speak", "communicating.listen"]),
    carrierIds: Object.freeze(["communicating/message", "communicating/channel", "communicating/common-ground"]),
    providerUse: "Represent prompts, replies, tool observations, and summaries as communication rather than raw strings.",
  },
  {
    library: "knowing",
    packageName: "@emsenn/knowing",
    capability: "memory, research, proof, explanation, and learning carriers",
    kinds: Object.freeze(["carrier", "action", "session"]),
    actionVerbs: Object.freeze(["knowing.cognize", "knowing.recollect", "knowing.infer"]),
    carrierIds: Object.freeze(["knowing/memory", "knowing/research", "knowing/lesson"]),
    providerUse: "Turn conversation traces and retrieval results into durable knowledge and lesson evidence.",
  },
  {
    library: "playing",
    packageName: "@emsenn/playing",
    capability: "design, duality, interaction, and strategy surfaces",
    kinds: Object.freeze(["carrier", "action"]),
    actionVerbs: Object.freeze(["playing.design", "playing.dualize", "playing.interact"]),
    carrierIds: Object.freeze(["playing/design", "playing/interaction"]),
    providerUse: "Model prompt plans, counter-prompts, eval rubrics, and adversarial review as designs in interaction.",
  },
  {
    library: "animating",
    packageName: "@emsenn/animating",
    capability: "perceive-act-goal agency loop and governing descent",
    kinds: Object.freeze(["carrier", "action", "runtime"]),
    actionVerbs: Object.freeze(["animating.perceive", "animating.act", "animating.governing"]),
    carrierIds: Object.freeze(["animating/agent", "animating/perception", "animating/goal"]),
    providerUse: "Read an agent run as a perceiving, acting, goal-directed loop rather than one inference call.",
  },
  {
    library: "socializing",
    packageName: "@emsenn/socializing",
    capability: "multi-observer field, translation, attendance, and consensus",
    kinds: Object.freeze(["carrier", "action", "governance"]),
    actionVerbs: Object.freeze(["socializing.admit", "socializing.translate", "socializing.converge"]),
    carrierIds: Object.freeze(["socializing/social-field", "socializing/translation", "socializing/consensus"]),
    providerUse: "Project several agents, tools, or reviewers as observers in one social field.",
  },
  {
    library: "computing",
    packageName: "@emsenn/computing",
    capability: "capability decision, program execution, work classification, and environment codecs",
    kinds: Object.freeze(["carrier", "action", "runtime"]),
    actionVerbs: Object.freeze(["computing.compute", "computing.decide", "computing.classify-work"]),
    carrierIds: Object.freeze(["computing/capability-request", "computing/decision", "computing/work-closure"]),
    providerUse: "Classify whether a provider can execute work locally, remotely, cheaply, or only with abstention.",
  },
  {
    library: "gaming",
    packageName: "@emsenn/gaming",
    capability: "concurrent game arenas, strategies, roles, and play traces",
    kinds: Object.freeze(["carrier", "action", "runtime"]),
    actionVerbs: Object.freeze(["gaming.create", "gaming.play", "gaming.settle"]),
    carrierIds: Object.freeze(["gaming/arena", "gaming/strategy", "gaming/game"]),
    providerUse: "Make multi-agent/tool interaction explicit as a game arena with traces and settlement.",
  },
  {
    library: "organizing",
    packageName: "@emsenn/organizing",
    capability: "work, office eligibility, accounting, adjudication, and federation",
    kinds: Object.freeze(["carrier", "action", "governance"]),
    actionVerbs: Object.freeze(["organizing.organize", "organizing.office-eligibility", "organizing.accounting-balance"]),
    carrierIds: Object.freeze(["organizing/work-record", "organizing/office-eligibility", "organizing/organization"]),
    providerUse: "Bind agent activity to work records, offices, adjudication, and collective operating state.",
  },
]);

/**
 * A provider's bundle of core-library capability projections.
 * @param {{provider: string, surface: string, projections?: readonly CoreCapabilityProjection[]}} input
 * @returns {{provider: string, surface: string, projections: readonly CoreCapabilityProjection[]}}
 */
export function coreCapabilityBundle(input) {
  return Object.freeze({
    provider: input.provider,
    surface: input.surface,
    projections: Object.freeze([...(input.projections ?? coreCapabilitySpine)]),
  });
}

/**
 * Registers one external-host connector (MCP/OpenAPI/etc.) for an agent-capable tool surface.
 * @param {{id: string, title: string, packageName: string, transport: "http"|"stdio"|"hybrid", command: string, args: readonly string[], env: Readonly<Record<string, string>>, endpoints: object, snippets: readonly object[]}} input
 * @returns {object} The frozen registration, tagged with its kind.
 */
export function agentConnectorRegistration(input) {
  return Object.freeze({
    kind: "agent.connector.registration",
    ...input,
    args: Object.freeze([...input.args]),
    env: Object.freeze({ ...input.env }),
    snippets: Object.freeze(input.snippets.map((snippet) => Object.freeze({ ...snippet }))),
  });
}

/** An MCP-over-HTTP client config snippet (`.mcp.json`-style). */
export function mcpHttpSnippet(input) {
  return JSON.stringify({
    mcpServers: {
      [input.name]: {
        type: "http",
        url: input.url,
      },
    },
  }, null, 2);
}

/** A VS Code MCP-over-HTTP client config snippet (`.vscode/mcp.json`-style). */
export function vscodeMcpHttpSnippet(input) {
  return JSON.stringify({
    servers: {
      [input.name]: {
        type: "http",
        url: input.url,
      },
    },
  }, null, 2);
}
