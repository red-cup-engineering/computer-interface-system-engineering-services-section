---
title: Obsidian Knowledge Vault
tool: obsidian-knowledge-vault
---


This vault is the Obsidian-facing cockpit for the repository `content/` knowledge vault.

The notes here are a working surface.
The durable memorystore remains the repository content tree, and the commands in the local Knowledge Vault plugin route through `@emsenn/organizing-a-knowledge-vault` instead of inventing another note law.

The cockpit side panel shows inherited agent packages, content-vault tools, potential-note graph facts, ranked local graph neighborhoods, Canvas context, and a prompt surface for running the ecosystem agent against bounded vault context plus the potential selection or note body.
The prompt surface keeps a threaded chat session with streaming token output, stop, retry, clear, and transcript writing controls.
The arena commands turn an potential note into a typed agent work state and then advance that state through one ecosystem-agent next move.
The handoff command writes `Agents/cockpit-handoff.md` with readiness settings, manifest, active-note context, root/health evidence, and recent generated notes.
The queue command writes `Agents/cockpit-queue.md` so proposed and admitted agent work is visible for review.
The audit command writes `Agents/cockpit-capability-audit.md` with present, partial, and gap sections for the agentic cockpit benchmark.
The connector command writes `Agents/connector-snippets.md` with MCP/OpenAPI registration snippets for external agent hosts.
The setup command writes `Agents/runtime-setup.md` with the resolved local-vs-npm runtime mode, package runner, runtime package, vault path roots, and redacted provider-key readiness.
The checkpoint command writes `Agents/cockpit-checkpoint.md` with a session checkpoint carrier, Markdown trace, generated artifacts, suggested commands, and next moves for another agent or editor window to resume from.
The package server command exposes the same tool surface over HTTP/OpenAPI/MCP for external agent hosts.
The Review side-panel control filters generated cockpit notes and can mark the selected mission, arena, proposal, receipt, or run note as `reviewed` or `settled` without editing frontmatter by hand.
It can also open a selected generated note's source note, approve proposal/receipt frontmatter, and advance a selected arena.
The Switch side-panel control opens a fuzzy cockpit palette over the potential note, ranked graph neighbors, and generated work so arenas, proposals, checkpoints, receipts, and context notes are directly reachable.
In plugin settings, configure repository/app/content roots when working outside this checkout, choose an agent endpoint/model when needed, and set `Agent API key env` plus `Agent API key` when you want Obsidian to inject a provider key for the spawned ecosystem agent bridge.
Outside this checkout, the plugin can run its public npm runtime with `Package runner executable` plus `Runtime package`; the default is `npx -y -p @emsenn/app-obsidian-knowledge-vault@0.0.0`.
Agent note edits are proposal-first: create an edit proposal, write its diff preview, inspect the generated notes, set `approved: true` in the proposal frontmatter, then enable note edits and apply the proposal when it is ready.
Applies write append-only edit receipts; restoring opens a chooser when several receipts exist for the potential note and still requires `rollbackApproved: true` in the selected receipt frontmatter.
Full-note proposals replace the note; selection proposals require an active selection and replace only that selected text.

Open the command palette and run:

- `Knowledge Vault: Open knowledge vault dashboard`
- `Knowledge Vault: Open knowledge vault cockpit`
- `Knowledge Vault: Catalog content vault`
- `Knowledge Vault: Inspect content vault health`
- `Knowledge Vault: Plan content vault normalization`
- `Knowledge Vault: Run knowledge vault tool`
- `Knowledge Vault: Search content vault`
- `Knowledge Vault: Build active note context pack`
- `Knowledge Vault: Build active note neighborhood`
- `Knowledge Vault: Create agent mission from active note`
- `Knowledge Vault: Create cockpit arena from active note`
- `Knowledge Vault: Advance active cockpit arena`
- `Knowledge Vault: List ecosystem agent endpoints`
- `Knowledge Vault: Write cockpit manifest`
- `Knowledge Vault: Write runtime setup note`
- `Knowledge Vault: Write cockpit checkpoint`
- `Knowledge Vault: Write cockpit handoff`
- `Knowledge Vault: Write cockpit queue`
- `Knowledge Vault: Open cockpit review queue`
- `Knowledge Vault: Open cockpit quick switcher`
- `Knowledge Vault: Write cockpit capability audit`
- `Knowledge Vault: Write connector snippets`
- `Knowledge Vault: Run active note with ecosystem agent`
- `Knowledge Vault: Propose active note edit`
- `Knowledge Vault: Preview active note edit proposal diff`
- `Knowledge Vault: Apply active note edit proposal`
- `Knowledge Vault: Choose edit receipt to restore`
- `Knowledge Vault: Map active note topic`
- `Knowledge Vault: Prepare active note triage deposit`

Build the plugin before first opening the vault:

```sh
pnpm --filter @emsenn/app-obsidian-knowledge-vault build
```
