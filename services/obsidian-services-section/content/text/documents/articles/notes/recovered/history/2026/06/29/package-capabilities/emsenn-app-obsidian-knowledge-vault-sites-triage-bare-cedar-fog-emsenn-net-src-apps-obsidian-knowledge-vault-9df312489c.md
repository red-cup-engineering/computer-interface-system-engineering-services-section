---
title: "Capability note: @emsenn/app-obsidian-knowledge-vault"
date: 2026-06-29
source-package: "sites/triage.bare-cedar-fog.emsenn.net/src/apps/obsidian-knowledge-vault"
---

# Capability note: @emsenn/app-obsidian-knowledge-vault

- Package path: `sites/triage.bare-cedar-fog.emsenn.net/src/apps/obsidian-knowledge-vault`
- Package kind: `src-app`
- Declared workspace entries: `apps/obsidian-knowledge-vault`
- Description: A desktop Obsidian vault app that mounts the 561 content knowledge vault through @emsenn/organizing-a-knowledge-vault and exposes bounded vault tooling as Obsidian commands.
- Capability tags from manifest/source hints: `application`, `service`, `agent-harness`, `workspace-analysis`, `content-production`, `knowledge`
- Bins: `obsidian-knowledge-vault`, `obsidian-knowledge-doctor`, `obsidian-knowledge-agent`, `obsidian-knowledge-cockpit`, `obsidian-knowledge-vault-serve`
- Export subpaths: `.`, `./tooling`, `./cockpit`, `./doctor`, `./app`, `./package.json`
- Scripts: `clean`, `build:deps`, `check:local`, `check:plugin`, `check`, `build:local`, `sync:plugin-assets`, `install:plugin`, `build:plugin`, `build`, `package:plugin`, `tool`, `doctor`, `agent`, `agent:list`, `cockpit`, `cockpit:markdown`, `serve`, `verify`, `rebuild`
- Dependencies: `@emsenn/organizing-a-knowledge-vault`, `@emsenn/organizing-with-agents`, `@emsenn/organizing-with-llm-agents`, `@emsenn/organizing-with-openai-agents`, `@emsenn/producing-content`, `@emsenn/relating`

## Local Evidence

- sites/triage.bare-cedar-fog.emsenn.net/src/apps/obsidian-knowledge-vault/README.md: A desktop Obsidian practice for working over the 561 content knowledge vault.
- Source hints: `plugin/src/main.ts`, `scripts/package-plugin.mjs`, `sites/emsenn.net/content/.obsidian/plugins/knowledge-vault/main.js`, `src/agent.mts`, `src/app.mts`, `src/cockpit.mts`, `src/doctor.mts`, `src/index.mts`, `src/scripts/agent.mts`, `src/scripts/cockpit.mts`, `src/scripts/doctor.mts`, `src/scripts/serve.mts`, `src/scripts/tool.mts`, `src/tooling.mts`

## Relation To Infography Baseline

- Direct surface overlap with `@emsenn/infography`: `.`, `./package.json`
- Capability classes not directly realized by infography's exported package surface: `application`, `agent-harness`, `content-production`, `knowledge`

This note is generated from manifest, nearby prose, and source-path evidence.
It should be checked against opened source before making migration or deletion decisions.
