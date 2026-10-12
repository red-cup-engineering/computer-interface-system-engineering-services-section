#!/usr/bin/env node
import { existsSync, mkdtempSync, readdirSync, readFileSync, readlinkSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const root = new URL("..", import.meta.url);
const repositoryRoot = new URL("../../", root);
const required = [
  "README.md",
  "package.json",
  "flake.nix",
  "guix/channels.scm",
  "guix/manifest.scm",
  "early-init.el",
  "init.el",
  "scripts/gnoponemacs.mjs",
  "lisp/gnopon-lib.el",
  "lisp/gnopon-core.el",
  "scripts/repro-check.mjs",
  "scripts/startup-benchmark.mjs",
  "lisp/gnopon-markdown.el",
  "lisp/gnopon-tasks.el",
  "lisp/gnopon-predication.el",
  "lisp/gnopon-formal.el",
  "lisp/gnopon-actions.el",
  "lisp/gnopon-ide.el",
  "lisp/gnopon-review.el",
  "lisp/gnopon-control.el",
  "lisp/gnopon-agents.el",
  "lisp/gnopon-mcp.el",
  "lisp/gnopon-capability.el",
  "tests/gnopon-lib-test.el",
  "tests/gnopon-command-test.el",
  "tests/gnopon-load-smoke.el",
];

for (const file of required) {
  readFileSync(new URL(file, root), "utf8");
}

const rootMakefile = readFileSync(new URL("Makefile", repositoryRoot), "utf8");
if (!rootMakefile.includes("gnoponemacs:") || !rootMakefile.includes("node apps/gnoponemacs/scripts/gnoponemacs.mjs")) {
  throw new Error("repository Makefile is missing the gnoponemacs launch target");
}

if (existsSync(new URL("config.org", root))) {
  throw new Error("config.org must not exist; GnoponEmacs is Markdown-native and does not use Org Babel");
}

const init = readFileSync(new URL("init.el", root), "utf8");
for (const moduleName of [
  "gnopon-lib",
  "gnopon-core",
  "gnopon-ui",
  "gnopon-workspace",
  "gnopon-completion",
  "gnopon-editing",
  "gnopon-programming",
  "gnopon-ide",
  "gnopon-api",
  "gnopon-markdown",
  "gnopon-tasks",
  "gnopon-predication",
  "gnopon-formal",
  "gnopon-git",
  "gnopon-shell",
  "gnopon-context",
  "gnopon-agents",
  "gnopon-mcp",
  "gnopon-review",
  "gnopon-actions",
  "gnopon-security",
  "gnopon-persistence",
  "gnopon-doctor",
  "gnopon-capability",
  "gnopon-control",
  "gnopon-cockpit",
]) {
  if (!init.includes(`(require '${moduleName})`)) {
    throw new Error(`init.el does not require ${moduleName}`);
  }
  if (!existsSync(new URL(`lisp/${moduleName}.el`, root))) {
    throw new Error(`missing lisp/${moduleName}.el`);
  }
}

const readme = readFileSync(new URL("README.md", root), "utf8");
const flake = readFileSync(new URL("flake.nix", root), "utf8");
const guixManifest = readFileSync(new URL("guix/manifest.scm", root), "utf8");
const allElisp = readdirSync(new URL("lisp/", root))
  .filter((file) => file.endsWith(".el"))
  .map((file) => readFileSync(new URL(`lisp/${file}`, root), "utf8"))
  .concat(init)
  .join("\n");
for (const prohibited of ["org-roam", "org-agenda", "org-babel", "(use-package org"]) {
  if (allElisp.includes(prohibited)) {
    throw new Error(`prohibited Org-centered dependency found: ${prohibited}`);
  }
}

const core = readFileSync(new URL("lisp/gnopon-core.el", root), "utf8");
const packageManifestMatch = core.match(
  /\(defvar gnopon-package-manifest\s+'\(([\s\S]*?)\)\s+"Third-party packages expected/,
);
if (!packageManifestMatch) {
  throw new Error("could not parse gnopon-package-manifest for reproducible manifest checks");
}
const emacsPackageManifest = [...packageManifestMatch[1].matchAll(/\b([a-zA-Z0-9][a-zA-Z0-9-]*)\b/g)].map(
  (item) => item[1],
);
for (const packageName of emacsPackageManifest) {
  if (!flake.includes(`"${packageName}"`)) {
    throw new Error(`flake.nix is missing Emacs package ${packageName}`);
  }
  if (!guixManifest.includes(`"emacs-${packageName}"`)) {
    throw new Error(`guix/manifest.scm is missing Emacs package emacs-${packageName}`);
  }
}

const builtInUsePackages = new Set([
  "auth-source",
  "compile",
  "dired",
  "eglot",
  "emacs",
  "epa",
  "epg",
  "eshell",
  "flymake",
  "project",
  "recentf",
  "savehist",
  "saveplace",
  "tab-bar",
  "treesit",
  "whitespace",
  "winner",
]);

function matchingElispForm(text, start) {
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let index = start; index < text.length; index += 1) {
    const char = text[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === "\\") {
        escaped = true;
      } else if (char === "\"") {
        inString = false;
      }
      continue;
    }
    if (char === "\"") {
      inString = true;
      continue;
    }
    if (char === "(") {
      depth += 1;
      continue;
    }
    if (char === ")") {
      depth -= 1;
      if (depth === 0) {
        return text.slice(start, index + 1);
      }
    }
  }
  throw new Error("unterminated use-package form in Elisp source");
}

for (const file of readdirSync(new URL("lisp/", root)).filter((name) => name.endsWith(".el"))) {
  const text = readFileSync(new URL(`lisp/${file}`, root), "utf8");
  for (const match of text.matchAll(/\(use-package\s+([a-zA-Z0-9-]+)/g)) {
    const packageName = match[1];
    if (builtInUsePackages.has(packageName)) {
      continue;
    }
    const form = matchingElispForm(text, match.index);
    if (!form.includes(":ensure nil") && !form.includes("gnopon/optional-package-available-p")) {
      throw new Error(
        `${file} has unguarded optional package ${packageName}; use gnopon/use-optional-package or :if gnopon/optional-package-available-p`,
      );
    }
  }
}

const definedGnoponSymbols = new Set(
  [
    ...allElisp.matchAll(/\(def(?:un|macro|var|custom|const)\s+(gnopon\/[a-zA-Z0-9-]+)/g),
    ...allElisp.matchAll(/\(transient-define-prefix\s+(gnopon\/[a-zA-Z0-9-]+)/g),
  ].map((match) => match[1]),
);
for (const symbol of [...allElisp.matchAll(/#'(gnopon\/[a-zA-Z0-9-]+)|\b(gnopon\/[a-zA-Z0-9-]+)\b/g)]
  .map((match) => match[1] || match[2])
  .filter(Boolean)) {
  if (!definedGnoponSymbols.has(symbol)) {
    throw new Error(`referenced GnoponEmacs symbol is not defined: ${symbol}`);
  }
}

for (const requiredFeature of [
  "transient-define-prefix gnopon/cockpit",
  "gnopon/optional-package-available-p",
  "gnopon/use-optional-package",
  "gnopon/search-project",
  "gnopon/switch-buffer",
  "package-quickstart nil",
  "gnopon/package-json-scripts",
  "gnopon/doctor-package-row",
  "gnopon/bootstrap-project-memory",
  "gnopon/validate-project-memory",
  "gnopon/capture-command-log",
  "gnopon/review-agent-diff",
  "gnopon/git-project-status",
  "gnopon/git-log-buffer-file",
  "gnopon/git-show-hunk",
  "gnopon/performance-report-text",
  "gnopon/write-performance-report",
  "gnopon/doctor",
  "gnopon/doctor-text",
  "gnopon/write-doctor-report",
  "gnopon/capability-audit",
  "gnopon/capability-audit-text",
  "gnopon/write-capability-audit",
  "gnopon/markdown-toggle-task-line",
  "gnopon/markdown-frontmatter-set-field",
  "gnopon/markdown-upsert-section",
  "gnopon/markdown-heading-entries",
  "gnopon/markdown-link-entries",
  "gnopon/markdown-structure-summary",
  "gnopon/markdown-structure-report",
  "gnopon/markdown-link-graph-report",
  "gnopon/markdown-link-graph-report-text",
  "gnopon/predication-frontmatter-string",
  "gnopon/turtle-string",
  "gnopon/turtle-local-name",
  "gnopon/create-predication-cell",
  "gnopon/validate-predications",
  "gnopon/formal-cockpit",
  "gnopon/formal-write-rdf",
  "gnopon/formal-write-shacl-schema",
  "gnopon/formal-write-proof-obligations",
  "gnopon/formal-validation-report",
  "gnopon/start-agent-session",
  "gnopon/start-codex-session",
  "gnopon/codex-cockpit",
  "gnopon-codex-resume-command",
  "gnopon-codex-resume-picker-command",
  "gnopon-codex-pass-project-root",
  "gnopon-codex-preserve-terminal-scrollback",
  "gnopon/codex-command-has-project-root-p",
  "gnopon/codex-command-has-no-alt-screen-p",
  "gnopon/codex-command-parts-for",
  "gnopon/codex-open-terminal",
  "gnopon/codex-resume-last",
  "gnopon/codex-resume-picker",
  "gnopon/codex-resume-workspace",
  "gnopon/codex-resume-picker-workspace",
  "gnopon/codex-command-executable-path",
  "gnopon/codex-dashboard",
  "gnopon-codex-dashboard-mode",
  "gnopon-codex-monitor-mode",
  "gnopon/codex-dashboard-text",
  "gnopon/codex-dashboard-render",
  "gnopon/codex-dashboard-refresh",
  "gnopon/codex-monitor-text",
  "gnopon/codex-monitor-render",
  "gnopon/codex-monitor-refresh",
  "gnopon/codex-monitor",
  "gnopon/codex-monitor-auto",
  "gnopon/codex-monitor-toggle-auto-refresh",
  "gnopon/codex-monitor-start-auto-refresh",
  "gnopon/codex-monitor-stop-auto-refresh",
  "gnopon-codex-monitor-actions",
  "gnopon/codex-monitor-button",
  "gnopon/codex-monitor-insert-actions",
  "gnopon-codex-cockpit-line-spacing",
  "gnopon/codex-polish-cockpit-buffer",
  "gnopon/codex-at-a-glance-section",
  "At A Glance",
  "Next Moves",
  "gnopon/codex-normalize-terminal-text",
  "gnopon/codex-transcript-tail-text",
  "terminal-normalization",
  "gnopon/codex-evidence-cursor-section",
  "gnopon/codex-brief-text",
  "gnopon/codex-brief",
  "gnopon/write-codex-brief",
  "gnopon/open-latest-codex-brief",
  "Codex Cockpit Brief",
  "brief-records",
  "gnopon-codex-composer-mode",
  "gnopon/codex-composer-template",
  "gnopon/codex-compose-prompt",
  "gnopon/codex-compose-region",
  "gnopon/codex-composer-prompt",
  "gnopon/codex-send-composer",
  "gnopon/codex-prompt-text",
  "gnopon/codex-prompt-record-text",
  "gnopon/write-codex-prompt-record",
  "gnopon/codex-evidence-section",
  "gnopon/codex-readiness-checks",
  "gnopon/codex-readiness-section",
  "gnopon/codex-evidence-files",
  "gnopon/codex-latest-evidence-path",
  "gnopon/open-latest-codex-evidence",
  "gnopon/open-latest-codex-session",
  "gnopon/open-latest-codex-prompt",
  "gnopon/open-latest-codex-transcript",
  "gnopon/codex-send-region",
  "gnopon/codex-send-buffer",
  "gnopon/codex-send-context-bundle",
  "gnopon/codex-transcript-text",
  "gnopon/write-codex-transcript",
  "Memory graph",
  "Formal validation",
  "Project command matrix",
  "Check project",
  "Test project",
  "latest evidence",
  "gnopon/codex-workspace",
  "gnopon/agent-handoff-text",
  "gnopon/open-agent-handoff",
  "gnopon/write-agent-handoff",
  "gnopon/agent-session-index",
  "gnopon/search-agent-sessions",
  "gnopon/close-agent-session",
  "gnopon/mcp-cockpit",
  "gnopon/mcp-write-indexes",
  "gnopon/mcp-resource-manifest-data",
  "gnopon/mcp-project-memory-index-data",
  "gnopon/mcp-agent-session-index-data",
  "flake.nix",
  "guix/manifest.scm",
  "scripts/repro-check.mjs",
  "scripts/startup-benchmark.mjs",
  "gnopon/safe-command-risk",
  "gnopon/project-command-candidates",
  "gnopon/project-command-matrix",
  "gnopon/run-project-command-candidate",
  "gnopon/redact-secrets",
  "gnopon/context-bundle",
  "gnopon/context-focus-section",
  "Focused Work Item",
  "gnopon/knowledge-vault",
  "gnopon/knowledge-vault-text",
  "gnopon/knowledge-vault-counts",
  "gnopon/capture-knowledge-note",
  "gnopon/capture-goal",
  "Gnoponics Knowledge Vault",
  "GitHub Markdown",
  "gnopon/copy-context-bundle",
  "gnopon/write-context-bundle",
  "gnopon/project-dashboard-text",
  "gnopon/workspace-snapshot-text",
  "gnopon/write-workspace-snapshot",
  "gnopon/dashboard-tool-section",
  "gnopon/github-dashboard",
  "gnopon/github-dashboard-text",
  "gnopon/context-actions",
  "gnopon/capture-current-note",
  "gnopon/create-predication-for-current-work",
  "gnopon/symbol-actions",
  "gnopon/code-status",
  "gnopon/code-action",
  "gnopon/show-diagnostics",
  "gnopon/review-cockpit",
  "gnopon/review-packet",
  "gnopon/write-review-packet",
  "gnopon/pr-body-draft",
  "gnopon/write-pr-body-file",
  "gnopon/copy-pr-body",
  "gnopon/gh-command-to-buffer",
  "gnopon/gh-pr-status",
  "gnopon/gh-pr-view-current",
  "gnopon/gh-issue-list",
  "gnopon/gh-pr-create-draft",
  "gnopon/control-center",
  "gnopon/welcome",
  "gnopon/safety-audit",
  "gnopon/safety-boundary-report",
  "gnopon/write-safety-audit",
  "gnopon/command-cockpit",
  "gnopon/command-preview-text",
  "gnopon/run-project-command",
  "gnopon/run-project-command-log",
  "gnopon/task-cockpit",
  "gnopon/task-dashboard",
  "gnopon/task-dashboard-text",
  "gnopon/capture-task",
  "gnopon/api-cockpit",
  "gnopon/api-status",
  "gnopon/curl-to-log",
  "gnopon/api-request-note",
  "gptel-make-ollama",
  "cargo clippy",
  "restclient",
  "dape",
  "apheleia",
]) {
  if (!allElisp.includes(requiredFeature) && !readme.includes(requiredFeature)) {
    throw new Error(`required feature marker missing: ${requiredFeature}`);
  }
}

const cli = readFileSync(new URL("scripts/gnoponemacs.mjs", root), "utf8");
for (const cliMarker of [
  "launch [-- EMACS_ARGS...]",
  "manifest [--json]",
  "catalog [--json]",
  "doctor [--json]",
  "install --target DIR",
  "function launchPlan",
  "function parsePackageManifest",
  "function parseDoctorTools",
  "function commandCatalog",
]) {
  if (!cli.includes(cliMarker)) {
    throw new Error(`CLI source is missing ${cliMarker}`);
  }
}
if (emacsPackageManifest.length === 0) {
  throw new Error("CLI manifest source did not expose Emacs packages");
}
const doctorToolsMatch = readFileSync(new URL("lisp/gnopon-doctor.el", root), "utf8").match(
  /\(defvar gnopon-doctor-tools\s+'\(([\s\S]*?)\)\s+"External tools/,
);
if (!doctorToolsMatch || !doctorToolsMatch[1].includes('"rg"') || !doctorToolsMatch[1].includes('"git"')) {
  throw new Error("doctor tool manifest is missing expected external tools");
}

if (!cli.includes("function parseInteractiveCommands") || !cli.includes("function parseKeybindings")) {
  throw new Error("CLI catalog source is missing command/keybinding parsers");
}

const keybindingMatches = [...allElisp.matchAll(/\(define-key\s+gnopon-map\s+\(kbd\s+"([^"]+)"\)\s+#'([^)]+)\)/g)];
const duplicateCatalogKeys = keybindingMatches
  .map((match) => `C-c g ${match[1]}`)
  .filter((key, index, keys) => keys.indexOf(key) !== index);
if (duplicateCatalogKeys.length > 0) {
  throw new Error(`GnoponEmacs has duplicate keybindings: ${[...new Set(duplicateCatalogKeys)].join(", ")}`);
}

const installTarget = mkdtempSync(join(tmpdir(), "gnoponemacs-install-"));
const install = spawnSync("node", ["scripts/gnoponemacs.mjs", "install", "--target", installTarget], {
  cwd: root.pathname,
  encoding: "utf8",
});
if (install.error) {
  console.log(`CLI install smoke skipped: ${install.error.message}`);
} else
if (install.status !== 0) {
  throw new Error(install.stderr || install.stdout || "CLI install failed");
}
if (!install.error) {
  for (const file of ["early-init.el", "init.el"]) {
    const link = join(installTarget, file);
    const expected = new URL(file, root).pathname;
    if (!existsSync(link) || resolve(installTarget, readlinkSync(link)) !== expected) {
      throw new Error(`CLI install did not create expected ${file} symlink`);
    }
  }
}

const launchDryRun = spawnSync("node", ["apps/gnoponemacs/scripts/gnoponemacs.mjs", "--dry-run", "--json"], {
  cwd: repositoryRoot.pathname,
  encoding: "utf8",
});
if (launchDryRun.error) {
  console.log(`CLI launch dry-run smoke skipped: ${launchDryRun.error.message}`);
} else if (launchDryRun.status !== 0) {
  throw new Error(launchDryRun.stderr || launchDryRun.stdout || "CLI launch dry-run failed");
} else {
  const dryRunText = launchDryRun.stdout.trim();
  if (dryRunText === "") {
    throw new Error("CLI launch dry-run produced empty JSON output");
  }
  const launchPlan = JSON.parse(dryRunText);
  if (
    launchPlan.command !== "emacs" ||
    !launchPlan.args.includes("--init-directory") ||
    !launchPlan.args.includes(root.pathname.replace(/\/$/, "")) ||
    !launchPlan.args.includes("--chdir") ||
    !launchPlan.args.includes(repositoryRoot.pathname.replace(/\/$/, ""))
  ) {
    throw new Error(`CLI launch dry-run did not target package init and repository cwd: ${launchDryRun.stdout}`);
  }
}

const requiredHeadings = [
  "## Architecture And UX Philosophy",
  "## Implementation Plan",
  "## Directory Structure",
  "## Bootstrap Strategy",
  "## Package Management",
  "## Reproducible Environments",
  "## Completion, Search, And Navigation",
  "## Rust And Node Engineering",
  "## API And CLI Engineering",
  "## Markdown Knowledge System",
  "## Formal Validation",
  "## Cockpit Commands",
  "## Agentic Programming",
  "## Security Model",
  "## Testing And Debugging",
  "## Roadmap",
];

for (const heading of requiredHeadings) {
  if (!readme.includes(heading)) {
    throw new Error(`README.md is missing heading ${heading}`);
  }
}

const emacs = spawnSync("emacs", ["--batch", "-Q", "--eval", "(princ emacs-version)"], {
  encoding: "utf8",
});

if (emacs.status === 0) {
  console.log(`Emacs available: ${emacs.stdout.trim()}`);
  const modules = readdirSync(new URL("lisp/", root))
    .filter((file) => file.endsWith(".el"))
    .map((file) => new URL(`lisp/${file}`, root).pathname);
  const elispModuleList = modules.map((file) => JSON.stringify(file)).join(" ");
  const parenCheck = spawnSync(
    "emacs",
    [
      "--batch",
      "-Q",
      "--eval",
      `(progn
         (dolist (file (list ${elispModuleList}))
           (with-current-buffer (find-file-noselect file)
             (check-parens)))
         (princ "checked"))`,
    ],
    { encoding: "utf8" },
  );
  if (parenCheck.status !== 0) {
    throw new Error(parenCheck.stderr || parenCheck.stdout || "Emacs paren check failed");
  }
  const test = spawnSync(
    "emacs",
    [
      "--batch",
      "-Q",
      "-L",
      new URL("lisp/", root).pathname,
      "-l",
      new URL("tests/gnopon-lib-test.el", root).pathname,
      "-f",
      "ert-run-tests-batch-and-exit",
    ],
    { encoding: "utf8" },
  );
  if (test.status !== 0) {
    throw new Error(test.stderr || test.stdout || "Emacs ERT tests failed");
  }
  const loadSmoke = spawnSync(
    "emacs",
    [
      "--batch",
      "-Q",
      "-l",
      new URL("tests/gnopon-load-smoke.el", root).pathname,
    ],
    { encoding: "utf8" },
  );
  if (loadSmoke.status !== 0) {
    throw new Error(loadSmoke.stderr || loadSmoke.stdout || "Emacs no-network load smoke failed");
  }
  const realInitFallback = spawnSync(
    "emacs",
    [
      "--batch",
      "-Q",
      "--eval",
      `(let* ((package-root ${JSON.stringify(root.pathname)})
              (user-emacs-directory
               (file-name-as-directory (make-temp-file "gnopon-real-init-" t))))
         (require 'package)
         (advice-add 'package-refresh-contents
                     :override
                     (lambda (&rest _)
                       (message "GnoponEmacs test: package refresh disabled")))
         (advice-add 'package-install
                     :override
                     (lambda (&rest _)
                       (message "GnoponEmacs test: package install disabled")))
         (load (expand-file-name "init.el" package-root) nil nil)
         (unless (eq (lookup-key global-map (kbd "C-c g")) gnopon-map)
           (error "C-c g is not bound to gnopon-map"))
         (unless (eq (lookup-key global-map (kbd "M-SPC")) 'gnopon/cockpit)
           (error "M-SPC is not bound to gnopon/cockpit"))
         (dolist (binding '(("?" . gnopon/welcome)
                            ("o" . gnopon/control-center)
                            ("m k" . gnopon/knowledge-vault)
                            ("a x" . gnopon/codex-cockpit)
                            ("a Z" . gnopon/codex-workspace)
                            ("a z" . gnopon/codex-resume-workspace)
                            ("a j" . gnopon/codex-resume-picker-workspace)
                            ("a A" . gnopon/codex-monitor)
                            ("a S" . gnopon/codex-shell)
                            ("a J" . gnopon/codex-resume-picker)
                            ("a L" . gnopon/codex-resume-last)))
           (unless (eq (lookup-key gnopon-map (kbd (car binding))) (cdr binding))
             (error "GnoponEmacs key %s is not bound to %s"
                    (car binding)
                    (cdr binding))))
         (princ "GnoponEmacs real init fallback smoke passed."))`,
    ],
    { cwd: repositoryRoot.pathname, encoding: "utf8" },
  );
  if (realInitFallback.status !== 0) {
    throw new Error(realInitFallback.stderr || realInitFallback.stdout || "Emacs real init fallback smoke failed");
  }
  const commandTest = spawnSync(
    "emacs",
    [
      "--batch",
      "-Q",
      "-l",
      new URL("tests/gnopon-load-smoke.el", root).pathname,
      "-l",
      new URL("tests/gnopon-command-test.el", root).pathname,
      "-f",
      "ert-run-tests-batch-and-exit",
    ],
    { encoding: "utf8" },
  );
  if (commandTest.status !== 0) {
    throw new Error(commandTest.stderr || commandTest.stdout || "Emacs command ERT tests failed");
  }
  const mcpExport = spawnSync(
    "emacs",
    [
      "--batch",
      "-Q",
      "-l",
      new URL("tests/gnopon-load-smoke.el", root).pathname,
      "--eval",
      `(let* ((default-directory (file-name-as-directory (make-temp-file "gnopon-mcp-" t))))
         (make-directory (expand-file-name ".git/" default-directory) t)
         (let* ((root (file-truename (gnopon/project-root)))
                (predication-dir (expand-file-name "docs/predications/" root))
                (agent-dir (expand-file-name "logs/agent/" root)))
         (with-temp-file (expand-file-name "README.md" root)
           (insert "# Temp Project\\n"))
         (with-temp-file (expand-file-name "AGENTS.md" root)
           (insert "# AGENTS\\n"))
         (make-directory predication-dir t)
         (with-temp-file (expand-file-name "20260617-demo.md" predication-dir)
           (insert (gnopon/predication-frontmatter-string
                    "temp" "exports" "memory" "present" "strict" "knowledge"))
           (insert "# temp / exports / memory\\n"))
         (make-directory agent-dir t)
         (with-temp-file (expand-file-name "20260617-120000-demo.md" agent-dir)
           (insert (gnopon/markdown-frontmatter-string "Demo session" "active" "2026-06-17" '("agent" "session")))
           (insert "# Demo session\\n"))
         (gnopon/mcp-write-indexes)
         (dolist (file '("resources.json" "project-memory.json" "agent-sessions.json"))
           (unless (file-readable-p (expand-file-name (concat "logs/mcp/" file) root))
             (error "MCP export did not write %s" file)))
         (with-temp-buffer
           (insert-file-contents (expand-file-name "logs/mcp/resources.json" root))
           (let ((manifest (buffer-string)))
             (unless (and (string-match-p "README.md" manifest)
                          (string-match-p "agent-session" manifest)
                          (string-match-p "predication-cell" manifest))
               (error "MCP resource manifest is missing expected resources"))))
         (princ "GnoponEmacs MCP export smoke passed.")))`,
    ],
    { encoding: "utf8" },
  );
  if (mcpExport.status !== 0) {
    throw new Error(mcpExport.stderr || mcpExport.stdout || "Emacs MCP export smoke failed");
  }
  const formalExport = spawnSync(
    "emacs",
    [
      "--batch",
      "-Q",
      "-l",
      new URL("tests/gnopon-load-smoke.el", root).pathname,
      "--eval",
      `(let* ((default-directory (file-name-as-directory (make-temp-file "gnopon-formal-" t))))
         (make-directory (expand-file-name ".git/" default-directory) t)
         (let* ((root (file-truename (gnopon/project-root)))
                (predication-dir (expand-file-name "docs/predications/" root)))
           (make-directory predication-dir t)
           (with-temp-file (expand-file-name "20260617-demo.md" predication-dir)
             (insert (gnopon/predication-frontmatter-string
                      "agent" "maintains" "evidence" "present" "strict" "knowledge"))
             (insert "# agent / maintains / evidence\\n"))
           (gnopon/formal-bootstrap)
           (dolist (file '("schema.ttl" "predications.ttl" "proof-obligations.md"))
             (unless (file-readable-p (expand-file-name (concat "docs/formal/" file) root))
               (error "Formal export did not write %s" file)))
           (with-temp-buffer
             (insert-file-contents (expand-file-name "docs/formal/predications.ttl" root))
             (let ((ttl (buffer-string)))
               (unless (and (string-match-p "g:PredicationCell" ttl)
                            (string-match-p "agent" ttl)
                            (string-match-p "g:present" ttl))
                 (error "Formal RDF export is missing expected triples"))))
           (with-temp-buffer
             (insert-file-contents (expand-file-name "docs/formal/proof-obligations.md" root))
             (unless (search-forward "Evidence block names an inspectable source" nil t)
               (error "Formal proof obligations are missing expected checklist")))
           (princ "GnoponEmacs formal export smoke passed.")))`,
    ],
    { encoding: "utf8" },
  );
  if (formalExport.status !== 0) {
    throw new Error(formalExport.stderr || formalExport.stdout || "Emacs formal export smoke failed");
  }
  const prBodyExport = spawnSync(
    "emacs",
    [
      "--batch",
      "-Q",
      "-l",
      new URL("tests/gnopon-load-smoke.el", root).pathname,
      "--eval",
      `(let* ((default-directory (file-name-as-directory (make-temp-file "gnopon-pr-body-" t))))
         (make-directory (expand-file-name ".git/" default-directory) t)
         (let* ((root (file-truename (gnopon/project-root)))
                (path (gnopon/write-pr-body-file nil)))
           (unless (file-readable-p path)
             (error "PR body export did not write a file"))
           (with-temp-buffer
             (insert-file-contents path)
             (let ((body (buffer-string)))
               (unless (and (string-match-p "## Summary" body)
                            (string-match-p "## Tests" body)
                            (string-match-p "## Review Notes" body))
                 (error "PR body export is missing expected sections"))))
           (unless (string-prefix-p (expand-file-name "logs/review/" root) path)
             (error "PR body export wrote outside logs/review"))
           (princ "GnoponEmacs PR body export smoke passed.")))`,
    ],
    { encoding: "utf8" },
  );
  if (prBodyExport.status !== 0) {
    throw new Error(prBodyExport.stderr || prBodyExport.stdout || "Emacs PR body export smoke failed");
  }
  const markdownStructure = spawnSync(
    "emacs",
    [
      "--batch",
      "-Q",
      "-l",
      new URL("tests/gnopon-load-smoke.el", root).pathname,
      "--eval",
      `(let* ((default-directory (file-name-as-directory (make-temp-file "gnopon-md-structure-" t))))
         (make-directory (expand-file-name ".git/" default-directory) t)
         (let ((docs-dir (expand-file-name "docs/" default-directory)))
           (make-directory docs-dir t)
           (with-temp-file (expand-file-name "README.md" default-directory)
             (insert "# Demo\\n\\nSee [Spec](docs/spec.md).\\n\\n- [ ] Ship structure report\\n"))
           (with-temp-file (expand-file-name "spec.md" docs-dir)
             (insert "# Spec\\n\\n## Goals\\n\\n[[README|readme]]\\n"))
           (let ((report (gnopon/markdown-structure-report-text)))
             (unless (and (string-match-p "Markdown Structure Report" report)
                          (string-match-p "README.md" report)
                          (string-match-p "docs/spec.md" report)
                          (string-match-p "Ship structure report" report)
                          (string-match-p "Spec" report))
               (error "Markdown structure report is missing expected content")))
           (princ "GnoponEmacs Markdown structure smoke passed.")))`,
    ],
    { encoding: "utf8" },
  );
  if (markdownStructure.status !== 0) {
    throw new Error(markdownStructure.stderr || markdownStructure.stdout || "Emacs Markdown structure smoke failed");
  }
} else {
  console.log("Emacs is not available; checked package structure and README sections only.");
}

console.log("GnoponEmacs package check passed.");
