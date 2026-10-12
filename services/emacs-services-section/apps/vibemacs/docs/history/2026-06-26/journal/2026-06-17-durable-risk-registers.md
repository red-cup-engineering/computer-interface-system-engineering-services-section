---
title: "Durable Risk Registers"
date: 2026-06-17
---

Vibemacs already had a scratch risk-register packet for persisted task files.
This cycle makes risk evidence durable.

The new `vibemacs-agent-insert-current-task-risk-register` command appends a timestamped risk register under `## Risk Registers` in the current task file.
It records the task goal, open acceptance checks, changed files, latest verification signal, open risks, mitigation prompts, and recent verification history.

The command is available as `C-c v U` from the global Vibemacs prefix, as `C-c C-x` inside persisted task files, and as "Write risks" in the cockpit.
The existing `C-c v K` and `C-c C-l` commands still open the scratch risk-register buffer.

This matters because risk is only useful if it survives long enough to shape the handoff.
A scratch risk packet helps the current agent think.
A durable risk register gives the next reader a concrete record of what remained uncertain, what still needed verification, and what should be called out before claiming completion.

Tests now cover timestamped risk-register rendering, insertion into task files, task-mode binding, and cockpit discoverability.
Vibemacs keeps shifting agent work from short-lived context into durable Emacs task artifacts.
