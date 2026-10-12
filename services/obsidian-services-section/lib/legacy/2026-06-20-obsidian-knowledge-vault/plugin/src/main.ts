import {
  App,
  ButtonComponent,
  DropdownComponent,
  FileSystemAdapter,
  FuzzySuggestModal,
  ItemView,
  MarkdownView,
  Modal,
  Notice,
  Plugin,
  PluginSettingTab,
  Setting,
  TFile,
  TextAreaComponent,
  TextComponent,
  WorkspaceLeaf,
  normalizePath,
  type FuzzyMatch,
} from "obsidian";

type ChildProcessModule = typeof import("node:child_process");
type PathModule = typeof import("node:path");
type UrlModule = typeof import("node:url");

type AgentEditTarget = "note" | "selection" | "file" | "region";

type AgentContextRelation = "outlink" | "backlink" | "tag" | "frontmatter" | "recent" | "canvas" | "unresolved" | "search" | "manual";

type AgentContextReference = Readonly<{
  kind: "agent.context.reference";
  source: string;
  target: string;
  relation: AgentContextRelation;
  score: number;
  reasons: readonly string[];
  title?: string;
  preview?: string;
  modifiedAt?: string;
}>;

type AgentContextNeighborhood = Readonly<{
  kind: "agent.context.neighborhood";
  source: string;
  generatedAt: string;
  references: readonly AgentContextReference[];
}>;

type AgentContextModule = Readonly<{
  agentContextReference: (input: Omit<AgentContextReference, "kind">) => AgentContextReference;
  rankAgentContextNeighborhood: (input: Readonly<{
    source: string;
    references: readonly AgentContextReference[];
    generatedAt?: string;
    limit?: number;
  }>) => AgentContextNeighborhood;
}>;

type CanvasNode = Readonly<{
  id: string;
  type: string;
  file?: string;
  text?: string;
  url?: string;
  label?: string;
}>;

type CanvasEdge = Readonly<{
  fromNode: string;
  toNode: string;
  label?: string;
}>;

type CanvasGraph = Readonly<{
  nodes: readonly CanvasNode[];
  edges: readonly CanvasEdge[];
}>;

type AgentReviewModule = Readonly<{
  approvalValueApproved: (value: unknown) => boolean;
  editProposalDiff: (input: Readonly<{
    source: string;
    proposal: string;
    appliesTo: AgentEditTarget;
    original: string;
    proposed: string;
  }>) => Readonly<{
    additions: number;
    deletions: number;
    text: string;
  }>;
  editApplyReceipt: (input: Readonly<{
    source: string;
    proposal: string;
    appliesTo: AgentEditTarget;
    before: string;
    after: string;
  }>) => Readonly<{
    source: string;
    proposal: string;
    appliesTo: AgentEditTarget;
    appliedAt: string;
    before: string;
    after: string;
  }>;
}>;

const KNOWLEDGE_VAULT_COCKPIT_VIEW = "knowledge-vault-cockpit-view";

type ToolRequest = Readonly<{
  verb: string;
  stdin: string;
  args?: readonly string[];
  title: string;
}>;

type ToolResult = Readonly<{
  code: number;
  stdout: string;
  stderr: string;
}>;

type RuntimeCommand = Readonly<{
  command: string;
  args: readonly string[];
  cwd: string;
}>;

type RuntimeDoctorProbe = Readonly<{
  label: string;
  command: string;
  args: readonly string[];
  cwd: string;
  code: number;
  stdout: string;
  stderr: string;
}>;

type AgentRequest = Readonly<{
  prompt: string;
  title: string;
  json?: boolean;
  stream?: boolean;
  session?: string;
  conversation?: readonly ChatMessage[];
}>;

type ChatMessage = Readonly<{
  role: "user" | "assistant" | "system" | "tool";
  content: string;
}>;

type LiveAgentRun = Readonly<{
  stop: () => void;
  promise: Promise<ToolResult>;
}>;

type GeneratedNoteRecord = Readonly<{
  path: string;
  modifiedAt: string;
  title: string | undefined;
  kind: string | undefined;
  status: string | undefined;
  source: string | undefined;
  verb: string | undefined;
}>;

type AgentSessionCheckpointArtifact = Readonly<{
  path: string;
  title?: string;
  kind?: string;
  status?: string;
  source?: string;
  modifiedAt?: string;
}>;

type AgentSessionCheckpoint = Readonly<{
  kind: "agent.session.checkpoint";
  session: string;
  generatedAt: string;
  title?: string;
  objective?: string;
  activePath?: string;
  readiness: readonly string[];
  artifacts: readonly AgentSessionCheckpointArtifact[];
  evidence: readonly string[];
  suggestedCommands: readonly string[];
  next: readonly string[];
}>;

type AgentCheckpointModule = Readonly<{
  sessionCheckpoint: (input: Readonly<{
    session: string;
    generatedAt?: string;
    title?: string;
    objective?: string;
    activePath?: string;
    readiness?: readonly string[];
    artifacts?: readonly AgentSessionCheckpointArtifact[];
    evidence?: readonly string[];
    suggestedCommands?: readonly string[];
    next?: readonly string[];
  }>) => AgentSessionCheckpoint;
  renderSessionCheckpointMarkdown: (checkpoint: AgentSessionCheckpoint) => string;
}>;

type EditReceiptSummary = Readonly<{
  file: TFile;
  path: string;
  appliedAt: string;
  appliesTo: string;
  proposal: string | undefined;
  rollbackApproved: boolean;
  modifiedAt: string;
}>;

type ReviewQueueFilter = "needs-review" | "proposals" | "arenas" | "receipts" | "all";

type QuickSwitchItem = Readonly<{
  kind: "active" | "neighbor" | "generated";
  path: string;
  title: string;
  detail: string;
  score?: number;
}>;

type KnowledgeVaultSettings = Readonly<{
  repoRoot: string;
  appRoot: string;
  contentRoot: string;
  nodeExecutable: string;
  packageRunnerExecutable: string;
  runtimePackage: string;
  outputFolder: string;
  agentFolder: string;
  defaultRegion: string;
  contextLimit: number;
  agentEndpoint: string;
  agentModel: string;
  agentApiKeyEnv: string;
  agentApiKey: string;
  agentSystem: string;
  allowExternalWrites: boolean;
  allowNoteEdits: boolean;
}>;

const DEFAULT_SETTINGS: KnowledgeVaultSettings = Object.freeze({
  repoRoot: "",
  appRoot: "",
  contentRoot: "content",
  nodeExecutable: "node",
  packageRunnerExecutable: "npx",
  runtimePackage: "@emsenn/app-obsidian-knowledge-vault@0.0.0",
  outputFolder: "Tooling",
  agentFolder: "Agents",
  defaultRegion: "content",
  contextLimit: 120,
  agentEndpoint: "",
  agentModel: "",
  agentApiKeyEnv: "OPENAI_API_KEY",
  agentApiKey: "",
  agentSystem: "",
  allowExternalWrites: false,
  allowNoteEdits: false,
});

const COCKPIT_ACTIONS = Object.freeze([
  "inspect-root",
  "catalog",
  "find-name",
  "grep-text",
  "read",
  "topic-guidance",
  "inspect-topic",
  "concept-map",
  "measure-gap",
  "inspect-health",
  "normalization-plan",
  "upload-triage-file",
  "plan-static-site-publication",
] as const);

const localAgentContextModule: AgentContextModule = Object.freeze({
  agentContextReference: (input) => Object.freeze({ kind: "agent.context.reference", ...input }),
  rankAgentContextNeighborhood: (input) => {
    const merged = new Map<string, AgentContextReference>();
    for (const reference of input.references) {
      const key = `${reference.target}\u0000${reference.relation}`;
      const existing = merged.get(key);
      if (existing === undefined) {
        merged.set(key, reference);
        continue;
      }
      const title = existing.title ?? reference.title;
      const preview = existing.preview ?? reference.preview;
      const modifiedAt = existing.modifiedAt ?? reference.modifiedAt;
      merged.set(key, Object.freeze({
        source: reference.source,
        target: reference.target,
        relation: reference.relation,
        kind: reference.kind,
        score: existing.score + reference.score,
        reasons: Object.freeze([...existing.reasons, ...reference.reasons]),
        ...(title === undefined ? {} : { title }),
        ...(preview === undefined ? {} : { preview }),
        ...(modifiedAt === undefined ? {} : { modifiedAt }),
      }));
    }
    return Object.freeze({
      kind: "agent.context.neighborhood",
      source: input.source,
      generatedAt: input.generatedAt ?? new Date().toISOString(),
      references: Object.freeze([...merged.values()]
        .sort((left, right) => right.score - left.score || left.target.localeCompare(right.target))
        .slice(0, input.limit ?? 24)),
    });
  },
});

const localAgentReviewModule: AgentReviewModule = Object.freeze({
  approvalValueApproved: (value) => {
    if (typeof value === "boolean") return value;
    if (typeof value !== "string") return false;
    return ["true", "yes", "approved", "approve", "1"].includes(value.trim().toLowerCase());
  },
  editProposalDiff: (input) => localEditProposalDiff(input.original, input.proposed),
  editApplyReceipt: (input) => Object.freeze({
    source: input.source,
    proposal: input.proposal,
    appliesTo: input.appliesTo,
    appliedAt: new Date().toISOString(),
    before: input.before,
    after: input.after,
  }),
});

const localAgentCheckpointModule: AgentCheckpointModule = Object.freeze({
  sessionCheckpoint: (input) => Object.freeze({
    kind: "agent.session.checkpoint" as const,
    session: input.session,
    generatedAt: input.generatedAt ?? new Date().toISOString(),
    ...(input.title === undefined ? {} : { title: input.title }),
    ...(input.objective === undefined ? {} : { objective: input.objective }),
    ...(input.activePath === undefined ? {} : { activePath: input.activePath }),
    readiness: Object.freeze([...(input.readiness ?? [])]),
    artifacts: Object.freeze((input.artifacts ?? []).map((artifact) => Object.freeze({ ...artifact }))),
    evidence: Object.freeze([...(input.evidence ?? [])]),
    suggestedCommands: Object.freeze([...(input.suggestedCommands ?? [])]),
    next: Object.freeze([...(input.next ?? [])]),
  }),
  renderSessionCheckpointMarkdown: (checkpoint) => renderLocalSessionCheckpointMarkdown(checkpoint),
});

export default class KnowledgeVaultPlugin extends Plugin {
  kvSettings: KnowledgeVaultSettings = DEFAULT_SETTINGS;

  override async onload(): Promise<void> {
    this.kvSettings = Object.freeze({ ...DEFAULT_SETTINGS, ...(await this.loadData()) });
    this.addSettingTab(new KnowledgeVaultSettingTab(this.app, this));
    this.registerView(KNOWLEDGE_VAULT_COCKPIT_VIEW, (leaf) => new KnowledgeVaultCockpitView(leaf, this));
    this.addRibbonIcon("folder-tree", "Open knowledge vault cockpit", () => this.openCockpitView());

    this.addCommand({
      id: "open-cockpit",
      name: "Open knowledge vault cockpit",
      callback: () => this.openCockpitView(),
    });
    this.addCommand({
      id: "open-dashboard",
      name: "Open knowledge vault dashboard",
      callback: () => this.openDashboard(),
    });
    this.addCommand({
      id: "catalog-content",
      name: "Catalog content vault",
      callback: () => this.writeToolNote({
        verb: "catalog",
        stdin: "",
        args: ["--limit", "250"],
        title: "Knowledge vault catalog",
      }),
    });
    this.addCommand({
      id: "inspect-health",
      name: "Inspect content vault health",
      callback: () => this.writeToolNote({
        verb: "inspect-health",
        stdin: "",
        args: ["--limit", "250"],
        title: "Knowledge vault health",
      }),
    });
    this.addCommand({
      id: "plan-normalization",
      name: "Plan content vault normalization",
      callback: () => this.writeToolNote({
        verb: "normalization-plan",
        stdin: "",
        args: ["--limit", "250"],
        title: "Knowledge vault normalization plan",
      }),
    });
    this.addCommand({
      id: "plan-next-gen-emsenn-net-publication",
      name: "Plan next-gen emsenn.net publication",
      callback: () => this.writeNextGenEmsennNetPublicationPlan(),
    });
    this.addCommand({
      id: "run-tool-palette",
      name: "Run knowledge vault tool",
      callback: () => new KnowledgeVaultToolModal(this.app, this).open(),
    });
    this.addCommand({
      id: "search-content-vault",
      name: "Search content vault",
      callback: () => new KnowledgeVaultSearchModal(this.app, this).open(),
    });
    this.addCommand({
      id: "build-active-note-context-pack",
      name: "Build active note context pack",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.buildActiveNoteContextPack(file);
        return true;
      },
    });
    this.addCommand({
      id: "build-active-note-neighborhood",
      name: "Build active note neighborhood",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.buildActiveNoteNeighborhoodNote(file);
        return true;
      },
    });
    this.addCommand({
      id: "create-agent-mission-from-active-note",
      name: "Create agent mission from active note",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.createAgentMissionFromActiveNote(file);
        return true;
      },
    });
    this.addCommand({
      id: "create-arena-from-active-note",
      name: "Create cockpit arena from active note",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.createArenaFromActiveNote(file);
        return true;
      },
    });
    this.addCommand({
      id: "advance-active-arena",
      name: "Advance active cockpit arena",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.advanceActiveArena(file);
        return true;
      },
    });
    this.addCommand({
      id: "list-agent-endpoints",
      name: "List ecosystem agent endpoints",
      callback: () => this.listAgentEndpoints(),
    });
    this.addCommand({
      id: "write-cockpit-manifest",
      name: "Write cockpit manifest",
      callback: () => this.writeCockpitManifestNote(),
    });
    this.addCommand({
      id: "write-runtime-setup",
      name: "Write runtime setup note",
      callback: () => this.writeRuntimeSetupNote(),
    });
    this.addCommand({
      id: "write-runtime-doctor",
      name: "Write runtime doctor note",
      callback: () => this.writeRuntimeDoctorNote(),
    });
    this.addCommand({
      id: "write-cockpit-checkpoint",
      name: "Write cockpit checkpoint",
      callback: () => this.writeCockpitCheckpointNote(),
    });
    this.addCommand({
      id: "write-cockpit-handoff",
      name: "Write cockpit handoff",
      callback: () => this.writeCockpitHandoffNote(),
    });
    this.addCommand({
      id: "write-cockpit-queue",
      name: "Write cockpit queue",
      callback: () => this.writeCockpitQueueNote(),
    });
    this.addCommand({
      id: "open-cockpit-review-queue",
      name: "Open cockpit review queue",
      callback: () => this.openCockpitReviewQueue(),
    });
    this.addCommand({
      id: "open-cockpit-quick-switcher",
      name: "Open cockpit quick switcher",
      callback: () => this.openCockpitQuickSwitcher(),
    });
    this.addCommand({
      id: "write-cockpit-audit",
      name: "Write cockpit capability audit",
      callback: () => this.writeCockpitAuditNote(),
    });
    this.addCommand({
      id: "write-connector-snippets",
      name: "Write connector snippets",
      callback: () => this.writeConnectorSnippetsNote(),
    });
    this.addCommand({
      id: "run-active-note-with-agent",
      name: "Run active note with ecosystem agent",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.runActiveNoteWithAgent(file);
        return true;
      },
    });
    this.addCommand({
      id: "propose-active-note-edit",
      name: "Propose active note edit",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.proposeActiveNoteEdit(file);
        return true;
      },
    });
    this.addCommand({
      id: "preview-active-note-edit-proposal-diff",
      name: "Preview active note edit proposal diff",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.previewActiveNoteEditProposalDiff(file);
        return true;
      },
    });
    this.addCommand({
      id: "apply-active-note-edit-proposal",
      name: "Apply active note edit proposal",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.applyActiveNoteEditProposal(file);
        return true;
      },
    });
    this.addCommand({
      id: "restore-active-note-from-edit-receipt",
      name: "Choose edit receipt to restore",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.restoreActiveNoteFromEditReceipt(file);
        return true;
      },
    });
    this.addCommand({
      id: "map-active-note-topic",
      name: "Map active note topic",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.mapActiveNoteTopic(file);
        return true;
      },
    });
    this.addCommand({
      id: "prepare-active-note-triage-deposit",
      name: "Prepare active note triage deposit",
      checkCallback: (checking) => {
        const file = this.activeMarkdownFile();
        if (file === null) return false;
        if (!checking) void this.prepareActiveNoteTriageDeposit(file);
        return true;
      },
    });
  }

  override onunload(): void {
    this.app.workspace.detachLeavesOfType(KNOWLEDGE_VAULT_COCKPIT_VIEW);
  }

  async saveSettings(next: KnowledgeVaultSettings): Promise<void> {
    this.kvSettings = Object.freeze(next);
    await this.saveData(this.kvSettings);
  }

  async openCockpitView(): Promise<void> {
    const leaves = this.app.workspace.getLeavesOfType(KNOWLEDGE_VAULT_COCKPIT_VIEW);
    const leaf = leaves[0] ?? this.app.workspace.getRightLeaf(false);
    if (leaf === null) return;
    await leaf.setViewState({ type: KNOWLEDGE_VAULT_COCKPIT_VIEW, active: true });
    this.app.workspace.revealLeaf(leaf);
  }

  async openDashboard(): Promise<void> {
    const root = await this.runTool({ verb: "inspect-root", stdin: "", title: "Knowledge vault root" });
    const health = root.code === 0
      ? await this.runTool({ verb: "inspect-health", stdin: "", args: ["--limit", "100"], title: "Knowledge vault health" })
      : undefined;
    const catalog = root.code === 0
      ? await this.runTool({ verb: "catalog", stdin: "", args: ["--limit", String(this.kvSettings.contextLimit)], title: "Knowledge vault catalog" })
      : undefined;
    const body = [
      "---",
      "title: Knowledge vault dashboard",
      "tool: obsidian-knowledge-vault",
      "---",
      "",
      "# Knowledge vault dashboard",
      "",
      "## Runtime setup",
      "",
      ...this.runtimeReadinessLines(),
      "",
      "## Root",
      "",
      this.resultBlock(root),
      "",
      "## Health",
      "",
      health === undefined ? "Root inspection failed." : this.resultBlock(health),
      "",
      "## Catalog",
      "",
      catalog === undefined ? "Root inspection failed." : this.resultBlock(catalog),
      "",
      "## Agent cockpit",
      "",
      "- Build active note context pack",
      "- Create agent mission from active note",
      "- Create cockpit arena from active note",
      "- Search content vault",
      "- Run knowledge vault tool",
      "- Write runtime setup note",
      "- Write runtime doctor note",
      "- Write cockpit checkpoint",
      "- Write cockpit handoff",
      "- Write cockpit queue",
      "- Write cockpit capability audit",
      "",
    ].join("\n");
    await this.upsertNote("knowledge-vault-dashboard.md", body);
  }

  private async writeNextGenEmsennNetPublicationPlan(): Promise<void> {
    const path = this.pathModule();
    const repoRoot = this.resolvedRepoRoot(path);
    await this.writeToolNote({
      verb: "plan-static-site-publication",
      stdin: JSON.stringify({
        site: "next-gen.emsenn.net",
        baseUrl: "https://next-gen.emsenn.net",
        siteRoot: path.join(repoRoot, "sites", "emsenn.net"),
        outDir: "build-next-gen",
        branch: "main",
        buildCommand: "pnpm --filter @emsenn/emsenn.net run build:next-gen",
        commitMessage: "Publish next-gen emsenn.net from knowledge vault",
        artifactPaths: [
          "build-next-gen/",
          "build-next-gen/index.html",
          "build-next-gen/map.json",
          "build-next-gen/map-health.json",
          "build-next-gen/CNAME",
          "build-next-gen/.nojekyll",
        ],
      }),
      title: "Next-gen emsenn.net publication plan",
    });
  }

  private async mapActiveNoteTopic(file: TFile): Promise<void> {
    const topic = file.basename.replaceAll("-", " ");
    await this.writeToolNote({
      verb: "concept-map",
      stdin: topic,
      args: ["--region", "content", "--limit", "250"],
      title: `Concept map for ${topic}`,
    });
  }

  private async prepareActiveNoteTriageDeposit(file: TFile): Promise<void> {
    const text = await this.app.vault.read(file);
    const payload = JSON.stringify({ filename: file.name, content: text });
    const writeArgs = this.kvSettings.allowExternalWrites ? ["--write", "true"] : [];
    await this.writeToolNote({
      verb: "upload-triage-file",
      stdin: payload,
      args: writeArgs,
      title: this.kvSettings.allowExternalWrites
        ? `Triage deposit for ${file.basename}`
        : `Dry-run triage deposit for ${file.basename}`,
    });
  }

  async buildActiveNoteContextPack(file: TFile): Promise<void> {
    const topic = await this.topicForFile(file);
    const noteText = await this.app.vault.read(file);
    const obsidianContext = this.activeNoteContextSections(file);
    const neighborhood = await this.activeNoteNeighborhoodSections(file, 12);
    const bundle = await this.contextBundle(topic);
    const body = [
      "---",
      `title: Context pack for ${topic}`,
      "tool: obsidian-knowledge-vault",
      "kind: agent-context-pack",
      `source: ${file.path}`,
      "---",
      "",
      `# Context pack for ${topic}`,
      "",
      "## Active note",
      "",
      `Path: ${file.path}`,
      "",
      "```markdown",
      noteText.trim(),
      "```",
      "",
      ...obsidianContext,
      ...neighborhood,
      ...bundle,
    ].join("\n");
    await this.upsertNote(`context-pack-${this.slug(topic)}.md`, body);
  }

  async buildActiveNoteNeighborhoodNote(file: TFile): Promise<void> {
    const topic = await this.topicForFile(file);
    const neighborhood = await this.activeNoteNeighborhood(file, 24);
    const body = [
      "---",
      `title: Active note neighborhood for ${topic}`,
      "tool: obsidian-knowledge-vault",
      "kind: agent-context-neighborhood",
      `source: ${file.path}`,
      `generated: ${neighborhood.generatedAt}`,
      "---",
      "",
      `# Active note neighborhood for ${topic}`,
      "",
      ...this.renderNeighborhoodSections(neighborhood),
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, `neighborhood-${this.slug(topic)}.md`, body);
  }

  async createAgentMissionFromActiveNote(file: TFile): Promise<void> {
    const selected = this.editorSelection();
    const noteText = selected.trim() === "" ? await this.app.vault.read(file) : selected;
    const topic = await this.topicForFile(file);
    const obsidianContext = this.activeNoteContextSections(file);
    const neighborhood = await this.activeNoteNeighborhoodSections(file, 12);
    const bundle = await this.contextBundle(topic);
    const body = [
      "---",
      `title: Agent mission for ${topic}`,
      "tool: obsidian-knowledge-vault",
      "kind: agent-mission",
      `source: ${file.path}`,
      "status: proposed",
      "---",
      "",
      `# Agent mission for ${topic}`,
      "",
      "## Mission",
      "",
      noteText.trim(),
      "",
      "## Working rule",
      "",
      "Use the knowledge-vault tools as bounded evidence readers. Inspect before writing, preserve corpus-relative evidence paths, and treat dry-run mutation output as a proposal until reviewed.",
      "",
      "## Suggested route",
      "",
      "1. Read this mission and the context bundle below.",
      "2. Use `inspect-root`, `catalog`, `find-name`, `grep-text`, and `read` to gather the smallest sufficient evidence.",
      "3. Use `topic-guidance`, `concept-map`, and `measure-gap` to plan placement or follow-up work.",
      "4. Produce dry-run writes before enabling any external write.",
      "",
      ...obsidianContext,
      ...neighborhood,
      ...bundle,
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, `mission-${this.slug(topic)}.md`, body);
  }

  async createArenaFromActiveNote(file: TFile): Promise<void> {
    const selected = this.editorSelection();
    const requestText = selected.trim() === "" ? await this.app.vault.read(file) : selected;
    const topic = await this.topicForFile(file);
    const manifest = await this.runCockpitManifest(true);
    const bundle = await this.contextBundle(topic);
    const neighborhood = await this.activeNoteNeighborhoodSections(file, 12);
    const body = [
      "---",
      `title: Cockpit arena for ${topic}`,
      "tool: obsidian-knowledge-vault",
      "kind: cockpit-arena",
      `source: ${file.path}`,
      "status: admitted",
      `scope: ${selected.trim() === "" ? "note" : "selection"}`,
      `created: ${new Date().toISOString()}`,
      "---",
      "",
      `# Cockpit arena for ${topic}`,
      "",
      "## Request",
      "",
      "```markdown",
      requestText.trim(),
      "```",
      "",
      "## Arena state",
      "",
      "- request: admitted",
      "- inspect: evidence bundle included below",
      "- choose-carrier: pending",
      "- mount-projection: pending",
      "- settle-trace: pending",
      "",
      "## Dispatch readiness",
      "",
      ...this.dispatchReadinessLines(),
      "",
      "## Active note context",
      "",
      ...this.activeNoteContextSections(file),
      ...neighborhood,
      "## Cockpit manifest",
      "",
      manifest.stdout.trim(),
      "",
      manifest.stderr.trim() === "" ? "" : ["```text", manifest.stderr.trim(), "```", ""].join("\n"),
      ...bundle,
      "## Recent generated notes",
      "",
      ...this.generatedNoteSummaries(12),
      "",
      "## Next move contract",
      "",
      "Advance this arena by choosing the smallest sufficient package/tool carrier, naming the evidence used, and writing a concrete next action. Do not mutate corpus content without a proposal note and an enabled write gate.",
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, `arena-${this.slug(topic)}.md`, body);
  }

  async advanceActiveArena(file: TFile): Promise<void> {
    const arenaText = await this.app.vault.read(file);
    const topic = await this.topicForFile(file);
    const manifest = await this.runCockpitManifest(true);
    const prompt = [
      `Arena source: ${file.path}`,
      "",
      "Task: advance this cockpit arena exactly one meaningful move.",
      "Return a short state update, the carrier/tool choice, evidence references, and the next concrete action.",
      "If a write is needed, propose it as markdown and explain which gate must be enabled before applying it.",
      "",
      "Arena note:",
      "```markdown",
      arenaText.trim(),
      "```",
      "",
      "Current dispatch readiness:",
      ...this.dispatchReadinessLines(),
      "",
      "Cockpit manifest:",
      manifest.stdout.trim(),
      "",
      "Recent generated notes:",
      ...this.generatedNoteSummaries(12),
    ].join("\n");
    const result = await this.runAgent({ prompt, title: `Arena advance for ${topic}`, json: true });
    const body = [
      "---",
      `title: Arena advance for ${topic}`,
      "tool: obsidian-knowledge-vault",
      "kind: cockpit-arena-advance",
      `source: ${file.path}`,
      `created: ${new Date().toISOString()}`,
      "---",
      "",
      `# Arena advance for ${topic}`,
      "",
      this.resultBlock(result),
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, `arena-advance-${this.slug(file.basename)}.md`, body);
  }

  async listAgentEndpoints(): Promise<void> {
    const result = await this.runAgent({ prompt: "", title: "Ecosystem agent endpoints" }, ["--list"]);
    const body = [
      "---",
      "title: Ecosystem agent endpoints",
      "tool: obsidian-knowledge-vault",
      "kind: agent-endpoint-inventory",
      "---",
      "",
      "# Ecosystem agent endpoints",
      "",
      "```text",
      result.stdout.trim(),
      "```",
      "",
      result.stderr.trim() === "" ? "" : ["```text", result.stderr.trim(), "```", ""].join("\n"),
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, "agent-endpoints.md", body);
  }

  async writeCockpitManifestNote(): Promise<void> {
    const result = await this.runCockpitManifest(true);
    const body = [
      "---",
      "title: Knowledge vault cockpit manifest",
      "tool: obsidian-knowledge-vault",
      "kind: cockpit-manifest",
      "---",
      "",
      result.stdout.trim(),
      "",
      result.stderr.trim() === "" ? "" : ["```text", result.stderr.trim(), "```", ""].join("\n"),
    ].join("\n");
    await this.upsertNote("knowledge-vault-cockpit-manifest.md", body);
  }

  async writeRuntimeSetupNote(): Promise<void> {
    const body = [
      "---",
      "title: Knowledge vault runtime setup",
      "tool: obsidian-knowledge-vault",
      "kind: runtime-setup",
      `created: ${new Date().toISOString()}`,
      "---",
      "",
      "# Knowledge vault runtime setup",
      "",
      "## Runtime status",
      "",
      ...this.runtimeReadinessLines(),
      "",
      "## Dispatch readiness",
      "",
      ...this.dispatchReadinessLines(),
      "",
      "## Packaged install mode",
      "",
      "Leave App root blank when this plugin is installed as a normal Obsidian community plugin. The plugin treats the open Obsidian vault as the content vault and runs the public package runtime through the configured package runner.",
      "",
      "```text",
      `${this.kvSettings.packageRunnerExecutable.trim() || DEFAULT_SETTINGS.packageRunnerExecutable} -y -p ${this.kvSettings.runtimePackage.trim() || DEFAULT_SETTINGS.runtimePackage} <obsidian-knowledge-* command>`,
      "```",
      "",
      "## Local checkout mode",
      "",
      "Set App root to this package directory when developing inside the monorepo. The plugin will use dist/scripts from that checkout before falling back to the public runtime package.",
      "",
      "## Provider keys",
      "",
      "Prefer shell-managed provider keys for normal desktop use. When that is not available, set Agent API key env and Agent API key in plugin settings; the key is injected only into spawned agent runtime processes.",
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, "runtime-setup.md", body);
  }

  async writeRuntimeDoctorNote(): Promise<void> {
    const path = this.pathModule();
    const childProcess = this.childProcessModule();
    const contentRoot = this.resolvedContentRoot(path);
    const runtime = this.runtimeCommand(path, "obsidian-knowledge-vault", "tool.mjs", [
      "inspect-root",
      "--path",
      contentRoot,
    ]);
    const nodeVersion = this.spawnProbe(childProcess, "node --version", {
      command: this.kvSettings.nodeExecutable,
      args: Object.freeze(["--version"]),
      cwd: this.resolvedRepoRoot(path),
    });
    const toolProbe = this.spawnProbe(childProcess, "inspect-root action", runtime);
    const body = [
      "---",
      "title: Knowledge vault runtime doctor",
      "tool: obsidian-knowledge-vault",
      "kind: runtime-doctor",
      `created: ${new Date().toISOString()}`,
      "---",
      "",
      "# Knowledge vault runtime doctor",
      "",
      "## Resolved Runtime",
      "",
      ...this.runtimeReadinessLines(),
      "",
      "## Dispatch Gates",
      "",
      ...this.dispatchReadinessLines(),
      "",
      "## Obsidian Process",
      "",
      `- platform: ${process.platform}`,
      `- execPath: ${process.execPath}`,
      `- cwd: ${process.cwd()}`,
      `- PATH: ${process.env["PATH"] ?? ""}`,
      "",
      "## Probes",
      "",
      this.runtimeDoctorProbeMarkdown(nodeVersion),
      "",
      this.runtimeDoctorProbeMarkdown(toolProbe),
      "",
      "## First Fixes",
      "",
      "- If `node --version` fails, set Knowledge Vault settings -> Node executable to an absolute path such as `C:\\nvm4w\\nodejs\\node.exe`.",
      "- If the inspect-root action cannot find the site content, set Repository root to `C:\\Users\\emsen\\561-group`, App root to `C:\\Users\\emsen\\561-group\\apps\\obsidian-knowledge-vault`, and Content root to `sites/emsenn.net/content`.",
      "- After changing settings, run this doctor again before testing other commands.",
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, "runtime-doctor.md", body);
  }

  async writeCockpitCheckpointNote(): Promise<void> {
    const active = this.activeMarkdownFile();
    const generatedNotes = this.generatedNoteRecords(60);
    const manifest = await this.runCockpitManifest(false);
    const parsed = parseJsonObject(manifest.stdout);
    const benchmark = Array.isArray(parsed?.["benchmark"]) ? parsed["benchmark"].filter(isRecord) : [];
    const next = benchmark
      .map((item) => {
        const id = typeof item["id"] === "string" ? item["id"] : "unknown";
        const nextMove = typeof item["next"] === "string" ? item["next"] : "";
        return nextMove === "" ? "" : `${id}: ${nextMove}`;
      })
      .filter((line) => line !== "")
      .slice(0, 12);
    const checkpointModule = await this.agentCheckpointModule();
    const checkpoint = checkpointModule.sessionCheckpoint({
      session: `obsidian-knowledge-vault-${new Date().toISOString().slice(0, 10)}`,
      title: "Knowledge vault cockpit checkpoint",
      objective: "Meet or beat agentic Obsidian cockpit capabilities while preserving governed vault work.",
      ...(active === null ? {} : { activePath: active.path }),
      readiness: [
        ...this.runtimeReadinessLines(),
        ...this.dispatchReadinessLines(),
      ],
      artifacts: generatedNotes.map((note) => Object.freeze({
        path: note.path,
        ...(note.title === undefined ? {} : { title: note.title }),
        ...(note.kind === undefined ? {} : { kind: note.kind }),
        ...(note.status === undefined ? {} : { status: note.status }),
        ...(note.source === undefined ? {} : { source: note.source }),
        modifiedAt: note.modifiedAt,
      })),
      evidence: [
        `cockpit manifest exit code: ${manifest.code}`,
        `generated artifact count folded: ${generatedNotes.length}`,
        active === null ? "active note: none" : `active note: ${active.path}`,
        "checkpoint carrier: @emsenn/organizing-with-agents/session",
      ],
      suggestedCommands: [
        "pnpm --filter @emsenn/app-obsidian-knowledge-vault check",
        "pnpm --filter @emsenn/app-obsidian-knowledge-vault run package:plugin",
      ],
      next: next.length === 0 ? [
        "Refresh the cockpit audit after adding capabilities.",
        "Advance one admitted arena or create one from the active note.",
      ] : next,
    });
    const body = [
      "---",
      "title: Knowledge vault cockpit checkpoint",
      "tool: obsidian-knowledge-vault",
      "kind: cockpit-checkpoint",
      `created: ${checkpoint.generatedAt}`,
      "---",
      "",
      checkpointModule.renderSessionCheckpointMarkdown(checkpoint),
      "",
      "## Carrier JSON",
      "",
      "```json",
      JSON.stringify(checkpoint, null, 2),
      "```",
      "",
      manifest.stderr.trim() === "" ? "" : ["## Manifest stderr", "", "```text", manifest.stderr.trim(), "```", ""].join("\n"),
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, "cockpit-checkpoint.md", body);
  }

  async writeConnectorSnippetsNote(): Promise<void> {
    const result = await this.runCockpitManifest(false);
    const parsed = parseJsonObject(result.stdout);
    const connectors = Array.isArray(parsed?.["connectors"]) ? parsed["connectors"].filter(isRecord) : [];
    const sections = connectors.flatMap(renderConnectorRegistration);
    const body = [
      "---",
      "title: Knowledge vault connector snippets",
      "tool: obsidian-knowledge-vault",
      "kind: connector-snippets",
      `created: ${new Date().toISOString()}`,
      "---",
      "",
      "# Knowledge vault connector snippets",
      "",
      "## Server",
      "",
      "Start the bridge before using HTTP MCP or OpenAPI clients.",
      "",
      ...(sections.length === 0 ? ["No connector registrations found.", ""] : sections),
      result.stderr.trim() === "" ? "" : ["## Errors", "", "```text", result.stderr.trim(), "```", ""].join("\n"),
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, "connector-snippets.md", body);
  }

  async writeCockpitHandoffNote(): Promise<void> {
    const active = this.activeMarkdownFile();
    const root = await this.runTool({ verb: "inspect-root", stdin: "", title: "Knowledge vault root" });
    const health = root.code === 0
      ? await this.runTool({ verb: "inspect-health", stdin: "", args: ["--limit", "100"], title: "Knowledge vault health" })
      : undefined;
    const manifest = await this.runCockpitManifest(true);
    const activeSection = active === null
      ? ["## Active note", "", "No active markdown note.", ""]
      : [
        "## Active note",
        "",
        `Path: ${active.path}`,
        "",
        ...this.activeNoteContextSections(active),
      ];
    const body = [
      "---",
      "title: Knowledge vault cockpit handoff",
      "tool: obsidian-knowledge-vault",
      "kind: cockpit-handoff",
      `created: ${new Date().toISOString()}`,
      "---",
      "",
      "# Knowledge vault cockpit handoff",
      "",
      "## Dispatch readiness",
      "",
      `Content root: ${this.kvSettings.contentRoot}`,
      `Default region: ${this.kvSettings.defaultRegion}`,
      `Context limit: ${this.kvSettings.contextLimit}`,
      `External content writes: ${this.kvSettings.allowExternalWrites ? "enabled" : "disabled"}`,
      `Note edits: ${this.kvSettings.allowNoteEdits ? "enabled" : "disabled"}`,
      "",
      ...activeSection,
      "## Cockpit manifest",
      "",
      manifest.stdout.trim(),
      "",
      manifest.stderr.trim() === "" ? "" : ["```text", manifest.stderr.trim(), "```", ""].join("\n"),
      "## Root evidence",
      "",
      this.resultBlock(root),
      "",
      "## Health evidence",
      "",
      health === undefined ? "Root inspection failed." : this.resultBlock(health),
      "",
      "## Recent generated notes",
      "",
      ...this.generatedNoteSummaries(20),
      "",
      "## Resume route",
      "",
      "1. Read the active note and generated notes above.",
      "2. Use the manifest to choose the smallest sufficient tool or agent package.",
      "3. Run bounded evidence tools before write-capable moves.",
      "4. Leave proposals and results as ordinary markdown notes.",
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, "cockpit-handoff.md", body);
  }

  async writeCockpitQueueNote(): Promise<void> {
    const notes = this.generatedNoteRecords(200);
    const grouped = groupGeneratedNotes(notes);
    const review = notes.filter((note) => {
      const status = note.status ?? "";
      const kind = note.kind ?? "";
      return status === "proposed" || status === "admitted" || kind === "agent-edit-proposal" || kind === "cockpit-arena";
    });
    const body = [
      "---",
      "title: Knowledge vault cockpit queue",
      "tool: obsidian-knowledge-vault",
      "kind: cockpit-queue",
      `created: ${new Date().toISOString()}`,
      "---",
      "",
      "# Knowledge vault cockpit queue",
      "",
      "## Dispatch readiness",
      "",
      ...this.dispatchReadinessLines(),
      "",
      "## Queue summary",
      "",
      ...grouped,
      "",
      "## Review queue",
      "",
      ...(review.length === 0 ? ["No proposed or admitted cockpit notes found."] : review.map(renderGeneratedNoteRecord)),
      "",
      "## Recent generated notes",
      "",
      ...notes.slice(0, 40).map(renderGeneratedNoteRecord),
      "",
      "## Operating rule",
      "",
      "Review proposed missions, arenas, and edit proposals before enabling write gates. Advance one arena at a time, then refresh this queue.",
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, "cockpit-queue.md", body);
  }

  openCockpitReviewQueue(): void {
    new KnowledgeVaultReviewQueueModal(this.app, this).open();
  }

  async openCockpitQuickSwitcher(): Promise<void> {
    const items = await this.cockpitQuickSwitchItems();
    if (items.length === 0) {
      new Notice("No cockpit quick-switch items found.");
      return;
    }
    new KnowledgeVaultQuickSwitcherModal(this.app, this, items).open();
  }

  async cockpitQuickSwitchItems(): Promise<readonly QuickSwitchItem[]> {
    const items: QuickSwitchItem[] = [];
    const active = this.activeMarkdownFile();
    if (active !== null) {
      const title = await this.topicForFile(active);
      items.push(Object.freeze({
        kind: "active" as const,
        path: active.path,
        title,
        detail: "active note",
      }));
      const neighborhood = await this.activeNoteNeighborhood(active, 32);
      for (const reference of neighborhood.references) {
        items.push(Object.freeze({
          kind: "neighbor" as const,
          path: reference.target,
          title: reference.title ?? reference.target,
          detail: `${reference.relation}; score ${reference.score}; ${reference.reasons.slice(0, 2).join("; ")}`,
          score: reference.score,
        }));
      }
    }
    for (const note of this.generatedNoteRecords(240)) {
      items.push(Object.freeze({
        kind: "generated" as const,
        path: note.path,
        title: note.title ?? note.path.split("/").at(-1) ?? note.path,
        detail: [note.kind ?? "generated", note.status === undefined ? undefined : `status ${note.status}`, note.source === undefined ? undefined : `source ${note.source}`]
          .filter((part) => part !== undefined)
          .join("; "),
      }));
    }
    return Object.freeze(items);
  }

  async openQuickSwitchItem(item: QuickSwitchItem): Promise<void> {
    const file = this.app.vault.getAbstractFileByPath(item.path);
    if (!(file instanceof TFile)) {
      new Notice(`No note found at ${item.path}.`);
      return;
    }
    await this.app.workspace.getLeaf(false).openFile(file);
  }

  reviewQueueRecords(filter: ReviewQueueFilter): readonly GeneratedNoteRecord[] {
    return Object.freeze(this.generatedNoteRecords(300).filter((note) => reviewQueueRecordMatches(note, filter)));
  }

  async openGeneratedNote(path: string): Promise<void> {
    const file = this.app.vault.getAbstractFileByPath(path);
    if (!(file instanceof TFile)) {
      new Notice(`No generated note found at ${path}.`);
      return;
    }
    await this.app.workspace.getLeaf(false).openFile(file);
  }

  async setGeneratedNoteStatus(path: string, status: string): Promise<void> {
    const file = this.app.vault.getAbstractFileByPath(path);
    if (!(file instanceof TFile)) {
      new Notice(`No generated note found at ${path}.`);
      return;
    }
    const text = await this.app.vault.read(file);
    await this.app.vault.process(file, () => setFrontmatterScalar(text, "status", status));
    new Notice(`Marked ${file.basename} ${status}.`);
  }

  async openGeneratedNoteSource(path: string): Promise<void> {
    const note = this.reviewQueueRecords("all").find((record) => record.path === path);
    const sourcePath = note?.source;
    if (sourcePath === undefined || sourcePath.trim() === "") {
      new Notice("Selected generated note has no source.");
      return;
    }
    const file = this.app.vault.getAbstractFileByPath(sourcePath);
    if (!(file instanceof TFile)) {
      new Notice(`No source note found at ${sourcePath}.`);
      return;
    }
    await this.app.workspace.getLeaf(false).openFile(file);
  }

  async approveGeneratedNote(path: string): Promise<void> {
    const file = this.app.vault.getAbstractFileByPath(path);
    if (!(file instanceof TFile)) {
      new Notice(`No generated note found at ${path}.`);
      return;
    }
    const note = this.reviewQueueRecords("all").find((record) => record.path === path);
    const kind = note?.kind ?? "";
    const approvalKey = kind === "agent-edit-receipt" ? "rollbackApproved" : "approved";
    const text = await this.app.vault.read(file);
    const approved = setFrontmatterScalar(setFrontmatterScalar(text, approvalKey, "true"), "status", "approved");
    await this.app.vault.process(file, () => approved);
    new Notice(`Approved ${file.basename}.`);
  }

  async advanceGeneratedArena(path: string): Promise<void> {
    const file = this.app.vault.getAbstractFileByPath(path);
    if (!(file instanceof TFile)) {
      new Notice(`No arena note found at ${path}.`);
      return;
    }
    await this.advanceActiveArena(file);
  }

  async writeCockpitAuditNote(): Promise<void> {
    const manifest = await this.runCockpitManifest(false);
    const manifestMarkdown = await this.runCockpitManifest(true);
    const root = await this.runTool({ verb: "inspect-root", stdin: "", title: "Knowledge vault root" });
    const endpoints = await this.runAgent({ prompt: "", title: "Ecosystem agent endpoints" }, ["--list"]);
    const parsed = parseJsonObject(manifest.stdout);
    const benchmark = Array.isArray(parsed?.["benchmark"]) ? parsed["benchmark"].filter(isRecord) : [];
    const byStatus = (status: string): string[] => benchmark
      .filter((item) => item["status"] === status)
      .map(renderBenchmarkItem);
    const present = byStatus("present");
    const partial = byStatus("partial");
    const gaps = byStatus("gap");
    const body = [
      "---",
      "title: Knowledge vault cockpit capability audit",
      "tool: obsidian-knowledge-vault",
      "kind: cockpit-capability-audit",
      `created: ${new Date().toISOString()}`,
      "---",
      "",
      "# Knowledge vault cockpit capability audit",
      "",
      "## Verdict",
      "",
      `Present: ${present.length}`,
      `Partial: ${partial.length}`,
      `Gap: ${gaps.length}`,
      "",
      "## Present capabilities",
      "",
      ...(present.length === 0 ? ["None recorded."] : present),
      "",
      "## Partial capabilities",
      "",
      ...(partial.length === 0 ? ["None recorded."] : partial),
      "",
      "## Gaps",
      "",
      ...(gaps.length === 0 ? ["None recorded."] : gaps),
      "",
      "## Live root evidence",
      "",
      this.resultBlock(root),
      "",
      "## Live endpoint evidence",
      "",
      "```text",
      endpoints.stdout.trim(),
      "```",
      "",
      endpoints.stderr.trim() === "" ? "" : ["```text", endpoints.stderr.trim(), "```", ""].join("\n"),
      "## Full manifest",
      "",
      manifestMarkdown.stdout.trim(),
      "",
      manifestMarkdown.stderr.trim() === "" ? "" : ["```text", manifestMarkdown.stderr.trim(), "```", ""].join("\n"),
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, "cockpit-capability-audit.md", body);
  }

  async runActiveNoteWithAgent(file: TFile): Promise<void> {
    const selected = this.editorSelection();
    const noteText = selected.trim() === "" ? await this.app.vault.read(file) : selected;
    const topic = await this.topicForFile(file);
    const obsidianContext = this.activeNoteContextSections(file);
    const neighborhood = await this.activeNoteNeighborhoodSections(file, 12);
    const bundle = await this.contextBundle(topic);
    const prompt = [
      `Mission source: ${file.path}`,
      "",
      "Mission:",
      noteText.trim(),
      "",
      obsidianContext.join("\n"),
      "",
      neighborhood.join("\n"),
      "",
      bundle.join("\n"),
    ].join("\n");
    const result = await this.runAgent({ prompt, title: `Agent run for ${topic}`, json: true });
    const body = [
      "---",
      `title: Agent run for ${topic}`,
      "tool: obsidian-knowledge-vault",
      "kind: agent-run",
      `source: ${file.path}`,
      "---",
      "",
      `# Agent run for ${topic}`,
      "",
      this.resultBlock(result),
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, `run-${this.slug(topic)}.md`, body);
  }

  async runPromptWithActiveContext(promptText: string): Promise<void> {
    const prompt = promptText.trim();
    if (prompt === "") {
      new Notice("Enter an agent prompt.");
      return;
    }
    const context = await this.agentPromptForActiveContext(prompt);
    const result = await this.runAgent({
      prompt: context.prompt,
      title: `Agent prompt for ${context.topic}`,
      json: true,
    });
    const body = [
      "---",
      `title: Agent prompt for ${context.topic}`,
      "tool: obsidian-knowledge-vault",
      "kind: agent-prompt-run",
      ...(context.source === undefined ? [] : [`source: ${context.source}`]),
      "---",
      "",
      `# Agent prompt for ${context.topic}`,
      "",
      "## Prompt",
      "",
      prompt,
      "",
      "## Result",
      "",
      this.resultBlock(result),
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, `prompt-${this.slug(context.topic)}.md`, body);
  }

  async agentPromptForActiveContext(prompt: string): Promise<Readonly<{ topic: string; prompt: string; source?: string }>> {
    const file = this.activeMarkdownFile();
    const selected = this.editorSelection();
    const activeText = file === null ? "" : selected.trim() === "" ? await this.app.vault.read(file) : selected;
    const activeNeighborhood = file === null ? [] : await this.activeNoteNeighborhoodSections(file, 12);
    const activeContext = file === null
      ? ["## Active note", "", "No active markdown note.", ""]
      : [
        "## Active note",
        "",
        `Path: ${file.path}`,
        `Scope: ${selected.trim() === "" ? "note" : "selection"}`,
        "",
        "```markdown",
        activeText.trim(),
        "```",
        "",
        ...this.activeNoteContextSections(file),
        ...activeNeighborhood,
      ];
    const topic = file === null ? "knowledge vault" : await this.topicForFile(file);
    const bundle = await this.contextBundle(topic);
    return Object.freeze({
      topic,
      ...(file === null ? {} : { source: file.path }),
      prompt: [
        "User prompt:",
        prompt,
        "",
        activeContext.join("\n"),
        "",
        bundle.join("\n"),
      ].join("\n"),
    });
  }

  async writeChatTranscript(sessionId: string, messages: readonly ChatMessage[], result: ToolResult | undefined): Promise<void> {
    const body = [
      "---",
      `title: Agent chat ${sessionId}`,
      "tool: obsidian-knowledge-vault",
      "kind: agent-chat-session",
      `session: ${sessionId}`,
      `updated: ${new Date().toISOString()}`,
      "---",
      "",
      `# Agent chat ${sessionId}`,
      "",
      "## Conversation",
      "",
      ...messages.flatMap((message) => [
        `### ${message.role}`,
        "",
        message.content.trim(),
        "",
      ]),
      "## Last run",
      "",
      result === undefined ? "No run has completed." : this.resultBlock(result),
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, `chat-${this.slug(sessionId)}.md`, body);
  }

  async proposeActiveNoteEdit(file: TFile): Promise<void> {
    const selected = this.editorSelection();
    const currentText = await this.app.vault.read(file);
    const workingText = selected.trim() === "" ? currentText : selected;
    const topic = await this.topicForFile(file);
    const bundle = await this.contextBundle(topic);
    const neighborhood = await this.activeNoteNeighborhoodSections(file, 12);
    const prompt = [
      `Target note: ${file.path}`,
      "",
      "Task: propose a full replacement for the target note or selected region.",
      "Return concise reasoning first, then a fenced markdown block containing only the proposed replacement.",
      "Do not apply the edit yourself.",
      "",
      "Current text:",
      "```markdown",
      workingText.trim(),
      "```",
      "",
      this.activeNoteContextSections(file).join("\n"),
      "",
      neighborhood.join("\n"),
      "",
      bundle.join("\n"),
    ].join("\n");
    const result = await this.runAgent({ prompt, title: `Edit proposal for ${topic}`, json: true });
    const agentText = agentTextFromResult(result.stdout);
    const replacement = extractMarkdownBlock(agentText);
    const body = [
      "---",
      `title: Edit proposal for ${topic}`,
      "tool: obsidian-knowledge-vault",
      "kind: agent-edit-proposal",
      `source: ${file.path}`,
      "status: proposed",
      `appliesTo: ${selected.trim() === "" ? "note" : "selection"}`,
      "reviewed: false",
      "approved: false",
      "---",
      "",
      `# Edit proposal for ${topic}`,
      "",
      "## Source",
      "",
      file.path,
      "",
      "## Agent result",
      "",
      this.resultBlock(result),
      "",
      "## Proposed replacement",
      "",
      "```markdown",
      replacement.trim(),
      "```",
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, this.editProposalFilename(file), body);
  }

  async previewActiveNoteEditProposalDiff(file: TFile): Promise<void> {
    const proposalPath = this.editProposalPath(file);
    const proposalFile = this.app.vault.getAbstractFileByPath(proposalPath);
    if (!(proposalFile instanceof TFile)) {
      new Notice(`No proposal note found at ${proposalPath}.`);
      return;
    }
    const proposalText = await this.app.vault.read(proposalFile);
    const replacement = extractMarkdownBlockAfterHeading(proposalText, "Proposed replacement");
    if (replacement.trim() === "") {
      new Notice("Proposal note has no proposed replacement block.");
      return;
    }
    const appliesTo = proposalFrontMatterValue(proposalText, "appliesTo") ?? "note";
    const original = await this.proposalOriginalText(file, appliesTo);
    if (original === null) return;
    const replacementText = appliesTo === "selection" ? replacement.trimEnd() : replacement.trimEnd() + "\n";
    const review = await this.agentReviewModule();
    const diff = review.editProposalDiff({
      source: file.path,
      proposal: proposalPath,
      appliesTo: this.agentEditTarget(appliesTo),
      original,
      proposed: replacementText,
    });
    const diffFilename = `edit-proposal-diff-${this.slug(file.basename)}.md`;
    const body = [
      "---",
      `title: Edit proposal diff for ${file.basename}`,
      "tool: obsidian-knowledge-vault",
      "kind: agent-edit-proposal-diff",
      `source: ${file.path}`,
      `proposal: ${proposalPath}`,
      "status: review",
      "approved: false",
      `additions: ${diff.additions}`,
      `deletions: ${diff.deletions}`,
      "---",
      "",
      `# Edit proposal diff for ${file.basename}`,
      "",
      "## Approval",
      "",
      `Proposal note: [[${proposalFile.basename}]]`,
      "",
      "Set `approved: true` in the proposal note frontmatter before applying.",
      "",
      "## Diff",
      "",
      "```diff",
      diff.text,
      "```",
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, diffFilename, body);
    new Notice(`Wrote edit proposal diff for ${file.path}.`);
  }

  async applyActiveNoteEditProposal(file: TFile): Promise<void> {
    if (!this.kvSettings.allowNoteEdits) {
      new Notice("Enable note edits in Knowledge Vault settings before applying proposals.");
      return;
    }
    const proposalPath = this.editProposalPath(file);
    const proposalFile = this.app.vault.getAbstractFileByPath(proposalPath);
    if (!(proposalFile instanceof TFile)) {
      new Notice(`No proposal note found at ${proposalPath}.`);
      return;
    }
    const proposalText = await this.app.vault.read(proposalFile);
    const replacement = extractMarkdownBlockAfterHeading(proposalText, "Proposed replacement");
    if (replacement.trim() === "") {
      new Notice("Proposal note has no proposed replacement block.");
      return;
    }
    const review = await this.agentReviewModule();
    if (!review.approvalValueApproved(proposalFrontMatterValue(proposalText, "approved") ?? proposalFrontMatterValue(proposalText, "approval"))) {
      new Notice("Set approved: true in the proposal note before applying it.");
      return;
    }
    const appliesTo = proposalFrontMatterValue(proposalText, "appliesTo") ?? "note";
    if (appliesTo === "selection") {
      const view = this.app.workspace.getActiveViewOfType(MarkdownView);
      if (view === null || view.file?.path !== file.path) {
        new Notice("Open the proposal source note before applying a selection proposal.");
        return;
      }
      const before = view.editor.getSelection();
      if (before.trim() === "") {
        new Notice("Select the target text before applying a selection proposal.");
        return;
      }
      const after = replacement.trimEnd();
      view.editor.replaceSelection(after);
      await this.writeEditReceipt(file, proposalPath, appliesTo, before, after);
      new Notice(`Applied selection edit proposal to ${file.path}.`);
      return;
    }
    const before = await this.app.vault.read(file);
    const after = replacement.trimEnd() + "\n";
    await this.app.vault.process(file, () => after);
    await this.writeEditReceipt(file, proposalPath, appliesTo, before, after);
    await this.app.workspace.getLeaf(false).openFile(file);
    new Notice(`Applied edit proposal to ${file.path}.`);
  }

  async restoreActiveNoteFromEditReceipt(file: TFile): Promise<void> {
    if (!this.kvSettings.allowNoteEdits) {
      new Notice("Enable note edits in Knowledge Vault settings before restoring receipts.");
      return;
    }
    const receipts = await this.editReceiptsFor(file);
    if (receipts.length === 0) {
      new Notice(`No edit receipts found for ${file.path}.`);
      return;
    }
    if (receipts.length === 1) {
      await this.restoreActiveNoteFromReceiptFile(file, receipts[0]!.file);
      return;
    }
    new KnowledgeVaultReceiptModal(this.app, this, file, receipts).open();
  }

  async restoreActiveNoteFromReceiptFile(file: TFile, receiptFile: TFile): Promise<void> {
    const receiptText = await this.app.vault.read(receiptFile);
    const review = await this.agentReviewModule();
    if (!review.approvalValueApproved(proposalFrontMatterValue(receiptText, "rollbackApproved"))) {
      new Notice(`Set rollbackApproved: true in ${receiptFile.path} before restoring it.`);
      return;
    }
    const rollback = extractMarkdownBlockAfterHeading(receiptText, "Previous content");
    if (rollback.trim() === "") {
      new Notice("Edit receipt has no previous content block.");
      return;
    }
    const appliesTo = proposalFrontMatterValue(receiptText, "appliesTo") ?? "note";
    if (appliesTo === "selection") {
      const view = this.app.workspace.getActiveViewOfType(MarkdownView);
      if (view === null || view.file?.path !== file.path) {
        new Notice("Open the receipt source note before restoring a selection receipt.");
        return;
      }
      if (view.editor.getSelection().trim() === "") {
        new Notice("Select the changed text before restoring a selection receipt.");
        return;
      }
      view.editor.replaceSelection(rollback.trimEnd());
      new Notice(`Restored selection edit receipt ${receiptFile.basename} to ${file.path}.`);
      return;
    }
    await this.app.vault.process(file, () => rollback.trimEnd() + "\n");
    await this.app.workspace.getLeaf(false).openFile(file);
    new Notice(`Restored edit receipt ${receiptFile.basename} to ${file.path}.`);
  }

  activeMarkdownFile(): TFile | null {
    const file = this.app.workspace.getActiveFile();
    if (file instanceof TFile && file.extension === "md") return file;
    return null;
  }

  async writeToolNote(request: ToolRequest): Promise<void> {
    const result = await this.runTool(request);
    const slug = this.slug(request.title);
    const body = [
      "---",
      `title: ${request.title}`,
      "tool: obsidian-knowledge-vault",
      `verb: ${request.verb}`,
      "---",
      "",
      `# ${request.title}`,
      "",
      this.resultBlock(result),
      "",
    ].join("\n");
    await this.upsertNote(`${slug}.md`, body);
  }

  async runTool(request: ToolRequest): Promise<ToolResult> {
    const path = this.pathModule();
    const childProcess = this.childProcessModule();
    const contentRoot = this.resolvedContentRoot(path);
    const runtime = this.runtimeCommand(path, "obsidian-knowledge-vault", "tool.mjs", [
      request.verb,
      "--path",
      contentRoot,
      ...(request.args ?? []),
    ]);
    const result = childProcess.spawnSync(runtime.command, runtime.args, {
      cwd: runtime.cwd,
      input: request.stdin,
      encoding: "utf8",
      maxBuffer: 1024 * 1024 * 20,
      windowsHide: true,
    });
    const code = result.status ?? (result.error === undefined ? 0 : 1);
    if (code === 0) {
      new Notice(`${request.title} complete`);
    } else {
      new Notice(`${request.title} failed; see the generated note`);
    }
    return Object.freeze({
      code,
      stdout: result.stdout ?? "",
      stderr: result.stderr ?? (result.error === undefined ? "" : result.error.message),
    });
  }

  private spawnProbe(childProcess: ChildProcessModule, label: string, runtime: RuntimeCommand): RuntimeDoctorProbe {
    const result = childProcess.spawnSync(runtime.command, runtime.args, {
      cwd: runtime.cwd,
      encoding: "utf8",
      maxBuffer: 1024 * 1024 * 20,
      windowsHide: true,
    });
    return Object.freeze({
      label,
      command: runtime.command,
      args: runtime.args,
      cwd: runtime.cwd,
      code: result.status ?? (result.error === undefined ? 0 : 1),
      stdout: result.stdout ?? "",
      stderr: result.stderr ?? (result.error === undefined ? "" : result.error.message),
    });
  }

  private runtimeDoctorProbeMarkdown(probe: RuntimeDoctorProbe): string {
    return [
      `### ${probe.label}`,
      "",
      `- code: ${probe.code}`,
      `- cwd: \`${probe.cwd}\``,
      `- command: \`${[probe.command, ...probe.args].join(" ")}\``,
      "",
      "#### stdout",
      "",
      "```text",
      probe.stdout.trim(),
      "```",
      "",
      "#### stderr",
      "",
      "```text",
      probe.stderr.trim(),
      "```",
    ].join("\n");
  }

  async runAgent(request: AgentRequest, extraArgs: readonly string[] = []): Promise<ToolResult> {
    const path = this.pathModule();
    const childProcess = this.childProcessModule();
    const runtime = this.runtimeCommand(path, "obsidian-knowledge-agent", "agent.mjs", [
      ...this.agentCliArgs(request),
      ...extraArgs,
    ]);
    const result = childProcess.spawnSync(runtime.command, runtime.args, {
      cwd: runtime.cwd,
      input: request.prompt,
      encoding: "utf8",
      env: this.agentProcessEnv(),
      maxBuffer: 1024 * 1024 * 20,
      windowsHide: true,
    });
    const code = result.status ?? (result.error === undefined ? 0 : 1);
    if (code === 0) new Notice(`${request.title} complete`);
    else new Notice(`${request.title} failed; see the generated note`);
    return Object.freeze({
      code,
      stdout: result.stdout ?? "",
      stderr: result.stderr ?? (result.error === undefined ? "" : result.error.message),
    });
  }

  startLiveAgentRun(
    request: AgentRequest,
    onChunk: (chunk: Readonly<{ stream: "stdout" | "stderr"; text: string }>) => void,
  ): LiveAgentRun {
    const path = this.pathModule();
    const childProcess = this.childProcessModule();
    const runtime = this.runtimeCommand(path, "obsidian-knowledge-agent", "agent.mjs", [
      ...this.agentCliArgs(request),
    ]);
    const child = childProcess.spawn(runtime.command, runtime.args, {
      cwd: runtime.cwd,
      env: this.agentProcessEnv(),
      windowsHide: true,
      stdio: ["pipe", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout?.setEncoding("utf8");
    child.stderr?.setEncoding("utf8");
    child.stdout?.on("data", (chunk: string) => {
      stdout += chunk;
      onChunk({ stream: "stdout", text: chunk });
    });
    child.stderr?.on("data", (chunk: string) => {
      stderr += chunk;
      onChunk({ stream: "stderr", text: chunk });
    });
    child.stdin?.end(request.prompt);
    const promise = new Promise<ToolResult>((resolve) => {
      child.on("error", (error) => {
        resolve(Object.freeze({ code: 1, stdout, stderr: `${stderr}${error.message}\n` }));
      });
      child.on("close", (code, signal) => {
        const exitCode = signal === null ? code ?? 0 : 130;
        resolve(Object.freeze({
          code: exitCode,
          stdout,
          stderr: signal === null ? stderr : `${stderr}stopped by ${signal}\n`,
        }));
      });
    });
    return Object.freeze({
      stop: () => child.kill(),
      promise,
    });
  }

  private agentCliArgs(request: AgentRequest): readonly string[] {
    const endpointArgs = this.kvSettings.agentEndpoint.trim() === "" ? [] : ["--endpoint", this.kvSettings.agentEndpoint.trim()];
    const modelArgs = this.kvSettings.agentModel.trim() === "" ? [] : ["--model", this.kvSettings.agentModel.trim()];
    const systemArgs = this.kvSettings.agentSystem.trim() === "" ? [] : ["--system", this.kvSettings.agentSystem.trim()];
    const sessionArgs = request.session === undefined || request.session.trim() === "" ? [] : ["--session", request.session.trim()];
    const conversationArgs = request.conversation === undefined || request.conversation.length === 0 ? [] : ["--conversation-json", JSON.stringify(request.conversation)];
    return Object.freeze([
      ...endpointArgs,
      ...modelArgs,
      ...systemArgs,
      ...sessionArgs,
      ...conversationArgs,
      ...(request.stream === true ? ["--stream"] : []),
      ...(request.json === true ? ["--json"] : []),
    ]);
  }

  private agentProcessEnv(): NodeJS.ProcessEnv {
    const keyName = this.kvSettings.agentApiKeyEnv.trim();
    const keyValue = this.kvSettings.agentApiKey.trim();
    return keyName === "" || keyValue === "" ? process.env : { ...process.env, [keyName]: keyValue };
  }

  async runCockpitManifest(markdown: boolean): Promise<ToolResult> {
    const path = this.pathModule();
    const childProcess = this.childProcessModule();
    const runtime = this.runtimeCommand(path, "obsidian-knowledge-cockpit", "cockpit.mjs", markdown ? ["--markdown"] : []);
    const result = childProcess.spawnSync(runtime.command, runtime.args, {
      cwd: runtime.cwd,
      encoding: "utf8",
      maxBuffer: 1024 * 1024 * 20,
      windowsHide: true,
    });
    const code = result.status ?? (result.error === undefined ? 0 : 1);
    return Object.freeze({
      code,
      stdout: result.stdout ?? "",
      stderr: result.stderr ?? (result.error === undefined ? "" : result.error.message),
    });
  }

  private resultBlock(result: ToolResult): string {
    const stderr = result.stderr.trim();
    const stdout = result.stdout.trim();
    const blocks = [
      `Exit code: ${result.code}`,
      "",
      "```json",
      stdout === "" ? "{}" : stdout,
      "```",
    ];
    if (stderr !== "") {
      blocks.push("", "```text", stderr, "```");
    }
    return blocks.join("\n");
  }

  private async contextBundle(topic: string): Promise<string[]> {
    const limit = String(this.kvSettings.contextLimit);
    const region = this.kvSettings.defaultRegion.trim() === "" ? "content" : this.kvSettings.defaultRegion.trim();
    const requests: readonly ToolRequest[] = Object.freeze([
      { verb: "inspect-root", stdin: "", title: "Root" },
      { verb: "find-name", stdin: topic, args: ["--region", region, "--limit", limit], title: "Name matches" },
      { verb: "grep-text", stdin: topic, args: ["--region", region, "--limit", limit], title: "Text matches" },
      { verb: "topic-guidance", stdin: topic, args: ["--region", region, "--limit", limit], title: "Topic guidance" },
      { verb: "concept-map", stdin: topic, args: ["--region", region, "--limit", limit], title: "Concept map" },
      { verb: "measure-gap", stdin: topic, args: ["--region", region, "--limit", limit], title: "Gap measurement" },
    ]);
    const sections: string[] = ["## Tool evidence", ""];
    for (const request of requests) {
      sections.push(`### ${request.title}`, "", this.resultBlock(await this.runTool(request)), "");
    }
    sections.push("## Available cockpit tools", "", ...COCKPIT_ACTIONS.map((action) => `- ${action}`), "");
    return sections;
  }

  private generatedNoteSummaries(limit: number): string[] {
    const notes = this.generatedNoteRecords(limit);
    if (notes.length === 0) return ["No generated cockpit notes found."];
    return notes.map(renderGeneratedNoteRecord);
  }

  private generatedNoteRecords(limit: number): readonly GeneratedNoteRecord[] {
    const folders = new Set([
      normalizePath(this.kvSettings.outputFolder || DEFAULT_SETTINGS.outputFolder),
      normalizePath(this.kvSettings.agentFolder || DEFAULT_SETTINGS.agentFolder),
    ]);
    return this.app.vault.getMarkdownFiles()
      .filter((file) => [...folders].some((folder) => file.path === folder || file.path.startsWith(`${folder}/`)))
      .sort((left, right) => right.stat.mtime - left.stat.mtime)
      .slice(0, limit)
      .map((file) => {
        const frontmatter = this.app.metadataCache.getFileCache(file)?.frontmatter;
        return Object.freeze({
          path: file.path,
          modifiedAt: new Date(file.stat.mtime).toISOString(),
          title: frontmatterScalar(frontmatter, "title"),
          kind: frontmatterScalar(frontmatter, "kind"),
          status: frontmatterScalar(frontmatter, "status"),
          source: frontmatterScalar(frontmatter, "source"),
          verb: frontmatterScalar(frontmatter, "verb"),
        });
      });
  }

  runtimeReadinessLines(): string[] {
    const path = this.pathModule();
    const hasLocalRuntime = this.hasLocalRuntime(path);
    return [
      `- runtime mode: ${hasLocalRuntime ? "local app dist" : "public npm package"}`,
      `- plugin directory: ${this.pluginDirectory(path)}`,
      `- app root: ${this.resolvedAppRoot(path)}`,
      `- repo root: ${this.resolvedRepoRoot(path)}`,
      `- content root: ${this.resolvedContentRoot(path)}`,
      `- node executable: ${this.kvSettings.nodeExecutable}`,
      `- package runner: ${this.kvSettings.packageRunnerExecutable.trim() || DEFAULT_SETTINGS.packageRunnerExecutable}`,
      `- runtime package: ${this.kvSettings.runtimePackage.trim() || DEFAULT_SETTINGS.runtimePackage}`,
      `- agent API key override: ${this.kvSettings.agentApiKey.trim() === "" ? "absent" : `present via ${this.kvSettings.agentApiKeyEnv.trim() || "unnamed env var"}`}`,
    ];
  }

  private dispatchReadinessLines(): string[] {
    return [
      `- content root: ${this.kvSettings.contentRoot}`,
      `- default region: ${this.kvSettings.defaultRegion}`,
      `- context limit: ${this.kvSettings.contextLimit}`,
      `- external content writes: ${this.kvSettings.allowExternalWrites ? "enabled" : "disabled"}`,
      `- note edits: ${this.kvSettings.allowNoteEdits ? "enabled" : "disabled"}`,
      `- runtime package: ${this.kvSettings.runtimePackage.trim() || DEFAULT_SETTINGS.runtimePackage}`,
      `- package runner: ${this.kvSettings.packageRunnerExecutable.trim() || DEFAULT_SETTINGS.packageRunnerExecutable}`,
      `- agent endpoint override: ${this.kvSettings.agentEndpoint.trim() === "" ? "auto" : this.kvSettings.agentEndpoint.trim()}`,
      `- agent model override: ${this.kvSettings.agentModel.trim() === "" ? "default" : this.kvSettings.agentModel.trim()}`,
      `- agent API key override: ${this.kvSettings.agentApiKey.trim() === "" ? "absent" : `present via ${this.kvSettings.agentApiKeyEnv.trim() || "unnamed env var"}`}`,
    ];
  }

  async upsertNote(filename: string, body: string): Promise<void> {
    await this.upsertNoteInFolder(this.kvSettings.outputFolder || DEFAULT_SETTINGS.outputFolder, filename, body);
  }

  private async upsertNoteInFolder(folderName: string, filename: string, body: string): Promise<void> {
    const folder = normalizePath(folderName);
    await this.ensureFolder(folder);
    const target = normalizePath(`${folder}/${filename}`);
    const existing = this.app.vault.getAbstractFileByPath(target);
    if (existing instanceof TFile) {
      await this.app.vault.process(existing, () => body);
      await this.app.workspace.getLeaf(false).openFile(existing);
      return;
    }
    const created = await this.app.vault.create(target, body);
    await this.app.workspace.getLeaf(false).openFile(created);
  }

  async topicForFile(file: TFile): Promise<string> {
    const cache = this.app.metadataCache.getFileCache(file);
    const title = cache?.frontmatter?.["title"];
    if (typeof title === "string" && title.trim() !== "") return title.trim();
    return file.basename.replaceAll("-", " ");
  }

  activeNoteContextSections(file: TFile): string[] {
    const cache = this.app.metadataCache.getFileCache(file);
    const frontmatter = cache?.frontmatter;
    const frontmatterKeys = frontmatter === undefined ? [] : Object.keys(frontmatter).filter((key) => key !== "position").sort();
    const tags = new Set<string>();
    for (const tag of cache?.tags ?? []) tags.add(tag.tag);
    const outlinks = new Set<string>();
    for (const link of cache?.links ?? []) outlinks.add(link.link);
    const resolvedBacklinks = Object.entries(this.app.metadataCache.resolvedLinks)
      .filter(([, targets]) => targets[file.path] !== undefined)
      .map(([source]) => source)
      .sort();
    const unresolved = Object.entries(this.app.metadataCache.unresolvedLinks[file.path] ?? {})
      .map(([target, count]) => `${target} (${count})`)
      .sort();
    return [
      "## Obsidian graph context",
      "",
      `Frontmatter keys: ${frontmatterKeys.length === 0 ? "none" : frontmatterKeys.join(", ")}`,
      `Tags: ${tags.size === 0 ? "none" : [...tags].sort().join(", ")}`,
      `Outlinks: ${outlinks.size === 0 ? "none" : [...outlinks].sort().join(", ")}`,
      `Resolved backlinks: ${resolvedBacklinks.length === 0 ? "none" : resolvedBacklinks.join(", ")}`,
      `Unresolved links from this note: ${unresolved.length === 0 ? "none" : unresolved.join(", ")}`,
      "",
    ];
  }

  async activeNoteNeighborhoodSections(file: TFile, limit: number): Promise<string[]> {
    return this.renderNeighborhoodSections(await this.activeNoteNeighborhood(file, limit));
  }

  async activeNoteNeighborhood(file: TFile, limit: number): Promise<AgentContextNeighborhood> {
    const context = await this.agentContextModule();
    const cache = this.app.metadataCache.getFileCache(file);
    const sourceTags = new Set((cache?.tags ?? []).map((tag) => tag.tag));
    const references: AgentContextReference[] = [];
    const addResolved = async (
      target: TFile,
      relation: AgentContextRelation,
      score: number,
      reasons: readonly string[],
    ): Promise<void> => {
      if (target.path === file.path) return;
      references.push(context.agentContextReference({
        source: file.path,
        target: target.path,
        relation,
        score,
        reasons,
        ...(await this.contextReferenceMetadata(target)),
      }));
    };
    for (const link of cache?.links ?? []) {
      const target = this.app.metadataCache.getFirstLinkpathDest(link.link, file.path);
      if (target instanceof TFile) {
        await addResolved(target, "outlink", 8, [`outlink: ${link.link}`]);
      } else {
        references.push(context.agentContextReference({
          source: file.path,
          target: link.link,
          relation: "unresolved",
          score: 2,
          reasons: [`unresolved outlink: ${link.link}`],
        }));
      }
    }
    const resolvedBacklinks = Object.entries(this.app.metadataCache.resolvedLinks)
      .filter(([, targets]) => targets[file.path] !== undefined)
      .map(([source]) => source)
      .sort();
    for (const sourcePath of resolvedBacklinks) {
      const target = this.app.vault.getAbstractFileByPath(sourcePath);
      if (target instanceof TFile) await addResolved(target, "backlink", 7, [`backlink count: ${this.app.metadataCache.resolvedLinks[sourcePath]?.[file.path] ?? 1}`]);
    }
    if (sourceTags.size > 0) {
      for (const candidate of this.app.vault.getMarkdownFiles()) {
        if (candidate.path === file.path) continue;
        const candidateTags = new Set((this.app.metadataCache.getFileCache(candidate)?.tags ?? []).map((tag) => tag.tag));
        const shared = [...sourceTags].filter((tag) => candidateTags.has(tag)).sort();
        if (shared.length > 0) await addResolved(candidate, "tag", 3 + shared.length, [`shared tags: ${shared.join(", ")}`]);
      }
    }
    for (const candidate of this.app.vault.getMarkdownFiles()
      .filter((candidate) => candidate.path !== file.path && candidate.parent?.path === file.parent?.path)
      .sort((left, right) => right.stat.mtime - left.stat.mtime)
      .slice(0, 8)) {
      await addResolved(candidate, "recent", 1.5, [`same folder recent note: ${candidate.parent?.path ?? "/"}`]);
    }
    references.push(...await this.canvasContextReferences(file, context));
    return context.rankAgentContextNeighborhood({
      source: file.path,
      references: Object.freeze(references),
      limit,
    });
  }

  renderNeighborhoodSections(neighborhood: AgentContextNeighborhood): string[] {
    const lines = [
      "## Local graph neighborhood",
      "",
      `Generated: ${neighborhood.generatedAt}`,
      `References: ${neighborhood.references.length}`,
      "",
    ];
    if (neighborhood.references.length === 0) {
      lines.push("No local graph neighbors found.", "");
      return lines;
    }
    for (const reference of neighborhood.references) {
      lines.push(
        `### ${reference.title ?? reference.target}`,
        "",
        `- path: ${reference.target}`,
        `- relation: ${reference.relation}`,
        `- score: ${Number(reference.score.toFixed(2))}`,
        `- reasons: ${reference.reasons.join("; ")}`,
        ...(reference.modifiedAt === undefined ? [] : [`- modified: ${reference.modifiedAt}`]),
        "",
      );
      if (reference.preview !== undefined && reference.preview.trim() !== "") {
        lines.push("```markdown", reference.preview.trim(), "```", "");
      }
    }
    return lines;
  }

  private async canvasContextReferences(file: TFile, context: AgentContextModule): Promise<readonly AgentContextReference[]> {
    const references: AgentContextReference[] = [];
    const canvasFiles = this.app.vault.getFiles()
      .filter((candidate) => candidate.extension === "canvas")
      .sort((left, right) => left.path.localeCompare(right.path));
    for (const canvasFile of canvasFiles) {
      const graph = await this.readCanvasGraph(canvasFile);
      if (graph === null) continue;
      const fileNodes = graph.nodes.filter((node) => node.type === "file" && typeof node.file === "string");
      const activeNodes = fileNodes.filter((node) => this.canvasNodeTargetsFile(node, file));
      if (activeNodes.length === 0) continue;
      const activeIds = new Set(activeNodes.map((node) => node.id));
      references.push(context.agentContextReference({
        source: file.path,
        target: canvasFile.path,
        relation: "canvas",
        score: 6 + activeNodes.length,
        reasons: [`canvas contains active note: ${canvasFile.path}`],
        title: canvasFile.basename,
        preview: this.canvasPreview(graph, activeIds),
        modifiedAt: new Date(canvasFile.stat.mtime).toISOString(),
      }));
      const connectedIds = new Set<string>();
      for (const edge of graph.edges) {
        if (activeIds.has(edge.fromNode)) connectedIds.add(edge.toNode);
        if (activeIds.has(edge.toNode)) connectedIds.add(edge.fromNode);
      }
      for (const node of graph.nodes) {
        if (activeIds.has(node.id)) continue;
        const connected = connectedIds.has(node.id);
        const score = connected ? 9 : 4;
        const reason = connected
          ? `connected on canvas ${canvasFile.path}`
          : `shares canvas ${canvasFile.path}`;
        if (node.type === "file" && typeof node.file === "string") {
          const target = this.resolveCanvasFileNode(node, file.path);
          if (target instanceof TFile) {
            references.push(context.agentContextReference({
              source: file.path,
              target: target.path,
              relation: "canvas",
              score,
              reasons: [reason],
              ...(await this.contextReferenceMetadata(target)),
            }));
          } else {
            references.push(context.agentContextReference({
              source: file.path,
              target: node.file,
              relation: "canvas",
              score: Math.max(1, score - 2),
              reasons: [`${reason}; unresolved canvas file node`],
            }));
          }
        } else if ((node.type === "text" || node.type === "group") && typeof node.text === "string" && node.text.trim() !== "") {
          references.push(context.agentContextReference({
            source: file.path,
            target: `${canvasFile.path}#${node.id}`,
            relation: "canvas",
            score: Math.max(2, score - 1),
            reasons: [reason],
            title: `${canvasFile.basename} canvas ${node.type}`,
            preview: node.text.trim().slice(0, 360),
            modifiedAt: new Date(canvasFile.stat.mtime).toISOString(),
          }));
        }
      }
    }
    return Object.freeze(references);
  }

  private async readCanvasGraph(file: TFile): Promise<CanvasGraph | null> {
    try {
      const parsed = JSON.parse(await this.app.vault.cachedRead(file)) as unknown;
      if (!isRecord(parsed)) return null;
      const nodes = Array.isArray(parsed["nodes"]) ? parsed["nodes"].map(canvasNode).filter((node): node is CanvasNode => node !== null) : [];
      const edges = Array.isArray(parsed["edges"]) ? parsed["edges"].map(canvasEdge).filter((edge): edge is CanvasEdge => edge !== null) : [];
      return Object.freeze({ nodes: Object.freeze(nodes), edges: Object.freeze(edges) });
    } catch {
      return null;
    }
  }

  private canvasNodeTargetsFile(node: CanvasNode, file: TFile): boolean {
    if (typeof node.file !== "string") return false;
    const target = this.resolveCanvasFileNode(node, file.path);
    return target instanceof TFile && target.path === file.path;
  }

  private resolveCanvasFileNode(node: CanvasNode, sourcePath: string): TFile | null {
    if (typeof node.file !== "string" || node.file.trim() === "") return null;
    const normalized = normalizePath(node.file.trim());
    const direct = this.app.vault.getAbstractFileByPath(normalized);
    if (direct instanceof TFile) return direct;
    return this.app.metadataCache.getFirstLinkpathDest(normalized, sourcePath);
  }

  private canvasPreview(graph: CanvasGraph, activeIds: ReadonlySet<string>): string {
    const connectedIds = new Set<string>();
    for (const edge of graph.edges) {
      if (activeIds.has(edge.fromNode)) connectedIds.add(edge.toNode);
      if (activeIds.has(edge.toNode)) connectedIds.add(edge.fromNode);
    }
    const nodeLines = graph.nodes
      .filter((node) => activeIds.has(node.id) || connectedIds.has(node.id))
      .slice(0, 12)
      .map((node) => {
        const label = node.file ?? node.text ?? node.url ?? node.label ?? node.id;
        return `- ${node.type}: ${label}`.slice(0, 220);
      });
    return nodeLines.join("\n");
  }

  private async contextReferenceMetadata(file: TFile): Promise<Readonly<{
    title?: string;
    preview?: string;
    modifiedAt: string;
  }>> {
    const frontmatter = this.app.metadataCache.getFileCache(file)?.frontmatter;
    const title = frontmatterScalar(frontmatter, "title") ?? file.basename.replaceAll("-", " ");
    const text = await this.app.vault.cachedRead(file);
    const preview = text
      .replace(/^---[\s\S]*?---\s*/u, "")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line !== "" && !line.startsWith("#"))
      .join(" ")
      .slice(0, 360);
    return Object.freeze({
      title,
      preview,
      modifiedAt: new Date(file.stat.mtime).toISOString(),
    });
  }

  private editorSelection(): string {
    const view = this.app.workspace.getActiveViewOfType(MarkdownView);
    return view?.editor.getSelection() ?? "";
  }

  private slug(value: string): string {
    return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "knowledge-vault";
  }

  private editProposalFilename(file: TFile): string {
    return `edit-proposal-${this.slug(file.basename)}.md`;
  }

  private editProposalPath(file: TFile): string {
    return normalizePath(`${this.kvSettings.agentFolder}/${this.editProposalFilename(file)}`);
  }

  private editReceiptFilename(file: TFile, appliedAt: string): string {
    return `edit-receipt-${this.slug(file.basename)}-${receiptTimestamp(appliedAt)}.md`;
  }

  private legacyEditReceiptPath(file: TFile): string {
    return normalizePath(`${this.kvSettings.agentFolder}/edit-receipt-${this.slug(file.basename)}.md`);
  }

  private async writeEditReceipt(
    file: TFile,
    proposalPath: string,
    appliesTo: string,
    before: string,
    after: string,
  ): Promise<void> {
    const review = await this.agentReviewModule();
    const receipt = review.editApplyReceipt({
      source: file.path,
      proposal: proposalPath,
      appliesTo: this.agentEditTarget(appliesTo),
      before,
      after,
    });
    const body = [
      "---",
      `title: Edit receipt for ${file.basename}`,
      "tool: obsidian-knowledge-vault",
      "kind: agent-edit-apply-receipt",
      `source: ${receipt.source}`,
      `proposal: ${receipt.proposal}`,
      `appliesTo: ${receipt.appliesTo}`,
      `appliedAt: ${receipt.appliedAt}`,
      "status: applied",
      "rollbackApproved: false",
      "---",
      "",
      `# Edit receipt for ${file.basename}`,
      "",
      "## Restore gate",
      "",
      "Set `rollbackApproved: true` in this receipt frontmatter before restoring.",
      "",
      "## Previous content",
      "",
      "```markdown",
      receipt.before.trimEnd(),
      "```",
      "",
      "## Applied content",
      "",
      "```markdown",
      receipt.after.trimEnd(),
      "```",
      "",
    ].join("\n");
    await this.upsertNoteInFolder(this.kvSettings.agentFolder, this.editReceiptFilename(file, receipt.appliedAt), body);
  }

  private async editReceiptsFor(file: TFile): Promise<readonly EditReceiptSummary[]> {
    const folder = normalizePath(this.kvSettings.agentFolder);
    const prefix = normalizePath(`${folder}/edit-receipt-${this.slug(file.basename)}`);
    const legacyPath = this.legacyEditReceiptPath(file);
    const receipts: EditReceiptSummary[] = [];
    const review = await this.agentReviewModule();
    for (const candidate of this.app.vault.getMarkdownFiles()) {
      if (candidate.path !== legacyPath && !candidate.path.startsWith(prefix)) continue;
      const text = await this.app.vault.cachedRead(candidate);
      if (proposalFrontMatterValue(text, "kind") !== "agent-edit-apply-receipt") continue;
      if (proposalFrontMatterValue(text, "source") !== file.path) continue;
      const appliedAt = proposalFrontMatterValue(text, "appliedAt") ?? new Date(candidate.stat.mtime).toISOString();
      receipts.push(Object.freeze({
        file: candidate,
        path: candidate.path,
        appliedAt,
        appliesTo: proposalFrontMatterValue(text, "appliesTo") ?? "note",
        proposal: proposalFrontMatterValue(text, "proposal"),
        rollbackApproved: review.approvalValueApproved(proposalFrontMatterValue(text, "rollbackApproved")),
        modifiedAt: new Date(candidate.stat.mtime).toISOString(),
      }));
    }
    return Object.freeze(receipts.sort((left, right) => right.appliedAt.localeCompare(left.appliedAt) || right.modifiedAt.localeCompare(left.modifiedAt)));
  }

  private agentEditTarget(value: string): AgentEditTarget {
    if (value === "selection" || value === "region" || value === "file") return value;
    return "note";
  }

  private async proposalOriginalText(file: TFile, appliesTo: string): Promise<string | null> {
    if (appliesTo === "selection") {
      const view = this.app.workspace.getActiveViewOfType(MarkdownView);
      if (view === null || view.file?.path !== file.path) {
        new Notice("Open the proposal source note before previewing a selection proposal.");
        return null;
      }
      const selection = view.editor.getSelection();
      if (selection.trim() === "") {
        new Notice("Select the target text before previewing a selection proposal.");
        return null;
      }
      return selection;
    }
    return this.app.vault.read(file);
  }

  private async ensureFolder(folder: string): Promise<void> {
    const parts = folder.split("/").filter((part) => part !== "");
    let current = "";
    for (const part of parts) {
      current = current === "" ? part : `${current}/${part}`;
      if (this.app.vault.getAbstractFileByPath(current) === null) {
        await this.app.vault.createFolder(current);
      }
    }
  }

  private resolvedRepoRoot(path: PathModule): string {
    if (this.kvSettings.repoRoot.trim() !== "") return this.kvSettings.repoRoot.trim();
    if (!this.hasLocalRuntime(path)) return this.vaultBasePath(path) ?? this.pluginDirectory(path);
    return path.resolve(this.pluginDirectory(path), "..", "..", "..", "..", "..", "..");
  }

  private resolvedAppRoot(path: PathModule): string {
    if (this.kvSettings.appRoot.trim() !== "") return this.kvSettings.appRoot.trim();
    return path.resolve(this.pluginDirectory(path), "..", "..", "..", "..");
  }

  private resolvedContentRoot(path: PathModule): string {
    const configured = this.kvSettings.contentRoot.trim();
    if (!this.hasLocalRuntime(path) && (configured === "" || configured === DEFAULT_SETTINGS.contentRoot)) {
      return this.vaultBasePath(path) ?? this.resolvedRepoRoot(path);
    }
    if (configured === "") return path.join(this.resolvedRepoRoot(path), DEFAULT_SETTINGS.contentRoot);
    return path.isAbsolute(configured) ? configured : path.join(this.resolvedRepoRoot(path), configured);
  }

  private hasLocalRuntime(path: PathModule): boolean {
    return this.fileExists(path, path.join(this.resolvedAppRoot(path), "dist", "scripts", "tool.mjs"));
  }

  private runtimeCommand(path: PathModule, bin: string, scriptName: string, args: readonly string[]): RuntimeCommand {
    const appRoot = this.resolvedAppRoot(path);
    const scriptPath = path.join(appRoot, "dist", "scripts", scriptName);
    if (this.fileExists(path, scriptPath)) {
      return Object.freeze({
        command: this.kvSettings.nodeExecutable,
        args: Object.freeze([scriptPath, ...args]),
        cwd: this.resolvedRepoRoot(path),
      });
    }
    const runtimePackage = this.kvSettings.runtimePackage.trim() || DEFAULT_SETTINGS.runtimePackage;
    const packageRunner = this.kvSettings.packageRunnerExecutable.trim() || DEFAULT_SETTINGS.packageRunnerExecutable;
    return Object.freeze({
      command: packageRunner,
      args: Object.freeze(["-y", "-p", runtimePackage, bin, ...args]),
      cwd: this.vaultBasePath(path) ?? this.pluginDirectory(path),
    });
  }

  private fileExists(path: PathModule, filePath: string): boolean {
    const fs = require("node:fs") as typeof import("node:fs");
    return path.isAbsolute(filePath) && fs.existsSync(filePath);
  }

  private pluginDirectory(path: PathModule): string {
    const adapter = this.app.vault.adapter;
    if (adapter instanceof FileSystemAdapter) {
      return path.join(adapter.getBasePath(), this.manifest.dir ?? ".obsidian/plugins/knowledge-vault");
    }
    throw new Error("The knowledge vault plugin requires the desktop filesystem adapter.");
  }

  private vaultBasePath(path: PathModule): string | null {
    const adapter = this.app.vault.adapter;
    return adapter instanceof FileSystemAdapter ? adapter.getBasePath() : null;
  }

  private childProcessModule(): ChildProcessModule {
    return require("node:child_process") as ChildProcessModule;
  }

  private pathModule(): PathModule {
    return require("node:path") as PathModule;
  }

  private urlModule(): UrlModule {
    return require("node:url") as UrlModule;
  }

  private async agentReviewModule(): Promise<AgentReviewModule> {
    const path = this.pathModule();
    const url = this.urlModule();
    const reviewPath = path.join(
      this.resolvedAppRoot(path),
      "node_modules",
      "@emsenn",
      "organizing-with-agents",
      "dist",
      "review",
      "index.mjs",
    );
    if (this.fileExists(path, reviewPath)) return await import(url.pathToFileURL(reviewPath).href) as AgentReviewModule;
    return localAgentReviewModule;
  }

  private async agentContextModule(): Promise<AgentContextModule> {
    const path = this.pathModule();
    const url = this.urlModule();
    const contextPath = path.join(
      this.resolvedAppRoot(path),
      "node_modules",
      "@emsenn",
      "organizing-with-agents",
      "dist",
      "context",
      "index.mjs",
    );
    if (this.fileExists(path, contextPath)) return await import(url.pathToFileURL(contextPath).href) as AgentContextModule;
    return localAgentContextModule;
  }

  private async agentCheckpointModule(): Promise<AgentCheckpointModule> {
    const path = this.pathModule();
    const url = this.urlModule();
    const checkpointPath = path.join(
      this.resolvedAppRoot(path),
      "node_modules",
      "@emsenn",
      "organizing-with-agents",
      "dist",
      "session",
      "checkpoint.mjs",
    );
    if (this.fileExists(path, checkpointPath)) return await import(url.pathToFileURL(checkpointPath).href) as AgentCheckpointModule;
    return localAgentCheckpointModule;
  }
}

class KnowledgeVaultCockpitView extends ItemView {
  private promptText = "";
  private readonly chatSessionId = `obsidian-chat-${Date.now()}`;
  private chatMessages: ChatMessage[] = [];
  private running = false;
  private runningOutput = "";
  private liveRun: LiveAgentRun | null = null;
  private lastPrompt = "";
  private lastResult: ToolResult | undefined;
  private liveOutputEl: HTMLElement | undefined;

  constructor(leaf: WorkspaceLeaf, private readonly plugin: KnowledgeVaultPlugin) {
    super(leaf);
  }

  override getViewType(): string {
    return KNOWLEDGE_VAULT_COCKPIT_VIEW;
  }

  override getDisplayText(): string {
    return "Knowledge Vault";
  }

  override getIcon(): string {
    return "folder-tree";
  }

  override async onOpen(): Promise<void> {
    await this.render();
  }

  private async render(): Promise<void> {
    const container = this.containerEl.children[1];
    if (!(container instanceof HTMLElement)) return;
    container.empty();
    container.addClass("knowledge-vault-cockpit");
    container.createEl("h2", { text: "Knowledge Vault" });

    const manifest = await this.plugin.runCockpitManifest(false);
    const parsed = parseJsonObject(manifest.stdout);
    const packages = Array.isArray(parsed?.["agentPackages"]) ? parsed["agentPackages"] : [];
    const tools = Array.isArray(parsed?.["tools"]) ? parsed["tools"] : [];
    const commands = Array.isArray(parsed?.["obsidianCommands"]) ? parsed["obsidianCommands"] : [];
    const core = isRecord(parsed?.["coreCapabilities"]) && Array.isArray(parsed["coreCapabilities"]["projections"])
      ? parsed["coreCapabilities"]["projections"]
      : [];

    const summary = container.createDiv({ cls: "knowledge-vault-cockpit-summary" });
    summary.createEl("p", { text: `Tools: ${tools.length}` });
    summary.createEl("p", { text: `Obsidian commands: ${commands.length}` });
    summary.createEl("p", { text: `Agent packages: ${packages.length}` });
    summary.createEl("p", { text: `Core projections: ${core.length}` });
    if (manifest.stderr.trim() !== "") summary.createEl("p", { text: manifest.stderr.trim() });

    new Setting(container)
      .addButton((button) => button.setButtonText("Refresh").onClick(() => this.render()))
      .addButton((button) => button.setButtonText("Dashboard").onClick(() => this.plugin.openDashboard()))
      .addButton((button) => button.setButtonText("Manifest").onClick(() => this.plugin.writeCockpitManifestNote()))
      .addButton((button) => button.setButtonText("Setup").onClick(() => this.plugin.writeRuntimeSetupNote()))
      .addButton((button) => button.setButtonText("Checkpoint").onClick(() => this.plugin.writeCockpitCheckpointNote()))
      .addButton((button) => button.setButtonText("Connectors").onClick(() => this.plugin.writeConnectorSnippetsNote()))
      .addButton((button) => button.setButtonText("Handoff").onClick(() => this.plugin.writeCockpitHandoffNote()))
      .addButton((button) => button.setButtonText("Queue").onClick(() => this.plugin.writeCockpitQueueNote()))
      .addButton((button) => button.setButtonText("Review").onClick(() => this.plugin.openCockpitReviewQueue()))
      .addButton((button) => button.setButtonText("Switch").onClick(() => this.plugin.openCockpitQuickSwitcher()))
      .addButton((button) => button.setButtonText("Audit").onClick(() => this.plugin.writeCockpitAuditNote()))
      .addButton((button) => button.setButtonText("Endpoints").onClick(() => this.plugin.listAgentEndpoints()))
      .addButton((button) => button.setButtonText("Search").onClick(() => new KnowledgeVaultSearchModal(this.app, this.plugin).open()))
      .addButton((button) => button.setButtonText("Tool").onClick(() => new KnowledgeVaultToolModal(this.app, this.plugin).open()));

    container.createEl("h3", { text: "Runtime setup" });
    const runtimeBox = container.createDiv({ cls: "knowledge-vault-runtime-status" });
    for (const line of this.plugin.runtimeReadinessLines()) {
      runtimeBox.createEl("p", { text: line.replace(/^- /u, "") });
    }

    const active = this.plugin.activeMarkdownFile();
    container.createEl("h3", { text: "Active note" });
    const activeBox = container.createDiv({ cls: "knowledge-vault-active-note" });
    if (active === null) {
      activeBox.createEl("p", { text: "No active markdown note." });
    } else {
      activeBox.createEl("p", { text: active.path });
      for (const line of this.plugin.activeNoteContextSections(active).filter((line) => line !== "" && !line.startsWith("## "))) {
        activeBox.createEl("p", { text: line });
      }
      new Setting(activeBox)
        .addButton((button) => button.setButtonText("Context").onClick(() => this.plugin.buildActiveNoteContextPack(active)))
        .addButton((button) => button.setButtonText("Neighborhood").onClick(() => this.plugin.buildActiveNoteNeighborhoodNote(active)))
        .addButton((button) => button.setButtonText("Mission").onClick(() => this.plugin.createAgentMissionFromActiveNote(active)))
        .addButton((button) => button.setButtonText("Arena").onClick(() => this.plugin.createArenaFromActiveNote(active)))
        .addButton((button) => button.setButtonText("Run").setCta().onClick(() => this.plugin.runActiveNoteWithAgent(active)));
      new Setting(activeBox)
        .addButton((button) => button.setButtonText("Advance arena").onClick(() => this.plugin.advanceActiveArena(active)))
        .addButton((button) => button.setButtonText("Edit proposal").onClick(() => this.plugin.proposeActiveNoteEdit(active)))
        .addButton((button) => button.setButtonText("Preview diff").onClick(() => this.plugin.previewActiveNoteEditProposalDiff(active)))
        .addButton((button) => button.setButtonText("Apply proposal").onClick(() => this.plugin.applyActiveNoteEditProposal(active)))
        .addButton((button) => button.setButtonText("Choose receipt").onClick(() => this.plugin.restoreActiveNoteFromEditReceipt(active)));
    }

    container.createEl("h3", { text: "Agent prompt" });
    new Setting(container)
      .setName("Prompt")
      .addTextArea((text) => text
        .setPlaceholder("Ask the ecosystem agent to inspect, compare, draft, or plan against the active note and content vault.")
        .setValue(this.promptText)
        .onChange((value) => {
          this.promptText = value;
        }));
    new Setting(container)
      .addButton((button) => button
        .setButtonText(this.running ? "Running" : "Run")
        .setCta()
        .setDisabled(this.running)
        .onClick(() => this.runLiveChat(this.promptText)))
      .addButton((button) => button
        .setButtonText("Stop")
        .setDisabled(!this.running)
        .onClick(() => this.stopLiveChat()))
      .addButton((button) => button
        .setButtonText("Retry")
        .setDisabled(this.running || this.lastPrompt.trim() === "")
        .onClick(() => this.runLiveChat(this.lastPrompt)))
      .addButton((button) => button
        .setButtonText("Transcript")
        .onClick(() => this.plugin.writeChatTranscript(this.chatSessionId, this.chatMessages, this.lastResult)))
      .addButton((button) => button
        .setButtonText("Clear")
        .setDisabled(this.running || this.chatMessages.length === 0)
        .onClick(() => {
          this.chatMessages = [];
          this.lastResult = undefined;
          this.runningOutput = "";
          void this.render();
        }));

    const transcript = container.createDiv({ cls: "knowledge-vault-chat-transcript" });
    transcript.createEl("p", { text: `Session: ${this.chatSessionId}` });
    if (this.chatMessages.length === 0) {
      transcript.createEl("p", { text: "No chat turns yet." });
    } else {
      for (const message of this.chatMessages.slice(-8)) {
        const item = transcript.createDiv({ cls: `knowledge-vault-chat-message knowledge-vault-chat-${message.role}` });
        item.createEl("strong", { text: message.role });
        item.createEl("pre", { text: message.content });
      }
    }
    this.liveOutputEl = transcript.createEl("pre", {
      cls: "knowledge-vault-live-output",
      text: this.runningOutput.trim() === "" ? (this.running ? "Waiting for agent output..." : "") : this.runningOutput,
    });

    container.createEl("h3", { text: "Agent packages" });
    const packageList = container.createEl("ul");
    for (const item of packages) {
      if (!isRecord(item)) continue;
      const name = typeof item["packageName"] === "string" ? item["packageName"] : "unknown package";
      const role = typeof item["cockpitRole"] === "string" ? item["cockpitRole"] : "";
      packageList.createEl("li", { text: `${name}: ${role}` });
    }

    container.createEl("h3", { text: "Tools" });
    const toolList = container.createEl("ul");
    for (const item of tools) {
      if (!isRecord(item)) continue;
      const command = typeof item["command"] === "string" ? item["command"] : "unknown";
      const purpose = typeof item["purpose"] === "string" ? item["purpose"] : "";
      toolList.createEl("li", { text: `${command}: ${purpose}` });
    }

    container.createEl("h3", { text: "Obsidian commands" });
    const commandList = container.createEl("ul");
    for (const item of commands) {
      if (!isRecord(item)) continue;
      const id = typeof item["id"] === "string" ? item["id"] : "unknown";
      const role = typeof item["role"] === "string" ? item["role"] : "";
      commandList.createEl("li", { text: `${id}: ${role}` });
    }
  }

  private async runLiveChat(promptText: string): Promise<void> {
    const prompt = promptText.trim();
    if (prompt === "" || this.running) return;
    this.lastPrompt = prompt;
    this.running = true;
    this.runningOutput = "";
    const prior = Object.freeze([...this.chatMessages]);
    this.chatMessages = [...this.chatMessages, { role: "user", content: prompt }];
    await this.render();
    const context = await this.plugin.agentPromptForActiveContext(prompt);
    const run = this.plugin.startLiveAgentRun({
      prompt: context.prompt,
      title: `Agent chat for ${context.topic}`,
      stream: true,
      session: this.chatSessionId,
      conversation: prior,
    }, (chunk) => {
      this.runningOutput += chunk.text;
      if (this.liveOutputEl !== undefined) this.liveOutputEl.setText(this.runningOutput);
    });
    this.liveRun = run;
    const result = await run.promise;
    this.liveRun = null;
    this.running = false;
    this.lastResult = result;
    const text = result.code === 0 ? agentTextFromResult(result.stdout).trim() : result.stderr.trim();
    this.chatMessages = [...this.chatMessages, { role: "assistant", content: text === "" ? "(no output)" : text }];
    await this.plugin.writeChatTranscript(this.chatSessionId, this.chatMessages, result);
    await this.render();
  }

  private stopLiveChat(): void {
    this.liveRun?.stop();
    this.runningOutput = `${this.runningOutput}\nStopping agent run...\n`;
    if (this.liveOutputEl !== undefined) this.liveOutputEl.setText(this.runningOutput);
  }
}

class KnowledgeVaultSettingTab extends PluginSettingTab {
  constructor(app: App, private readonly plugin: KnowledgeVaultPlugin) {
    super(app, plugin);
  }

  override display(): void {
    const { containerEl } = this;
    containerEl.empty();

    this.text("Repository root", "Leave blank when using the packaged vault inside the repo.", "repoRoot");
    this.text("App root", "Leave blank to use local repo inference when present, then the public npm runtime fallback.", "appRoot");
    this.text("Content root", "Absolute path or repository-relative path.", "contentRoot");
    this.text("Node executable", "The executable used to run the app tooling.", "nodeExecutable");
    this.text("Package runner executable", "Used when this plugin is installed without a local appRoot/dist runtime; usually npx.", "packageRunnerExecutable");
    this.text("Runtime package", "Public npm package used by the package runner for tool, agent, server, and cockpit commands.", "runtimePackage");
    this.text("Output folder", "Vault folder for generated tool notes.", "outputFolder");
    this.text("Agent folder", "Vault folder for generated mission notes.", "agentFolder");
    this.text("Default region", "Corpus-relative region used by context/search commands.", "defaultRegion");
    this.text("Agent endpoint", "Optional endpoint id for @emsenn/organizing-with-openai-agents.", "agentEndpoint");
    this.text("Agent model", "Optional model id passed to the ecosystem agent bridge.", "agentModel");
    this.text("Agent API key env", "Env var to inject for the chosen endpoint, such as OPENAI_API_KEY, GROQ_API_KEY, NVIDIA_API_KEY, or CEREBRAS_API_KEY.", "agentApiKeyEnv");
    this.password("Agent API key", "Stored in Obsidian plugin data and injected only into spawned agent processes.", "agentApiKey");
    this.longText("Agent system prompt", "Optional system prompt passed to the ecosystem agent bridge.", "agentSystem");
    this.number("Context limit", "Maximum evidence items requested by context commands.", "contextLimit");

    new Setting(containerEl)
      .setName("Allow external writes")
      .setDesc("When off, triage deposit commands produce dry-run plans instead of writing into the content vault.")
      .addToggle((toggle) => toggle
        .setValue(this.plugin.kvSettings.allowExternalWrites)
        .onChange((value) => this.saveSetting("allowExternalWrites", value)));
    new Setting(containerEl)
      .setName("Allow note edits")
      .setDesc("When off, generated edit proposals cannot be applied to Obsidian notes.")
      .addToggle((toggle) => toggle
        .setValue(this.plugin.kvSettings.allowNoteEdits)
        .onChange((value) => this.saveSetting("allowNoteEdits", value)));
  }

  private text(
    name: string,
    desc: string,
    key: "repoRoot" | "appRoot" | "contentRoot" | "nodeExecutable" | "packageRunnerExecutable" | "runtimePackage" | "outputFolder" | "agentFolder" | "defaultRegion" | "agentEndpoint" | "agentModel" | "agentApiKeyEnv",
  ): void {
    new Setting(this.containerEl)
      .setName(name)
      .setDesc(desc)
      .addText((text) => text
        .setValue(this.plugin.kvSettings[key])
        .onChange((value) => this.saveSetting(key, value)));
  }

  private password(name: string, desc: string, key: "agentApiKey"): void {
    new Setting(this.containerEl)
      .setName(name)
      .setDesc(desc)
      .addText((text) => {
        text.inputEl.type = "password";
        text.setValue(this.plugin.kvSettings[key])
          .onChange((value) => this.saveSetting(key, value));
      });
  }

  private longText(name: string, desc: string, key: "agentSystem"): void {
    new Setting(this.containerEl)
      .setName(name)
      .setDesc(desc)
      .addTextArea((text) => text
        .setValue(this.plugin.kvSettings[key])
        .onChange((value) => this.saveSetting(key, value)));
  }

  private number(name: string, desc: string, key: "contextLimit"): void {
    new Setting(this.containerEl)
      .setName(name)
      .setDesc(desc)
      .addText((text) => text
        .setValue(String(this.plugin.kvSettings[key]))
        .onChange((value) => {
          const parsed = Number(value);
          if (Number.isFinite(parsed) && parsed > 0) void this.saveSetting(key, Math.floor(parsed));
        }));
  }

  private async saveSetting<K extends keyof KnowledgeVaultSettings>(key: K, value: KnowledgeVaultSettings[K]): Promise<void> {
    await this.plugin.saveSettings(Object.freeze({ ...this.plugin.kvSettings, [key]: value }));
  }
}

class KnowledgeVaultSearchModal extends Modal {
  private query = "";

  constructor(app: App, private readonly plugin: KnowledgeVaultPlugin) {
    super(app);
  }

  override onOpen(): void {
    const { contentEl } = this;
    contentEl.empty();
    contentEl.createEl("h2", { text: "Search content vault" });
    new Setting(contentEl)
      .setName("Query")
      .addText((text) => text
        .setPlaceholder("topic, title, phrase")
        .onChange((value) => {
          this.query = value;
        }));
    new Setting(contentEl)
      .addButton((button) => button
        .setButtonText("Search")
        .setCta()
        .onClick(() => {
          const query = this.query.trim();
          if (query === "") {
            new Notice("Enter a search query.");
            return;
          }
          this.close();
          void this.runSearch(query);
        }));
  }

  private async runSearch(query: string): Promise<void> {
    const region = this.plugin.kvSettings.defaultRegion;
    const limit = String(this.plugin.kvSettings.contextLimit);
    const name = await this.plugin.runTool({
      verb: "find-name",
      stdin: query,
      args: ["--region", region, "--limit", limit],
      title: `Name search for ${query}`,
    });
    const text = await this.plugin.runTool({
      verb: "grep-text",
      stdin: query,
      args: ["--region", region, "--limit", limit],
      title: `Text search for ${query}`,
    });
    const body = [
      "---",
      `title: Search results for ${query}`,
      "tool: obsidian-knowledge-vault",
      "kind: vault-search",
      "---",
      "",
      `# Search results for ${query}`,
      "",
      "## Name matches",
      "",
      this.resultBlock(name),
      "",
      "## Text matches",
      "",
      this.resultBlock(text),
      "",
    ].join("\n");
    await this.plugin.upsertNote(`search-results-${query.toLowerCase().replace(/[^a-z0-9]+/g, "-")}.md`, body);
  }

  private resultBlock(result: ToolResult): string {
    const stderr = result.stderr.trim();
    const stdout = result.stdout.trim();
    return [
      `Exit code: ${result.code}`,
      "",
      "```json",
      stdout === "" ? "{}" : stdout,
      "```",
      ...(stderr === "" ? [] : ["", "```text", stderr, "```"]),
    ].join("\n");
  }
}

class KnowledgeVaultToolModal extends Modal {
  private action = "inspect-root";
  private stdin = "";
  private extraArgs = "";

  constructor(app: App, private readonly plugin: KnowledgeVaultPlugin) {
    super(app);
  }

  override onOpen(): void {
    const { contentEl } = this;
    contentEl.empty();
    contentEl.createEl("h2", { text: "Run knowledge vault tool" });
    new Setting(contentEl)
      .setName("Tool")
      .addDropdown((dropdown: DropdownComponent) => {
        for (const action of COCKPIT_ACTIONS) dropdown.addOption(action, action);
        dropdown.setValue(this.action).onChange((value) => {
          this.action = value;
        });
      });
    new Setting(contentEl)
      .setName("Input")
      .addTextArea((text: TextAreaComponent) => text
        .setPlaceholder("stdin for the selected tool")
        .onChange((value) => {
          this.stdin = value;
        }));
    new Setting(contentEl)
      .setName("Extra arguments")
      .setDesc("Space-separated dispatcher args, for example --region content --limit 50.")
      .addText((text: TextComponent) => text
        .setPlaceholder("--region content --limit 50")
        .onChange((value) => {
          this.extraArgs = value;
        }));
    new Setting(contentEl)
      .addButton((button: ButtonComponent) => button
        .setButtonText("Run")
        .setCta()
        .onClick(() => {
          this.close();
          void this.plugin.writeToolNote({
            verb: this.action,
            stdin: this.stdin,
            args: splitArgs(this.extraArgs),
            title: `Knowledge vault ${this.action}`,
          });
        }));
  }
}

class KnowledgeVaultReceiptModal extends Modal {
  private selectedPath: string;

  constructor(
    app: App,
    private readonly plugin: KnowledgeVaultPlugin,
    private readonly source: TFile,
    private readonly receipts: readonly EditReceiptSummary[],
  ) {
    super(app);
    this.selectedPath = receipts[0]?.path ?? "";
  }

  override onOpen(): void {
    const { contentEl } = this;
    contentEl.empty();
    contentEl.createEl("h2", { text: "Restore edit receipt" });
    new Setting(contentEl)
      .setName("Receipt")
      .addDropdown((dropdown: DropdownComponent) => {
        for (const receipt of this.receipts) {
          const state = receipt.rollbackApproved ? "approved" : "locked";
          dropdown.addOption(receipt.path, `${receipt.appliedAt} - ${receipt.appliesTo} - ${state}`);
        }
        dropdown.setValue(this.selectedPath).onChange((value) => {
          this.selectedPath = value;
        });
      });
    new Setting(contentEl)
      .addButton((button: ButtonComponent) => button
        .setButtonText("Open")
        .onClick(() => {
          const receipt = this.selectedReceipt();
          if (receipt === undefined) return;
          this.close();
          void this.app.workspace.getLeaf(false).openFile(receipt.file);
        }))
      .addButton((button: ButtonComponent) => button
        .setButtonText("Restore")
        .setCta()
        .onClick(() => {
          const receipt = this.selectedReceipt();
          if (receipt === undefined) {
            new Notice("Choose an edit receipt.");
            return;
          }
          this.close();
          void this.plugin.restoreActiveNoteFromReceiptFile(this.source, receipt.file);
        }));
  }

  private selectedReceipt(): EditReceiptSummary | undefined {
    return this.receipts.find((receipt) => receipt.path === this.selectedPath);
  }
}

class KnowledgeVaultQuickSwitcherModal extends FuzzySuggestModal<QuickSwitchItem> {
  constructor(
    app: App,
    private readonly plugin: KnowledgeVaultPlugin,
    private readonly items: readonly QuickSwitchItem[],
  ) {
    super(app);
    this.setPlaceholder("Open generated work, active note context, arenas, proposals, or graph neighbors");
    this.emptyStateText = "No matching cockpit item.";
    this.limit = 24;
  }

  override getItems(): QuickSwitchItem[] {
    return [...this.items];
  }

  override getItemText(item: QuickSwitchItem): string {
    return `${item.title} ${item.path} ${item.kind} ${item.detail}`;
  }

  override renderSuggestion(match: FuzzyMatch<QuickSwitchItem>, el: HTMLElement): void {
    const item = match.item;
    el.createEl("div", { text: item.title, cls: "knowledge-vault-switch-title" });
    el.createEl("div", { text: `${item.kind} - ${item.path}`, cls: "knowledge-vault-switch-path" });
    el.createEl("div", { text: item.detail, cls: "knowledge-vault-switch-detail" });
  }

  override onChooseItem(item: QuickSwitchItem, _evt: MouseEvent | KeyboardEvent): void {
    void this.plugin.openQuickSwitchItem(item);
  }
}

class KnowledgeVaultReviewQueueModal extends Modal {
  private filter: ReviewQueueFilter = "needs-review";
  private selectedPath = "";

  constructor(app: App, private readonly plugin: KnowledgeVaultPlugin) {
    super(app);
  }

  override onOpen(): void {
    this.render();
  }

  private render(): void {
    const { contentEl } = this;
    contentEl.empty();
    contentEl.createEl("h2", { text: "Cockpit review queue" });
    const records = this.plugin.reviewQueueRecords(this.filter);
    if (this.selectedPath === "" || !records.some((note) => note.path === this.selectedPath)) {
      this.selectedPath = records[0]?.path ?? "";
    }
    new Setting(contentEl)
      .setName("Filter")
      .addDropdown((dropdown: DropdownComponent) => {
        dropdown
          .addOption("needs-review", "Needs review")
          .addOption("proposals", "Proposals")
          .addOption("arenas", "Arenas")
          .addOption("receipts", "Receipts")
          .addOption("all", "All generated");
        dropdown.setValue(this.filter).onChange((value) => {
          this.filter = reviewQueueFilter(value);
          this.selectedPath = "";
          this.render();
        });
      });
    if (records.length === 0) {
      contentEl.createEl("p", { text: "No generated cockpit notes match this filter." });
      return;
    }
    new Setting(contentEl)
      .setName("Item")
      .addDropdown((dropdown: DropdownComponent) => {
        for (const note of records) dropdown.addOption(note.path, reviewQueueOptionLabel(note));
        dropdown.setValue(this.selectedPath).onChange((value) => {
          this.selectedPath = value;
          this.render();
        });
      });
    const selected = records.find((note) => note.path === this.selectedPath);
    if (selected !== undefined) {
      const details = contentEl.createDiv({ cls: "knowledge-vault-review-queue-detail" });
      details.createEl("p", { text: selected.path });
      details.createEl("p", { text: `kind: ${selected.kind ?? "unknown"}; status: ${selected.status ?? "none"}` });
      if (selected.source !== undefined) details.createEl("p", { text: `source: ${selected.source}` });
    }
    const actions = new Setting(contentEl)
      .addButton((button: ButtonComponent) => button
        .setButtonText("Open")
        .onClick(() => {
          if (this.selectedPath === "") return;
          this.close();
          void this.plugin.openGeneratedNote(this.selectedPath);
        }));
    if (selected?.source !== undefined) {
      actions.addButton((button: ButtonComponent) => button
        .setButtonText("Source")
        .onClick(() => {
          if (this.selectedPath === "") return;
          this.close();
          void this.plugin.openGeneratedNoteSource(this.selectedPath);
        }));
    }
    if (selected !== undefined && reviewQueueRecordSupportsApproval(selected)) {
      actions.addButton((button: ButtonComponent) => button
        .setButtonText("Approve")
        .onClick(() => void this.approve()));
    }
    if (selected !== undefined && reviewQueueRecordSupportsArenaAdvance(selected)) {
      actions.addButton((button: ButtonComponent) => button
        .setButtonText("Advance")
        .setCta()
        .onClick(() => {
          if (this.selectedPath === "") return;
          this.close();
          void this.plugin.advanceGeneratedArena(this.selectedPath);
        }));
    }
    actions
      .addButton((button: ButtonComponent) => button
        .setButtonText("Reviewed")
        .onClick(() => void this.transition("reviewed")))
      .addButton((button: ButtonComponent) => button
        .setButtonText("Settled")
        .setCta()
        .onClick(() => void this.transition("settled")));
  }

  private async transition(status: string): Promise<void> {
    if (this.selectedPath === "") {
      new Notice("Choose a generated note.");
      return;
    }
    await this.plugin.setGeneratedNoteStatus(this.selectedPath, status);
    this.render();
  }

  private async approve(): Promise<void> {
    if (this.selectedPath === "") {
      new Notice("Choose a generated note.");
      return;
    }
    await this.plugin.approveGeneratedNote(this.selectedPath);
    this.render();
  }
}

function splitArgs(input: string): readonly string[] {
  const args: string[] = [];
  let current = "";
  let quote: '"' | "'" | null = null;
  for (const char of input) {
    if (quote !== null) {
      if (char === quote) quote = null;
      else current += char;
      continue;
    }
    if (char === '"' || char === "'") {
      quote = char;
      continue;
    }
    if (/\s/.test(char)) {
      if (current !== "") {
        args.push(current);
        current = "";
      }
      continue;
    }
    current += char;
  }
  if (current !== "") args.push(current);
  return Object.freeze(args);
}

function parseJsonObject(text: string): Readonly<Record<string, unknown>> | null {
  try {
    const value: unknown = JSON.parse(text);
    return isRecord(value) ? value : null;
  } catch {
    return null;
  }
}

function isRecord(value: unknown): value is Readonly<Record<string, unknown>> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function canvasNode(value: unknown): CanvasNode | null {
  if (!isRecord(value)) return null;
  const id = value["id"];
  const type = value["type"];
  if (typeof id !== "string" || id.trim() === "" || typeof type !== "string" || type.trim() === "") return null;
  const file = value["file"];
  const text = value["text"];
  const url = value["url"];
  const label = value["label"];
  return Object.freeze({
    id,
    type,
    ...(typeof file === "string" && file.trim() !== "" ? { file } : {}),
    ...(typeof text === "string" && text.trim() !== "" ? { text } : {}),
    ...(typeof url === "string" && url.trim() !== "" ? { url } : {}),
    ...(typeof label === "string" && label.trim() !== "" ? { label } : {}),
  });
}

function canvasEdge(value: unknown): CanvasEdge | null {
  if (!isRecord(value)) return null;
  const fromNode = value["fromNode"];
  const toNode = value["toNode"];
  if (typeof fromNode !== "string" || fromNode.trim() === "" || typeof toNode !== "string" || toNode.trim() === "") return null;
  const label = value["label"];
  return Object.freeze({
    fromNode,
    toNode,
    ...(typeof label === "string" && label.trim() !== "" ? { label } : {}),
  });
}

function frontmatterValue(frontmatter: unknown, key: string): string | undefined {
  const value = frontmatterScalar(frontmatter, key);
  return value === undefined ? undefined : `${key}: ${value}`;
}

function frontmatterScalar(frontmatter: unknown, key: string): string | undefined {
  if (!isRecord(frontmatter)) return undefined;
  const value = frontmatter[key];
  return typeof value === "string" && value.trim() !== "" ? value.trim() : undefined;
}

function renderGeneratedNoteRecord(note: GeneratedNoteRecord): string {
  const details = [
    note.kind === undefined ? undefined : `kind: ${note.kind}`,
    note.verb === undefined ? undefined : `verb: ${note.verb}`,
    note.status === undefined ? undefined : `status: ${note.status}`,
    note.source === undefined ? undefined : `source: ${note.source}`,
  ].filter((value) => value !== undefined);
  const suffix = details.length === 0 ? "" : ` - ${details.join("; ")}`;
  return `- [[${note.path}]] (${note.modifiedAt})${suffix}`;
}

function localEditProposalDiff(original: string, proposed: string): Readonly<{ additions: number; deletions: number; text: string }> {
  const originalLines = original.split(/\r?\n/u);
  const proposedLines = proposed.split(/\r?\n/u);
  const rows: string[] = [];
  let additions = 0;
  let deletions = 0;
  const max = Math.max(originalLines.length, proposedLines.length);
  for (let index = 0; index < max; index += 1) {
    const before = originalLines[index];
    const after = proposedLines[index];
    if (before === after && before !== undefined) {
      rows.push(` ${before}`);
      continue;
    }
    if (before !== undefined) {
      deletions += 1;
      rows.push(`-${before}`);
    }
    if (after !== undefined) {
      additions += 1;
      rows.push(`+${after}`);
    }
  }
  return Object.freeze({ additions, deletions, text: rows.join("\n") });
}

function renderLocalSessionCheckpointMarkdown(checkpoint: AgentSessionCheckpoint): string {
  return [
    `# ${checkpoint.title ?? "Agent session checkpoint"}`,
    "",
    `Session: \`${checkpoint.session}\``,
    `Generated: ${checkpoint.generatedAt}`,
    ...(checkpoint.objective === undefined ? [] : [`Objective: ${checkpoint.objective}`]),
    ...(checkpoint.activePath === undefined ? [] : [`Active path: \`${checkpoint.activePath}\``]),
    "",
    "## Readiness",
    "",
    ...markdownList(checkpoint.readiness),
    "",
    "## Generated Artifacts",
    "",
    ...checkpointArtifactsMarkdown(checkpoint.artifacts),
    "",
    "## Evidence",
    "",
    ...markdownList(checkpoint.evidence),
    "",
    "## Suggested Commands",
    "",
    ...markdownList(checkpoint.suggestedCommands.map((command) => `\`${command}\``)),
    "",
    "## Next Moves",
    "",
    ...markdownList(checkpoint.next),
    "",
  ].join("\n");
}

function markdownList(items: readonly string[]): readonly string[] {
  if (items.length === 0) return Object.freeze(["- none"]);
  return Object.freeze(items.map((item) => item.startsWith("- ") ? item : `- ${item}`));
}

function checkpointArtifactsMarkdown(artifacts: readonly AgentSessionCheckpointArtifact[]): readonly string[] {
  if (artifacts.length === 0) return Object.freeze(["- none"]);
  return Object.freeze(artifacts.map((artifact) => {
    const details = [
      artifact.kind === undefined ? undefined : `kind: ${artifact.kind}`,
      artifact.status === undefined ? undefined : `status: ${artifact.status}`,
      artifact.source === undefined ? undefined : `source: ${artifact.source}`,
      artifact.modifiedAt === undefined ? undefined : `modified: ${artifact.modifiedAt}`,
    ].filter((value) => value !== undefined);
    return `- [[${artifact.path}|${artifact.title ?? artifact.path}]]${details.length === 0 ? "" : ` (${details.join("; ")})`}`;
  }));
}

function groupGeneratedNotes(notes: readonly GeneratedNoteRecord[]): readonly string[] {
  if (notes.length === 0) return Object.freeze(["No generated cockpit notes found."]);
  const counts = new Map<string, number>();
  for (const note of notes) {
    const key = `${note.kind ?? "unknown"} / ${note.status ?? "none"}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return Object.freeze([...counts.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, count]) => `- ${key}: ${count}`));
}

function renderBenchmarkItem(item: Readonly<Record<string, unknown>>): string {
  const id = typeof item["id"] === "string" ? item["id"] : "unknown";
  const name = typeof item["name"] === "string" ? item["name"] : id;
  const requirement = typeof item["requirement"] === "string" ? item["requirement"] : "";
  const next = typeof item["next"] === "string" ? item["next"] : "";
  const evidence = Array.isArray(item["evidence"])
    ? item["evidence"].filter((value): value is string => typeof value === "string").join(", ")
    : "";
  return `- ${name} (\`${id}\`): ${requirement}${evidence === "" ? "" : ` Evidence: ${evidence}.`}${next === "" ? "" : ` Next: ${next}`}`;
}

function renderConnectorRegistration(connector: Readonly<Record<string, unknown>>): readonly string[] {
  const id = typeof connector["id"] === "string" ? connector["id"] : "unknown";
  const title = typeof connector["title"] === "string" ? connector["title"] : id;
  const command = typeof connector["command"] === "string" ? connector["command"] : "";
  const args = Array.isArray(connector["args"])
    ? connector["args"].filter((value): value is string => typeof value === "string")
    : [];
  const endpoints = isRecord(connector["endpoints"]) ? connector["endpoints"] : {};
  const snippets = Array.isArray(connector["snippets"]) ? connector["snippets"].filter(isRecord) : [];
  const mcp = typeof endpoints["mcp"] === "string" ? endpoints["mcp"] : "";
  const openapi = typeof endpoints["openapi"] === "string" ? endpoints["openapi"] : "";
  return [
    `## ${title}`,
    "",
    `Connector id: \`${id}\``,
    "",
    "### Start command",
    "",
    "```sh",
    [command, ...args].filter((part) => part !== "").join(" "),
    "```",
    "",
    "### Endpoints",
    "",
    `- MCP: ${mcp === "" ? "not projected" : mcp}`,
    `- OpenAPI: ${openapi === "" ? "not projected" : openapi}`,
    "",
    "### Host snippets",
    "",
    ...(snippets.length === 0 ? ["No host snippets projected.", ""] : snippets.flatMap(renderConnectorSnippet)),
  ];
}

function renderConnectorSnippet(snippet: Readonly<Record<string, unknown>>): readonly string[] {
  const host = typeof snippet["host"] === "string" ? snippet["host"] : "Unknown host";
  const targetPath = typeof snippet["path"] === "string" ? snippet["path"] : "unknown";
  const format = typeof snippet["format"] === "string" ? snippet["format"] : "";
  const body = typeof snippet["body"] === "string" ? snippet["body"] : "";
  const fence = format === "json" ? "json" : format === "toml" ? "toml" : format === "shell" ? "sh" : "markdown";
  return [
    `#### ${host}`,
    "",
    `Target: \`${targetPath}\``,
    "",
    `\`\`\`${fence}`,
    body,
    "```",
    "",
  ];
}

function agentTextFromResult(stdout: string): string {
  const parsed = parseJsonObject(stdout.trim());
  const text = parsed?.["text"];
  return typeof text === "string" ? text : stdout;
}

function extractMarkdownBlock(text: string): string {
  const markdown = /```(?:markdown|md)?\s*\n([\s\S]*?)\n```/i.exec(text);
  if (markdown?.[1] !== undefined) return markdown[1];
  return text;
}

function extractMarkdownBlockAfterHeading(text: string, heading: string): string {
  const escaped = heading.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const section = new RegExp(`^##\\s+${escaped}\\s*$([\\s\\S]*)`, "im").exec(text)?.[1] ?? text;
  return extractMarkdownBlock(section);
}

function proposalFrontMatterValue(text: string, key: string): string | undefined {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const value = new RegExp(`^${escaped}:\\s*(.+?)\\s*$`, "m").exec(text)?.[1]?.trim();
  return value === "" ? undefined : value;
}

function receiptTimestamp(value: string): string {
  return value.replace(/[^0-9a-z]+/giu, "-").replace(/^-|-$/g, "").toLowerCase() || `${Date.now()}`;
}

function reviewQueueFilter(value: string): ReviewQueueFilter {
  return value === "proposals" || value === "arenas" || value === "receipts" || value === "all" ? value : "needs-review";
}

function reviewQueueRecordMatches(note: GeneratedNoteRecord, filter: ReviewQueueFilter): boolean {
  const kind = note.kind ?? "";
  const status = note.status ?? "";
  if (filter === "all") return true;
  if (filter === "proposals") return kind.includes("proposal") || status === "proposed";
  if (filter === "arenas") return kind === "cockpit-arena" || status === "admitted";
  if (filter === "receipts") return kind.includes("receipt");
  return status === "proposed" || status === "admitted" || kind === "agent-edit-proposal" || kind === "cockpit-arena";
}

function reviewQueueOptionLabel(note: GeneratedNoteRecord): string {
  const title = note.title ?? note.path.split("/").at(-1) ?? note.path;
  return `${title} - ${note.kind ?? "unknown"} - ${note.status ?? "none"}`;
}

function reviewQueueRecordSupportsApproval(note: GeneratedNoteRecord): boolean {
  const kind = note.kind ?? "";
  return kind.includes("proposal") || kind.includes("receipt");
}

function reviewQueueRecordSupportsArenaAdvance(note: GeneratedNoteRecord): boolean {
  return note.kind === "cockpit-arena";
}

function setFrontmatterScalar(text: string, key: string, value: string): string {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const line = `${key}: ${value}`;
  const block = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/u.exec(text);
  if (block === null) return `---\n${line}\n---\n\n${text}`;
  const bodyStart = block[0].length;
  const frontmatter = block[1] ?? "";
  const nextFrontmatter = new RegExp(`^${escaped}:\\s*.*$`, "m").test(frontmatter)
    ? frontmatter.replace(new RegExp(`^${escaped}:\\s*.*$`, "m"), line)
    : `${frontmatter.trimEnd()}\n${line}`.trimStart();
  return `---\n${nextFrontmatter}\n---\n${text.slice(bodyStart)}`;
}
