---
title: "Task Verification Plans"
date: 2026-06-17
---

Vibemacs could already run verification commands, record their results, and append evidence back into task files.
This cycle adds a planning surface for the moment before running those commands.

The new `vibemacs-agent-open-current-task-verification-plan` command opens a scratch Markdown packet from the current persisted task file.
It includes the task path, goal, open acceptance checks, configured verification commands, recent verification history, changed files, and practical verification notes.

The command is available as `C-c v G` from the global Vibemacs prefix, as `C-c C-g` inside persisted task files, and as "Verify guide" in the cockpit.
It does not run anything by itself; `C-c v v` and `C-c v V` still own execution.
The guide exists to help an agent decide whether to run a narrow command first or escalate to the full suite before handoff.

This keeps verification grounded in the task rather than as a detached project ritual.
The open checks explain what still needs proof, while the configured commands show the available gates.

The tests now cover verification-plan rendering, scratch-buffer creation from a persisted task, task-mode binding, and cockpit discoverability.
The workflow is a little more deliberate: plan verification, run it, append evidence, then refresh readiness and closeout.
