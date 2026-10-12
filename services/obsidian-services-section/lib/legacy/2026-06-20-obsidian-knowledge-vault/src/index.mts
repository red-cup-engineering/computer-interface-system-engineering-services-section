export const OBSIDIAN_KNOWLEDGE_VAULT_PACKAGE = "@emsenn/app-obsidian-knowledge-vault";
export const OBSIDIAN_KNOWLEDGE_VAULT_PLUGIN_ID = "knowledge-vault";
export const DEFAULT_CONTENT_ROOT = "content";
export const DEFAULT_TOOL_OUTPUT_FOLDER = "Tooling";

export {
  runKnowledgeVaultAction,
  knowledgeVaultActionHelp,
  type KnowledgeVaultActionRunOptions,
  type KnowledgeVaultActionRunResult,
} from "./tooling.mjs";

export {
  runKnowledgeVaultAgent,
  listKnowledgeVaultAgentEndpoints,
  type KnowledgeVaultAgentRunOptions,
  type KnowledgeVaultAgentRunResult,
} from "./agent.mjs";

export {
  knowledgeVaultCockpitManifest,
  renderCockpitManifestMarkdown,
  type KnowledgeVaultCockpitManifest,
} from "./cockpit.mjs";

export {
  knowledgeVaultDoctor,
  renderKnowledgeVaultDoctorMarkdown,
  type DoctorProbe,
  type KnowledgeVaultDoctorOptions,
  type KnowledgeVaultDoctorReport,
} from "./doctor.mjs";

export {
  KnowledgeVaultApplication,
  createKnowledgeVaultApplication,
  createKnowledgeVaultApplicationServer,
  routeKnowledgeVaultApplicationRequest,
  resolveCorpusPath,
  type KnowledgeVaultApplicationOptions,
  type KnowledgeVaultApplicationRequest,
} from "./app.mjs";
