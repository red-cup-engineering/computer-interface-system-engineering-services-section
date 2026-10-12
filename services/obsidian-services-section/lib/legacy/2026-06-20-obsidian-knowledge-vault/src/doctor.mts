import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import process from "node:process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export type DoctorProbe = Readonly<{
  label: string;
  command: string;
  args: readonly string[];
  cwd: string;
  code: number;
  stdout: string;
  stderr: string;
}>;

export type KnowledgeVaultDoctorOptions = Readonly<{
  vaultRoot?: string;
  toolScript?: string;
  obsidianExecutable?: string;
  cwd?: string;
}>;

export type KnowledgeVaultDoctorReport = Readonly<{
  kind: "obsidian-knowledge-vault.doctor";
  generatedAt: string;
  platform: NodeJS.Platform;
  node: Readonly<{
    execPath: string;
    version: string;
  }>;
  cwd: string;
  path: string;
  vaultRoot: string;
  toolScript: string;
  obsidianExecutable: string;
  probes: readonly DoctorProbe[];
  suggestions: readonly string[];
}>;

export function knowledgeVaultDoctor(options: KnowledgeVaultDoctorOptions = {}): KnowledgeVaultDoctorReport {
  const cwd = resolve(options.cwd ?? process.env["INIT_CWD"] ?? process.cwd());
  const vaultRoot = resolve(cwd, options.vaultRoot ?? cwd);
  const toolScript = options.toolScript ?? join(dirname(fileURLToPath(import.meta.url)), "scripts", "tool.mjs");
  const obsidianExecutable = options.obsidianExecutable ?? process.env["OBSIDIAN_EXECUTABLE"] ?? defaultObsidianExecutable();
  const probes = Object.freeze([
    runProbe("node --version", process.execPath, ["--version"], cwd),
    runProbe("knowledge-vault inspect-root", process.execPath, [toolScript, "inspect-root", "--path", vaultRoot], cwd),
    runProbe("obsidian cli help", obsidianExecutable, ["--help"], cwd),
  ]);
  return Object.freeze({
    kind: "obsidian-knowledge-vault.doctor" as const,
    generatedAt: new Date().toISOString(),
    platform: process.platform,
    node: Object.freeze({ execPath: process.execPath, version: process.version }),
    cwd,
    path: process.env["PATH"] ?? "",
    vaultRoot,
    toolScript,
    obsidianExecutable,
    probes,
    suggestions: doctorSuggestions(probes),
  });
}

export function renderKnowledgeVaultDoctorMarkdown(report: KnowledgeVaultDoctorReport): string {
  return [
    "# Knowledge Vault Doctor",
    "",
    `Generated: ${report.generatedAt}`,
    "",
    "## Runtime",
    "",
    `- platform: ${report.platform}`,
    `- cwd: \`${report.cwd}\``,
    `- node: \`${report.node.execPath}\` (${report.node.version})`,
    `- vault root: \`${report.vaultRoot}\``,
    `- tool script: \`${report.toolScript}\``,
    `- Obsidian executable: \`${report.obsidianExecutable}\``,
    `- PATH: ${report.path}`,
    "",
    "## Probes",
    "",
    ...report.probes.flatMap(renderProbeMarkdown),
    "## Suggestions",
    "",
    ...(report.suggestions.length === 0 ? ["- No immediate runtime suggestions."] : report.suggestions.map((item) => `- ${item}`)),
    "",
  ].join("\n");
}

function runProbe(label: string, command: string, args: readonly string[], cwd: string): DoctorProbe {
  const result = spawnSync(command, [...args], {
    cwd,
    encoding: "utf8",
    maxBuffer: 1024 * 1024 * 20,
    timeout: 8_000,
    windowsHide: true,
  });
  return Object.freeze({
    label,
    command,
    args: Object.freeze([...args]),
    cwd,
    code: result.status ?? (result.error === undefined ? 0 : 1),
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? (result.error === undefined ? "" : result.error.message),
  });
}

function renderProbeMarkdown(probe: DoctorProbe): readonly string[] {
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
    "",
  ];
}

function doctorSuggestions(probes: readonly DoctorProbe[]): readonly string[] {
  const suggestions: string[] = [];
  const node = probes.find((probe) => probe.label === "node --version");
  const tool = probes.find((probe) => probe.label === "knowledge-vault inspect-root");
  const obsidian = probes.find((probe) => probe.label === "obsidian cli help");
  if (node === undefined || node.code !== 0) suggestions.push("Set the plugin Node executable to an absolute path, for example C:\\nvm4w\\nodejs\\node.exe on this workstation.");
  if (tool === undefined || tool.code !== 0) suggestions.push("Build the app package, confirm the vault root path, and run the inspect-root command shown above from a terminal.");
  if (obsidian !== undefined && /command line interface is not enabled/i.test(`${obsidian.stdout}\n${obsidian.stderr}`)) {
    suggestions.push("Enable Obsidian's command line interface in Settings -> General -> Advanced before using Obsidian CLI launch/open smoke tests.");
  } else if (obsidian !== undefined && obsidian.code !== 0 && /Loaded main app package|Latest version/i.test(`${obsidian.stdout}\n${obsidian.stderr}`)) {
    suggestions.push("Obsidian launched but did not provide CLI help; enable the command line interface in Settings -> General -> Advanced, then rerun this doctor.");
  } else if (obsidian === undefined || obsidian.code !== 0) {
    suggestions.push("Set OBSIDIAN_EXECUTABLE or add Obsidian to PATH before relying on Obsidian CLI smoke tests.");
  }
  return Object.freeze(suggestions);
}

function defaultObsidianExecutable(): string {
  if (process.platform === "win32") {
    const installed = "C:\\Program Files\\Obsidian\\Obsidian.exe";
    if (existsSync(installed)) return installed;
  }
  return "obsidian";
}
