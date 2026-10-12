---
title: "Durable Next Actions"
date: 2026-06-17
---

Vibemacs already had a scratch next-actions packet for finding the first useful move in a persisted task.
This cycle makes that packet durable inside the task file.

The new `vibemacs-agent-insert-current-task-next-actions` command appends a timestamped packet under `## Next Actions`.
It records the task path, acceptance-check progress, immediate next unchecked item, remaining checks, task goal, changed files, recent verification, and resume moves.

The command is available as `C-c v L` from the global Vibemacs prefix, as `C-c ,` inside persisted task files, and as "Write next" in the cockpit.
The existing `C-c v A` and `C-c C-a` commands still open the scratch next-actions buffer.

This matters because the first next action is often the most valuable thing to preserve when a task crosses a session boundary.
A scratch packet helps the current agent focus; a durable next-actions entry gives the next session a precise place to resume.

Tests now cover timestamped next-actions rendering, insertion into task files, task-mode binding, and cockpit discoverability.
Vibemacs keeps making Emacs task files more useful as durable coordination surfaces for agentic programming.
