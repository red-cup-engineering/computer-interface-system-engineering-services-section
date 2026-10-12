---
title: "Durable Verification Plans"
date: 2026-06-17
---

Vibemacs already had a scratch verification-plan packet that paired open task checks with configured verification commands.
This cycle makes the plan durable inside the persisted task file.

The new `vibemacs-agent-insert-current-task-verification-plan` command appends a timestamped plan under `## Verification Plans`.
It records the task goal, open acceptance checks, suggested verification commands, recent verification history, changed files, and verification notes.

The command is available as `C-c v N` from the global Vibemacs prefix, as `C-c ;` inside persisted task files, and as "Write verify" in the cockpit.
The existing `C-c v G` and `C-c C-g` commands still open the scratch verification-plan buffer.

This matters because verification evidence says what passed, but a verification plan says what should be proven.
Persisting the plan gives a later agent a concrete bridge between unfinished checks and the commands expected to reduce uncertainty.

Tests now cover timestamped verification-plan rendering, insertion into task files, task-mode binding, and cockpit discoverability.
Vibemacs continues shaping the task file into the durable center of the agentic programming loop.
