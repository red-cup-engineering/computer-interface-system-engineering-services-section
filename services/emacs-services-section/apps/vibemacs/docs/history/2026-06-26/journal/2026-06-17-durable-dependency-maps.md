---
title: "Durable Dependency Maps"
date: 2026-06-17
---

Vibemacs already had a scratch dependency-map packet for changed files.
This cycle makes that map durable inside the persisted task file.

The new `vibemacs-agent-insert-current-task-dependency-map` command appends a timestamped map under `## Dependency Maps`.
It records the task goal, changed files, parsed source dependencies, blast-radius questions, and recent verification.

The command is available as `C-c v B` from the global Vibemacs prefix, as `C-c C-t` inside persisted task files, and as "Write deps" in the cockpit.
The existing `C-c v M` and `C-c C-b` commands still open the scratch dependency-map buffer.

This matters because changed files are only the visible edge of a task.
The dependency map captures which source relationships were visible when the agent reviewed the task, giving the next reader a better sense of what might need opening, testing, or mentioning in a handoff.

Tests now cover timestamped dependency-map rendering, insertion into task files, task-mode binding, and cockpit discoverability.
Vibemacs continues turning short-lived review context into durable Emacs task evidence.
