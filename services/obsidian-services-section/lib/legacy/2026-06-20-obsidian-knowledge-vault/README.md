# @emsenn/app-obsidian-knowledge-vault

A desktop Obsidian practice for working over the 561 content knowledge vault.

This app is intentionally downstream of the repo libraries:

- `@emsenn/organizing-a-knowledge-vault` owns content-vault path law, corpus reads, topic guidance, health, normalization, triage upload preparation, and document-type workflows.
- `@emsenn/organizing-with-agents` supplies the generic agent/session substrate, MCP/OpenAPI connector-registration carriers, ranked context-neighborhood carriers, and the shared edit-review carriers for proposals, diffs, approvals, receipts, and rollback.
- `@emsenn/organizing-with-llm-agents` supplies the LLM conversation, running, cost, and harness carriers.
- `@emsenn/organizing-with-openai-agents` supplies OpenAI-compatible endpoint resolution and settled chat runs for ecosystem agents.
- `@emsenn/producing-content` supplies the frontmatter codec used by the app tooling.
- `@emsenn/relating` supplies the action dispatcher carrier surface.

The Obsidian plugin stays small.
It adds commands, stores settings through Obsidian plugin data, writes generated reports as ordinary vault notes, and runs the Node action/agent bridges for the heavy corpus and inference work.

## Use

```sh
pnpm --filter @emsenn/app-obsidian-knowledge-vault build
```

Then open `apps/obsidian-knowledge-vault/vault` as an Obsidian vault and enable the local `Knowledge Vault` community plugin if Obsidian asks for confirmation.
In the plugin settings, set the repository/app/content roots when working outside this checkout, choose an agent endpoint/model when needed, and either provide provider keys through your shell environment or set `Agent API key env` plus `Agent API key`.
The key is injected into the spawned Node agent bridge under the named env var, so the upstream endpoint resolver still sees `OPENAI_API_KEY`, `GROQ_API_KEY`, `NVIDIA_API_KEY`, `CEREBRAS_API_KEY`, or a future compatible name.

When the plugin is installed outside this monorepo, leave `App root` blank and let the runtime fallback use the public npm package.
The default packaged runtime is:

```text
npx -y -p @emsenn/app-obsidian-knowledge-vault@0.0.0 <obsidian-knowledge-* command>
```

That keeps the Obsidian community-plugin artifact in the normal three-file shape while still running the same public `@emsenn/*` libraries for the heavy tooling.
Set `Package runner executable` or `Runtime package` only when you want a pinned package version, a local package mirror, or a different package runner.

## Package

```sh
pnpm --filter @emsenn/app-obsidian-knowledge-vault run package:plugin
```

This writes release-ready Obsidian plugin assets under `apps/obsidian-knowledge-vault/dist/obsidian-plugin/`:

- `knowledge-vault/manifest.json`
- `knowledge-vault/main.js`
- `knowledge-vault/styles.css`
- `versions.json`
- `knowledge-vault-0.0.0.zip`

For a manual install, place `manifest.json`, `main.js`, and `styles.css` in `.obsidian/plugins/knowledge-vault/` for the target vault, then enable `Knowledge Vault` in Obsidian.
For release managers, attach those three files and `versions.json` to a GitHub release, or attach the zip for people who prefer download-and-extract installation.
Official Obsidian community-plugin submission is easiest from a plugin-root repository or mirror whose root contains `manifest.json` and `versions.json`; this app can already produce those assets from the monorepo.
The packaged plugin first uses a local `App root`/`dist` runtime when present, then falls back to the public npm runtime package.

For local development against an existing vault, build the plugin and install it directly into that vault:

```sh
pnpm --filter @emsenn/app-obsidian-knowledge-vault run build:plugin
pnpm --filter @emsenn/app-obsidian-knowledge-vault run install:plugin -- sites/emsenn.net/content
```

On Windows, Obsidian may not inherit the same `PATH` as a terminal.
If commands install but do not run, start with the package doctor from a terminal:

```sh
pnpm --filter @emsenn/app-obsidian-knowledge-vault run doctor -- sites/emsenn.net/content --markdown
```

That verifies the Node package runtime, action bridge, vault path, and local Obsidian CLI status from the shell.
Then use the Obsidian command palette command `Write runtime doctor note`.
It writes `Agents/runtime-doctor.md` with the resolved plugin/app/repo/content paths, the Obsidian process `PATH`, a `node --version` probe, and an `inspect-root` action probe from inside Obsidian.
If Node is not found, set `Node executable` in the plugin settings to an absolute path such as `C:\nvm4w\nodejs\node.exe`.
For monorepo development, set:

```text
Repository root: C:\Users\emsen\561-group
App root: C:\Users\emsen\561-group\apps\obsidian-knowledge-vault
Content root: sites/emsenn.net/content
```

Obsidian's own CLI can be used later for launch/open smoke tests, but on this Windows workstation `Obsidian.exe --help` reports that the command line interface must first be enabled in Obsidian under Settings -> General -> Advanced.

The command palette exposes dashboard, catalog, health, normalization, active-topic concept mapping, a persistent cockpit side view, search, custom tool execution, runtime setup notes, session checkpoint notes, fuzzy cockpit quick switching, context-pack generation, agent mission creation, ecosystem endpoint inventory, ecosystem agent runs, cockpit arena admission/advance notes, cockpit handoff/checkpoint notes, cockpit queue/review notes, active-note graph context, ranked local graph neighborhoods, side-panel agent prompting over the potential selection or note body, capability audit notes, governed active-note edit proposals, and active-note triage deposit commands.
It also writes connector snippets for external MCP and OpenAPI clients.
External content writes are disabled by default; the triage command writes a dry-run note unless `Allow external writes` is enabled in the plugin settings.
Agent-generated note edits are also gated; `Allow note edits` must be enabled before an edit proposal can be applied.

Compared with generic agentic Obsidian cockpits, this app's advantage is that the agent does not receive an untyped vault scrape.
It receives bounded knowledge-vault evidence from the corpus tools, Obsidian-local graph facts (frontmatter keys, tags, outlinks, backlinks, unresolved links), a mission note, and then runs through the repo's own agent packages so costs, endpoint selection, run settlement, and handoff vocabulary stay compatible with the rest of the 561 agent ecosystem.

The side-panel chat loop keeps a session id, preserves prior user/assistant messages through the upstream `conversation` carrier, exposes stop/retry/clear controls, streams OpenAI-compatible token chunks through `obsidian-knowledge-agent --stream`, and writes `Agents/chat-*.md` transcripts.

The neighborhood loop writes `Agents/neighborhood-*.md` and feeds the same ranked local graph projection into context packs, missions, arenas, edit proposals, and chat prompts.
It scores resolved outlinks, backlinks, shared tags, Canvas files containing or connecting the potential note, same-folder recent notes, unresolved links, and note snippets through `@emsenn/organizing-with-agents/context`, giving the agent a Smart Connections-style local context surface without sending an unbounded vault scrape.

The arena loop turns a note or selection into `Agents/arena-*.md`: request, arena state, dispatch readiness, active-note graph context, the cockpit manifest, bounded corpus evidence, recent generated notes, and a next-move contract.
The advance command runs the ecosystem agent over that arena and writes one settlement note instead of letting a chat thread drift away from the vault.

The edit loop is proposal-first: the agent writes an `Agents/edit-proposal-*.md` note with its reasoning, approval fields, and a fenced Markdown replacement.
The diff preview command writes an `Agents/edit-proposal-diff-*.md` review note.
Applying the proposal to the potential note is a separate command, and it is disabled unless note edits are explicitly allowed in settings and the proposal note says `approved: true`.
Successful applies write append-only `Agents/edit-receipt-*.md` notes with the previous and applied content; restoring opens a receipt chooser when more than one receipt exists for the potential note, and the selected receipt must say `rollbackApproved: true`.
Full-note proposals replace the note; selection proposals require the target text to be actively selected and only replace that selection.

The handoff loop folds the current cockpit state into `Agents/cockpit-handoff.md`: dispatch readiness, active note graph facts, the full cockpit manifest, root and health evidence, and the recent generated note trail from the Tooling and Agents folders.
It is meant to make Obsidian sessions resumable by another human or agent without rereading the whole vault.

The runtime setup loop writes `Agents/runtime-setup.md` and the side panel shows the same status live: local-vs-npm runtime mode, plugin directory, app root, repo root, resolved content root, package runner, runtime package, and redacted provider-key readiness.
This is the normal first diagnostic note for manual installs, BRAT-style installs, and later community-plugin releases.

The checkpoint loop writes `Agents/cockpit-checkpoint.md` through the `@emsenn/organizing-with-agents/session` checkpoint carrier.
It folds runtime readiness, dispatch gates, active note path, recent generated artifacts, verification evidence, suggested commands, and next moves into both Markdown and carrier JSON, so another agent can resume from a trace cut rather than a chat scroll.

The queue loop writes `Agents/cockpit-queue.md`, grouping generated cockpit notes by kind/status and surfacing proposed/admitted work such as edit proposals, missions, and arenas that need review before write gates are opened.
The side-panel Review control opens the same queue as an actuator: filter generated notes by needs-review, proposals, arenas, receipts, or all generated work; open the selected note or its source note; approve proposal/receipt frontmatter; advance a selected arena; or mark it `reviewed` / `settled`.
The side-panel Switch control and `Open cockpit quick switcher` command open a native Obsidian fuzzy palette over the potential note, ranked graph neighbors, and recent generated cockpit notes, so arenas, proposals, receipts, checkpoints, and context notes are reachable without browsing folders.

The audit loop writes `Agents/cockpit-capability-audit.md`, separating benchmark capabilities into present, partial, and gap sections.
It includes live root and endpoint evidence plus the full cockpit manifest, so the meet-or-beat claim can be checked from the current state instead of asserted in prose.

The connector loop writes `Agents/connector-snippets.md` from the same `@emsenn/organizing-with-agents/connectors` carrier exposed in the cockpit manifest.
It includes the `obsidian-knowledge-vault-serve` start command, HTTP MCP/OpenAPI endpoints, and `.mcp.json` / `.vscode/mcp.json` registration snippets so Codex, Claude-compatible MCP clients, VS Code, and generic MCP hosts can mount the vault tooling without inventing per-host setup by hand.

## CLI bridge

The app also exposes the same action bridge outside Obsidian:

```sh
pnpm --filter @emsenn/app-obsidian-knowledge-vault build
pnpm --filter @emsenn/app-obsidian-knowledge-vault run doctor -- sites/emsenn.net/content --markdown
echo content | pnpm --filter @emsenn/app-obsidian-knowledge-vault run tool -- inspect-health --path content --limit 100
echo topic | pnpm --filter @emsenn/app-obsidian-knowledge-vault run tool -- concept-map --path content --region content --limit 100
```

## Server bridge

External agent hosts can mount the same action surface over HTTP/OpenAPI/MCP:

```sh
pnpm --filter @emsenn/app-obsidian-knowledge-vault build
pnpm --filter @emsenn/app-obsidian-knowledge-vault run serve -- --path content --port 8790
```

The server exposes the inherited action bridge at `/`, `/openapi.json`, and `/mcp`, plus app-level cockpit projections at `/cockpit`, `/cockpit.md`, `/benchmark`, and `/connectors`.

## Agent bridge

```sh
pnpm --filter @emsenn/app-obsidian-knowledge-vault build
pnpm --filter @emsenn/app-obsidian-knowledge-vault run agent:list
echo "Use the current context pack and propose next actions." | pnpm --filter @emsenn/app-obsidian-knowledge-vault run agent -- --json
pnpm --filter @emsenn/app-obsidian-knowledge-vault run agent -- --conversation-json '[{"role":"user","content":"previous question"},{"role":"assistant","content":"previous answer"}]' --json --prompt "continue"
pnpm --filter @emsenn/app-obsidian-knowledge-vault run agent -- --stream --prompt "continue with live token output"
```

## Cockpit manifest

```sh
pnpm --filter @emsenn/app-obsidian-knowledge-vault run cockpit
pnpm --filter @emsenn/app-obsidian-knowledge-vault run cockpit:markdown
pnpm --filter @emsenn/app-obsidian-knowledge-vault run cockpit -- --connectors
```

The manifest projects the content-vault tools, the inherited 561 agent packages, the Obsidian command actuators, benchmark capabilities, and the `@emsenn/organizing-with-agents/capabilities` core capability spine into one Obsidian-facing cockpit record.

This is deliberately the same shape as `organize-knowledge-vault`; Obsidian is a human interface over the content vault, not a second source of truth.
