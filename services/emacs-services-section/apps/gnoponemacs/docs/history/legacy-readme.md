# GnoponEmacs

GnoponEmacs is a Markdown-native Emacs cockpit for agentic programmers: fast startup, polished navigation, Rust/Node engineering, GitHub-first documentation, project memory, terminals, diagnostics, diffs, tests, and human-controlled AI workflows.

It deliberately does not center Org mode.
Project planning and knowledge work happen in clean GitHub-flavored Markdown, YAML frontmatter, Markdown task lists, and project-native files such as `README.md`, `SPEC.md`, `PLAN.md`, `TODO.md`, `CHANGELOG.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, ADRs, and RFCs.

## Architecture And UX Philosophy

The UX target is a 2026-era programmable engineering cockpit, not a traditional personal Emacs scrapbook.
The system has one command space, rich completion, contextual actions, project-aware terminals, first-class diffs, fast search, visible diagnostics, and explicit agent boundaries.

The architecture is a small kernel plus capability modules:

- `early-init.el`: strict early startup and native-comp/UI suppression.
- `init.el`: direct module loader, no tangling and no document syntax dependency.
- `lisp/gnopon-core.el`: package bootstrap, state paths, command prefix, project helpers.
- `lisp/gnopon-ui.el`: theme, modeline, discoverability, command help.
- `lisp/gnopon-workspace.el`: tabs, dashboards, window undo, popup management.
- `lisp/gnopon-completion.el`: minibuffer, search, navigation, completion-at-point.
- `lisp/gnopon-programming.el`: tree-sitter, Eglot, Flymake, language modes, compile/test commands.
- `lisp/gnopon-ide.el`: symbol navigation, code actions, diagnostics, code-status cockpit.
- `lisp/gnopon-api.el`: `.http` request files, JSON/JQ, explicit curl helpers, API cockpit.
- `lisp/gnopon-markdown.el`: Markdown/YAML docs, task files, backlinks, context files.
- `lisp/gnopon-tasks.el`: GitHub Markdown task cockpit and task dashboard.
- `lisp/gnopon-predication.el`: one-file-per-cell predication notes, bilattice-style values, validation.
- `lisp/gnopon-formal.el`: RDF/Turtle export, SHACL shape scaffolds, and proof obligations.
- `lisp/gnopon-git.el`: Magit, Forge, diff hunk workflow.
- `lisp/gnopon-shell.el`: project shells, terminal buffers, safe command runner.
- `lisp/gnopon-context.el`: redacted Markdown context bundles for human-controlled AI use.
- `lisp/gnopon-agents.el`: controlled agent context, Codex cockpit, shells, patch review, commit/PR drafting helpers.
- `lisp/gnopon-mcp.el`: local MCP-style JSON resource manifests for memory and agent records.
- `lisp/gnopon-review.el`: review packets, evidence capture, and GitHub PR handoff drafts.
- `lisp/gnopon-actions.el`: contextual action palette for current file, buffer, and project work.
- `lisp/gnopon-security.el`: auth-source, GPG, safety audits, explicit AI boundaries.
- `lisp/gnopon-persistence.el`: backups, autosaves, history, recent files, places.
- `lisp/gnopon-capability.el`: requirement-to-command capability audits.
- `lisp/gnopon-control.el`: first-run welcome and button-driven control center.
- `lisp/gnopon-cockpit.el`: transient command palette for the whole system.
- `lisp/gnopon-cwe.el`: multi-agent cockpit over `@emsenn/computing-with-emacs` — the interactive chooser plus chat-and-monitor window layout, bound to the 561 `cockpit.config.json`.

The 561 Group mathematical frame is implemented operationally.
Strict/scott/transfinite/aperiodic become evidence and validation regimes for project memory.
Truth/knowledge/conflict/gap labels make paraconsistent state explicit instead of erasing disagreement.
Agent sessions are treated as strategies in a project arena and must leave inspectable evidence: context, command logs, diffs, tests, and review notes.

Predication work is represented as normal Markdown: one predication cell per file under `docs/predications/`, with YAML frontmatter for `subject`, `predicate`, `object`, bilattice-style `value`, `evidence-regime`, `evidence-side`, and `depends-on`.
This follows the research-library pattern of typed notes as predication cells while keeping every artifact readable on GitHub.

## Implementation Plan

1. Keep startup direct: no Org Babel, no generated init, no hidden network work in early init.
2. Use built-in Emacs where it is strong: `project.el`, `xref`, `eglot`, `flymake`, `compile`, `auth-source`.
3. Add best-in-class packages where they materially improve UX: Vertico, Orderless, Marginalia, Consult, Embark, Corfu, Magit, Forge, Eat, Markdown Mode, YAML Mode, Transient, Which-key.
4. Make Markdown the knowledge substrate through commands for frontmatter, task navigation, context files, ADR/RFC/SPEC/PLAN/TODO creation, backlinks, and project memory search.
5. Make agent workflows explicit: prepare context, launch a project-scoped terminal, review generated diffs, stage hunks, run tests, draft commit messages and PR descriptions locally.
6. Keep AI optional and local-first.
  `gptel` is configured for Ollama by default and never silently sends buffers.

## Directory Structure

```text
apps/gnoponemacs/
  README.md
  package.json
  flake.nix
  guix/
    channels.scm
    manifest.scm
  early-init.el
  init.el
  scripts/gnoponemacs.mjs
  lisp/
    gnopon-core.el
    gnopon-ui.el
    gnopon-workspace.el
    gnopon-completion.el
    gnopon-editing.el
    gnopon-programming.el
    gnopon-ide.el
    gnopon-api.el
    gnopon-markdown.el
    gnopon-tasks.el
    gnopon-predication.el
    gnopon-formal.el
    gnopon-git.el
    gnopon-shell.el
    gnopon-context.el
    gnopon-agents.el
    gnopon-mcp.el
    gnopon-review.el
    gnopon-actions.el
    gnopon-security.el
    gnopon-persistence.el
    gnopon-capability.el
    gnopon-control.el
    gnopon-cockpit.el
  scripts/check.mjs
```

Install by symlinking the package bootstrap into an Emacs config directory:

```sh
node apps/gnoponemacs/scripts/gnoponemacs.mjs install --target ~/.config/emacs
node apps/gnoponemacs/scripts/gnoponemacs.mjs
pnpm --dir apps/gnoponemacs start
make gnoponemacs
node apps/gnoponemacs/scripts/gnoponemacs.mjs manifest
node apps/gnoponemacs/scripts/gnoponemacs.mjs catalog
node apps/gnoponemacs/scripts/gnoponemacs.mjs doctor
```

The `gnoponemacs` package bin launches `emacs --init-directory apps/gnoponemacs --chdir $PWD`, so it uses this package as the active Emacs configuration while preserving the caller's project directory.
From the super-repo root, `make gnoponemacs` opens GnoponEmacs at the repository root.

### Agent cockpit

`make gnoponemacs run` opens GnoponEmacs at the repository root and immediately
presents the interactive agent cockpit chooser (`gnopon/cockpit-launch`, also at
`C-c g a g`). Pick Claude CLI, Codex CLI, or the OpenAI Agent TUI; the chosen chat
program runs live in the main pane while monitor panes beside it tail the
Operations Manifold context-injection, hook, and message streams — so you watch
exactly what the agent is fed and how the harness reacts.

The chat pane renders through the rich `eat` terminal (truecolor; Claude's and
Codex's full-screen TUIs display correctly), falling back to the built-in `term`
when `eat` is absent.

Every launch opens its **own session with its own character**, not a shared
"claude": a persona (name, colour, glyph, bio — drawn from the `personas` pool in
`cockpit.config.json`) tints the chat header, namespaces the buffers, exports the
session identity as env (`CWE_SESSION`/`CWE_PERSONA`) to the CLI, and gets a
leading "world" pane holding that session's persona card. Run it twice and two
distinct characters sit side by side.

For Claude, the character is a **discrete embodiment built from Claude Code's own
capabilities** (see `cockpit.config.json` → `claude.identity`):

- `--session-id` is pinned to the cockpit session id, so the persona, the cockpit
  session, and the Operations Manifold world are one key.
- `--name` gives Claude's own UI the character's name.
- `--append-system-prompt` embodies the character (name, glyph, bio).
- `CLAUDE_CONFIG_DIR` points at `apps/gnoponemacs/var/characters/<persona>/` — the
  character's **own** history, todos, and `CLAUDE.md` memory, seeded once and kept
  across that character's sessions, importing the shared
  `var/characters/_shared/MEMORY.md` so all the Claudes share deeper memory.

So each Claude session is a separate self with its own data and memory, while
sharing deeper memory and the general systems with its siblings.

The cockpit topology is owned by `@emsenn/computing-with-emacs` (the reusable,
environment-agnostic library); everything 561-specific lives in
`cockpit.config.json` (the agents and the stream log paths) and the path bindings
in `lisp/gnopon-cwe.el`. Build the library once so the bin is present:

```sh
pnpm --filter @emsenn/computing-with-emacs run build
```

## Bootstrap Strategy

`early-init.el` only handles startup constraints.
`init.el` resolves the real package path, extends `load-path`, and requires modules in a deterministic order.
Startup does not require package archive access: optional UI, completion, editing, and formatting packages degrade away when they are absent, while the GnoponEmacs prefix map, Markdown knowledge vault, and agent cockpit entry points still load.
Reproducible deployments should pin the Emacs binary and package closure with Guix, Nix, or an OS image.

## Package Management

Default: built-in `package.el` plus built-in `use-package`.
It is boring, inspectable, and good enough for a durable base.
GnoponEmacs declares the expected package closure but does not install that closure during critical startup, because opening the cockpit should not depend on network availability.
Optional third-party packages are declared through `gnopon/use-optional-package` or a direct `gnopon/optional-package-available-p` guard; missing packages skip their integrations instead of aborting init.
`package-quickstart` is disabled to avoid stale autoload caches that reference removed package files.
`straight.el` and `elpaca` are valid later choices if Git-level pinning becomes more important than bootstrap simplicity.

The core module declares `gnopon-package-manifest` and assigns it to `package-selected-packages`, so the expected package closure is visible in one place.
`node apps/gnoponemacs/scripts/gnoponemacs.mjs manifest --json` exposes that package closure and the expected external tool list for CI, provisioning, and the Guix/Nix manifests.
`node apps/gnoponemacs/scripts/gnoponemacs.mjs catalog --json` statically indexes modules, interactive commands, transient cockpits, and `C-c g` keybindings so the command surface is inspectable before launching Emacs.
Hard reproducibility should still pin Emacs and ELPA archives outside Emacs with Guix, Nix, or an OS image.

## Reproducible Environments

The default bootstrap remains `package.el` because it is transparent inside ordinary Emacs installs.
For pinned environments, use the package-root `flake.nix` or Guix manifest instead of relying on ad hoc first-launch package installation.

Nix:

```sh
cd apps/gnoponemacs
nix develop
nix build .#emacs
```

The flake builds an Emacs package closure from `gnopon-package-manifest` and opens a shell with Rust, Node, GitHub, ripgrep, JSON, shell, Markdown, and local AI tools.

Guix:

```sh
cd apps/gnoponemacs
guix time-machine -C guix/channels.scm -- shell -m guix/manifest.scm
```

`guix/channels.scm` is intentionally minimal; pin it to an exact Guix commit in production.
Some newer MELPA-derived packages may require an additional Guix channel depending on the user's Guix revision.

Reproducibility checks:

```sh
pnpm --dir apps/gnoponemacs repro
pnpm --dir apps/gnoponemacs repro -- --require-tools
```

Both commands run `scripts/repro-check.mjs`.
The first form always checks that `flake.nix` and `guix/manifest.scm` contain the Emacs package closure declared by `gnopon-package-manifest`, and skips Nix/Guix evaluation when the tools are unavailable.
The `--require-tools` form is intended for CI runners that install `nix` and `guix`; it fails if either tool is missing or if `nix flake check --no-build` / Guix manifest dry-run evaluation fails.

## Startup Performance Strategy

Startup stays fast by disabling package activation in `early-init.el`, raising GC only during startup, loading modules directly, deferring heavy packages, avoiding Org tangling, and keeping language servers opt-in unless `gnopon-enable-eglot-auto` is set.

Benchmark the deterministic no-network bootstrap path with:

```sh
pnpm --dir apps/gnoponemacs benchmark -- --iterations 5 --json
pnpm --dir apps/gnoponemacs benchmark -- --iterations 5 --max-ms 1500
```

The benchmark runs `scripts/startup-benchmark.mjs`, which invokes `tests/gnopon-load-smoke.el` under `emacs --batch -Q`, so it measures module loading and command registration without first-launch package installation or network-dependent archive refreshes.

Inside Emacs, `C-c g d p` opens `gnopon/performance-report`, generated by `gnopon/performance-report-text`; `C-c g d P` writes the same report under `logs/performance/`.
It captures startup seconds, garbage collections, GC threshold, process output size, package closure size, loaded Gnopon modules, native-comp availability, state directories, and the external benchmark commands needed for release evidence.

## Keybinding Model

The cockpit prefix is `C-c g`; `M-SPC` opens the transient cockpit launcher when `transient` is available.
Package-native maps stay intact.
The prefix is organized by work:

- `o`: control center.
- `?
  `: first-run welcome.
- `a`: agents and AI boundaries.
- `d`: diagnostics and config debugging.
- `i`: symbol navigation, diagnostics, code actions, and rename.
- `.
  `: contextual actions for the current file, buffer, or project.
- `g`: Git and GitHub.
- `m`: Markdown memory.
- `p`: programming, tests, compile, LSP.
- `s`: shells and terminals.

## Completion, Search, And Navigation

The stack is Vertico, Orderless, Marginalia, Consult, Embark, Corfu, Cape, Project, Xref, Imenu, and ripgrep.
This gives command-palette behavior without replacing Emacs primitives.

`C-c g i` opens the symbol action cockpit: buffer symbol index, references, project search for the symbol at point, Eglot code actions, rename, diagnostics, formatting, checks, tests, and linting.
`M-SPC .
` remains the broader current-work action surface.

Graphical sessions also get icon-enhanced completion and Dired through Nerd Icons.
`consult-dir` adds fast directory jumping across projects and recent paths.

## Rust And Node Engineering

Rust uses `rust-mode`, tree-sitter where available, Eglot with `rust-analyzer`, Flymake, `cargo check`, `cargo test`, `cargo clippy`, Dape debugging, and formatting through Eglot or Apheleia.
Node/TypeScript uses `typescript-mode`, tree-sitter where available, Eglot with `typescript-language-server`, package-manager detection for npm/pnpm/yarn/bun, project-local package scripts, lint/check/test commands, and compile buffers for logs.

`C-c g p m` opens `gnopon/project-command-matrix`, generated by `gnopon/project-command-matrix-text`.
It detects Cargo commands, package.json scripts, and Makefile entry points, then shows them as a GitHub-renderable command matrix with command kind, label, shell command, and source.
`C-c g p r` runs a selected detected candidate through the normal project compile buffer.

## API And CLI Engineering

API work uses `.http` and `.rest` files through Restclient, `requests.http` project scratch files, JSON/JQ modes, `.env.example` documentation, and explicit `curl` helpers that ask before running.
`C-c g p a` opens the API cockpit for HTTP scratch files, JSON and jq scratch files, request notes under `docs/api/`, API status, curl-to-buffer, and curl-to-log evidence under `logs/api/`.
CLI work stays in compile buffers or project terminals so logs remain visible and reusable.

## Markdown Knowledge System

Markdown Mode and YAML Mode are the document substrate.
GnoponEmacs provides commands for:

- opening or creating `README.md`, `GOALS.md`, `SPEC.md`, `PLAN.md`, `TODO.md`, `CHANGELOG.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, and standard `docs/` memory indexes;
- opening the Gnoponics knowledge vault with `C-c g m k`;
- capturing goals in `GOALS.md` and knowledge notes under `docs/notes/`;
- inserting YAML frontmatter;
- inserting and toggling Markdown task items with `C-c g m n` / `C-c g m N`;
- parsing/updating YAML frontmatter, headings, links, tasks, and replacing Markdown sections through tested helper functions;
- searching backlinks and unresolved tasks with ripgrep;
- creating ADR and RFC files under `docs/adr/` and `docs/rfc/`;
- inserting evidence blocks labeled by regime and side.
- generating a project memory index from known context files and open task scans.
- opening a Markdown link graph report with present links, missing links, external links, incoming/outgoing counts, and orphaned memory files.
- bootstrapping standard context files and syncing `CLAUDE.md` / `GEMINI.md` from `AGENTS.md`.
- validating project memory by scanning evidence labels and Markdown task markers.
- opening a task cockpit for TODO capture, task dashboards, task search, and task toggling.
- creating, inserting, indexing, searching, and validating Markdown predication cells under `docs/predications/`.
- exporting predication cells to RDF/Turtle and proof-obligation checklists under `docs/formal/`.
- opening a Markdown structure report with per-file heading, H1, link, and task counts.

`C-c g m k` opens `gnopon/knowledge-vault`, the shared knowledge-cultivation surface for humans and agents.
It treats goals, plans, tasks, notes, predication cells, agent sessions, Codex prompt records, Codex transcripts, link graphs, MCP exports, and validation reports as one GitHub Markdown vault.
The local keys are intentionally direct: `G` opens goals, `p` opens the plan, `t` captures a task, `n` captures a knowledge note, `c` previews the context bundle, `a` opens the Codex dashboard, `A` opens the Codex workspace, `m` opens MCP exports, `l` opens the link graph, and `v` validates project memory.

`C-c g m g` opens `gnopon/markdown-link-graph-report`, generated by `gnopon/markdown-link-graph-report-text`.
It turns ordinary Markdown and wiki-style links into an inspectable project-memory graph without leaving GitHub-renderable files: present edges, missing local targets, external references, per-file incoming/outgoing counts, and orphaned memory files are all visible in one report.

## Formal Validation

Predication cells remain the source of truth because they are normal Markdown files with YAML frontmatter and GitHub-readable evidence sections.
`C-c g m F` opens the formal validation cockpit for projects that need a stronger interface to shape validation and proof review.

The formal layer writes:

- `docs/formal/schema.ttl`: a SHACL/Turtle shape for predication cells;
- `docs/formal/predications.ttl`: generated RDF/Turtle triples from Markdown predication frontmatter;
- `docs/formal/proof-obligations.md`: Markdown checklists for evidence, dependencies, conflict/gap labels, and latest-diff review.

This is intentionally a scaffold, not a hidden theorem prover.
It gives agents and humans stable artifacts to inspect, commit, and hand to external RDF/SHACL tooling while keeping project memory readable in GitHub.

## Cockpit Commands

`M-SPC` opens the transient cockpit.
It groups project search, the doctor report, tests, checks, linting, formatting, package scripts, debugging, HTTP scratch files, Markdown memory, local MCP exports, agent actions, and Git review.
`C-c g o` opens a button-driven control center for first-run and daily operation.
`C-c g .
` opens contextual actions for the current file or buffer: copy a GitHub-friendly reference, capture a Markdown note, create a predication cell, copy/open redacted context, run tests, and review diffs.
The normal `C-c g` prefix remains available for direct keyboard access.

`C-c g a x` opens the Codex cockpit.
`C-c g a Z` builds the agent cockpit layout: a Markdown dashboard on the left, a project-scoped Codex terminal on the upper right, and a live Codex chat monitor under the terminal.
`C-c g a z` builds the same layout while running `gnopon-codex-resume-command`, which defaults to `codex resume --last`, so a new shell can run `make gnoponemacs` and then resume the latest project Codex session from inside Emacs.
`C-c g a L` resumes the latest Codex session in the normal project Codex terminal without rebuilding the window layout.
`C-c g a J` opens Codex's interactive resume picker, and `C-c g a j` opens the full dashboard/terminal/monitor cockpit around that picker.
Codex commands are project-root aware: when `gnopon-codex-pass-project-root` is non-nil, GnoponEmacs appends `-C <project-root>` unless the configured command already supplies `-C` or `--cd`.
When `gnopon-codex-preserve-terminal-scrollback` is non-nil, GnoponEmacs also appends `--no-alt-screen` unless already present, so the Emacs monitor can read useful chat scrollback.
The monitor shows a redacted tail of the chat buffer after stripping ANSI and control sequences, the latest evidence cursor across session/prompt/transcript/brief files, prompt/transcript/brief counts, lawfulness links, conformance links, local refresh/navigation keys, and live buttons for the normal monitor actions.
`C-c g a o` previews a Codex cockpit brief; `C-c g a k` writes that brief under `logs/agent/` with current readiness, evidence cursor, Git state, diff stat, operating loop, and live chat tail.
`C-c g a q` opens an editable Markdown prompt composer; `C-c g a Q` seeds the composer from the active region.
In the composer, `C-c C-c` sends the `## Prompt` section to Codex after confirmation, `C-c C-b` inserts the project context bundle, `C-c C-l` resumes the latest Codex session, `C-c C-j` opens the resume picker, and `C-c C-k` discards the staged prompt.
The dashboard and monitor both render Codex Readiness checks for executable availability, resume command availability, resume picker availability, monitor scrollback, terminal normalization, terminal state, Markdown context memory, prompt evidence, transcript evidence, cockpit briefs, Codex session records, and live chat transcript text.
The dashboard frames the chat buffer with the current project, command risk, executable readiness, memory files, task counts, Git state, diff stat, recent agent sessions, context/handoff commands, prompt composition, prompt sending, prompt/transcript/brief evidence counts, recent evidence records, and check/test/review paths.
Dashboard and monitor buffers both render live buttons plus local keys for refresh, terminal launch, session resume, session picker, prompt composition, redacted context-bundle prompts, memory graph, formal validation, check/test, latest evidence navigation, transcript, brief, and diff-review actions.
It does not send buffers to Codex silently; prompt sending requires explicit confirmation and writes a Markdown prompt record.

Codex cockpit buffers use a readable Emacs presentation layer on top of GitHub Markdown: visual line wrapping, local line spacing, no horizontal truncation, and an `At A Glance` / `Next Moves` section before the dense readiness, evidence, and transcript sections.
The underlying files remain plain Markdown; the Emacs view is tuned so the operator can scan state and act without parsing a terminal dump.

`C-c g w d` opens `gnopon/project-dashboard`, a project cockpit buffer generated by `gnopon/project-dashboard-text`.
It summarizes project memory readiness, task counts, Git state, external tool readiness, and the main command paths for build, API, agent, review, and capability work.

`C-c g w s` opens `gnopon/workspace-snapshot`, generated by `gnopon/workspace-snapshot-text`; `C-c g w S` writes the same report under `logs/workspace/`.
The snapshot shows open project files, modified buffers, recent project files, tab names, and resume commands so a human or agent can quickly re-enter the current work state.

`C-c g s c` opens the safe command runner.
Commands are classified with the same low/write/network/dangerous risk model used by agent logging.
Dangerous commands are refused; all other commands require confirmation and run visibly through `compile` or a Markdown command log under `logs/shell/`.

## Doctor And Operations

`M-SPC !
` or `C-c g d d` opens `gnopon/doctor`, a Markdown-rendered health report generated by `gnopon/doctor-text` for Emacs, the active project, package state, selected package closure, and external tools.
It checks for search, GitHub, Rust, Node, shell, JSON, direnv, Markdown, and local AI tooling without installing or mutating anything.
`C-c g d D` writes the same report under `logs/doctor/` as release or handoff evidence.

`C-c g d c` opens `gnopon/capability-audit`, a Markdown report that maps the cockpit requirements to concrete modules, commands, tests, and reproducibility artifacts.
`C-c g d C` writes the same report under `logs/capability/` for release review or agent handoff evidence.

`C-c g d a` opens `gnopon/safety-audit`, a redacted Markdown safety report for the current project.
It classifies the configured agent command, restates the AI/shell/Git invariants, scans likely secret-bearing lines with redaction, and previews unstaged/staged diffs through the same redaction path.
`C-c g d A` writes the audit under `logs/security/`.

Outside Emacs, `node apps/gnoponemacs/scripts/gnoponemacs.mjs doctor --json` reports the package root, Node runtime, Emacs availability, install-link status, expected Emacs package closure, and external tool status.
`node apps/gnoponemacs/scripts/gnoponemacs.mjs catalog --json` reports the static module, command, and keybinding catalog for docs, CI checks, and agent handoffs.
The installer refuses pre-existing `early-init.el` or `init.el` symlinks if they point somewhere other than this package.

## Git And GitHub Review Loops

Magit is the default Git UI.
Diff-hl shows working tree state in buffers.
Forge is prepared for GitHub issue/PR work.
Read-only `gh` helpers show repository metadata, PR lists, PR status, the current branch PR, open issues, and PR checks in local buffers.
Agent-generated changes should be reviewed through Magit hunks before staging.

`C-c g g h d` opens `gnopon/github-dashboard`, generated by `gnopon/github-dashboard-text`.
It is a local, read-only GitHub cockpit that summarizes the current branch, origin remote, `gh` availability, and the direct command paths for repository metadata, PRs, checks, issues, review packets, PR body drafts, and confirmation-gated draft PR creation.

`C-c g r` opens a review cockpit for GitHub handoff work: inspect Magit status, review diffs, write a Markdown review packet under `logs/review/`, run tests/checks, capture command logs, inspect agent sessions, list PRs/checks/issues, write or copy a PR body draft, copy a conservative `gh pr create --draft` command, or explicitly create a GitHub draft PR from a generated body file.
Draft PR creation is confirmation-gated, runs through a visible `*gh:pr-create-draft*` buffer, and sets `GH_PROMPT_DISABLED=1` so the command fails visibly instead of dropping into hidden prompts.
These commands do not commit or push automatically.

## Terminal And Shell Setup

Eat is the default terminal because it is portable Elisp.
Eshell remains available for Lisp-integrated shell work.
Commands create project-scoped shells with predictable names so agent runs, test logs, and manual commands stay attached to the project.

For ad hoc commands, prefer `C-c g s c`: preview the command risk, run it in a compile buffer, or run and capture the output as Markdown evidence.
This keeps shell work visible, reviewable, and attached to the project instead of buried in an unstructured terminal scrollback.

## Agentic Programming

Agent commands are explicit and human-triggered:

- open a Codex-specific cockpit for chat, context, session, log, and review commands;
- open a Codex workspace with a Markdown dashboard, the live project terminal, and a redacted chat monitor with evidence/readiness cues;
- stage prompts in an editable Markdown composer before sending them to Codex;
- create Codex-specific session records with prompt evidence, transcript evidence, lawfulness checks, conformance checks, and review closure;
- send an active region, current buffer, or generated project context bundle to the project Codex terminal as a redacted, metadata-bearing prompt after explicit confirmation, with a `logs/agent/*-codex-prompt.md` evidence record;
- capture the visible Codex terminal transcript as normalized, redacted Markdown evidence under `logs/agent/`;
- write a Codex cockpit brief that joins readiness, evidence cursor, Git state, diff stat, operating loop, and live chat tail into one Markdown handoff;
- copy a project context bundle;
- open or write a redacted Markdown context bundle assembled from project memory files plus the current buffer or active region as a focused work item;
- open or write a Markdown agent handoff packet that combines safety invariants, Git state, memory readiness, task counts, recent sessions, and recommended command flow;
- launch a project agent shell;
- create a timestamped Markdown agent session record;
- index previous project-local agent sessions;
- search and close project-local agent sessions;
- write local MCP-style JSON indexes under `logs/mcp/` for project memory, predication cells, and agent sessions;
- open project memory files;
- capture a command log into Markdown;
- draft commit messages and PR descriptions from local Git state;
- write PR body files under `logs/review/` and create draft PRs only after explicit confirmation;
- open Magit for patch review.

`C-c g a h` opens `gnopon/open-agent-handoff`, backed by `gnopon/agent-handoff-text`; `C-c g a H` writes the same packet under `logs/agent/`.
The handoff packet is deliberately local and read-only by default.
It does not launch an agent or send data; it gives the human operator an inspectable preflight artifact before copying context, starting an agent shell, reviewing diffs, and preparing PR evidence.

`C-c g a S` opens or returns to the project-scoped Codex terminal named `*codex:<project>*`.
`C-c g a L` runs `codex resume --last` in that same terminal buffer, `C-c g a J` runs `codex resume` for the picker, `C-c g a z` opens the full dashboard/terminal/monitor layout around the latest resumed session, and `C-c g a j` opens the same layout around the picker.
`C-c g a D` opens the read-only Codex dashboard without starting the terminal.
`C-c g a A` opens the Codex chat monitor.
`C-c g a q` opens a blank prompt composer, and `C-c g a Q` opens a composer seeded from the active region.
`C-c g a N` creates a Codex-specific session record.
`C-c g a y` sends the active region as a redacted focused prompt, `C-c g a Y` sends the current buffer, `C-c g a B` sends the generated project context bundle, `C-c g a T` writes a redacted transcript snapshot of the terminal under `logs/agent/`, `C-c g a o` previews a cockpit brief, and `C-c g a k` writes the brief.
`C-c g a E e` opens the newest Codex evidence record across sessions, prompts, transcripts, and briefs; `C-c g a E s` opens the newest Codex session, `C-c g a E b` opens the newest brief, `C-c g a E p` opens the newest prompt record, and `C-c g a E t` opens the newest transcript record.
Inside the dashboard, `g` refreshes the report, `z` restores the dashboard/terminal/monitor cockpit, `Z` resumes the cockpit workspace, `j` opens the picker workspace, `J` opens the resume picker, `s` opens Codex, `S` resumes the latest Codex session, `A` opens the monitor, `C` opens the prompt composer, `N` creates a Codex session, `p`/`P`/`b` send prompt material, `M`/`F` open memory and formal validation, `X`/`K`/`V` open command matrix/check/test surfaces, `o e`/`o s`/`o b`/`o p`/`o t` open latest evidence/session/brief/prompt/transcript records, `T` captures the transcript, `O` writes the cockpit brief, and the context/session/review keys mirror the agent prefix.
`C-c g a x` exposes the same commands through a transient alongside context bundle, handoff, session, transcript, brief, log, monitor, prompt composer, and diff-review actions.

No command silently sends secrets, runs arbitrary shell commands from model output, or commits generated work.
Logged shell commands are confirmation-gated and classified as low, write, network, or dangerous; dangerous commands are refused by the helper.

Safety audits are local artifacts.
They may show file names and redacted line structure so humans can investigate leaks, but likely secret values are passed through the same redaction helper used for agent context bundles.

`C-c g a M` opens the local MCP export cockpit.
It writes `logs/mcp/resources.json`, `logs/mcp/project-memory.json`, and `logs/mcp/agent-sessions.json` as file-backed resource indexes.
These are static local manifests for external MCP servers or agent wrappers to consume; GnoponEmacs does not start a server or expose data over the network.

## Security Model

Secrets live in `auth-source`, `~/.authinfo.gpg`, `pass`, environment variables, or untracked local files.
AI backends are opt-in.
The default `gptel` backend is local Ollama if available.

## Persistence

Backups, autosaves, recent files, places, transient state, package data, and custom variables live under `~/.config/emacs/var/`, not in project files.

## Testing And Debugging

Repository check:

```sh
pnpm --dir apps/gnoponemacs verify
```

The verifier checks package structure, required README sections, module wiring, balanced Elisp parentheses, missing `gnopon/` command references, required feature markers, reproducible-manifest alignment, startup benchmark wiring, and the absence of Org-centered dependencies.
It also runs ERT tests for pure Markdown/frontmatter/heading/link/task/shell-risk/Turtle helpers, command-level ERT tests for file-producing and report-producing command surfaces including the doctor report and capability audit, a no-network module load smoke that stubs package declarations instead of installing packages, a real-init fallback smoke that disables package refresh/install and verifies `C-c g` prefix keys plus the `M-SPC` cockpit launcher, a temp-project smoke for local MCP resource exports, a temp-project smoke for formal RDF/proof exports, a temp-project smoke for PR body file generation, and a temp-project smoke for Markdown structure reports.
`pnpm --dir apps/gnoponemacs repro -- --require-tools` is the CI gate for Nix/Guix evaluation.

Emacs checks:

```sh
emacs --batch -Q -l ~/.config/emacs/init.el --eval '(message "loaded")'
emacs --debug-init
```

Use `M-x gnopon/report-startup` for quick startup timing, `M-x gnopon/performance-report` for the Markdown runtime report, and `M-x gnopon/open-module` to inspect a module.

Startup troubleshooting:

- If `C-c g` or `M-SPC` is undefined, startup aborted before `init.el` finished.
  Run `emacs --debug-init --init-directory apps/gnoponemacs --chdir $PWD` from the project root and inspect the first error.
- Visual and workflow packages are optional for the cockpit.
  Missing `modus-themes`, `popper`, `diff-hl`, `magit`, `which-key`, `transient`, completion packages, snippets, language modes, API modes, or formatters should produce at most a message or a command-specific fallback and must not prevent the GnoponEmacs prefix map or agent commands from loading.
  If `transient` is missing, direct `C-c g` keys still work while transient menu commands report that the package closure is incomplete.
- To verify the command surface without opening a UI, run `pnpm --dir apps/gnoponemacs verify`.

## Migration Path

1. Move the old config aside.
2. Install `early-init.el` and `init.el` symlinks with the Node wrapper.
3. Put machine-specific values in `~/.config/emacs/local.el`.
4. Move planning into `PLAN.md`, task lists into `TODO.md`, long-lived project norms into `AGENTS.md`, and design records into `docs/adr/`.
5. Port only keybindings that still fit the cockpit model.

## Roadmap

- Broaden command-level ERT coverage for interactive buffer navigation and failure states.
- Add committed Nix flake locks and pinned Guix channel commits after evaluating on runners with Nix and Guix installed.
