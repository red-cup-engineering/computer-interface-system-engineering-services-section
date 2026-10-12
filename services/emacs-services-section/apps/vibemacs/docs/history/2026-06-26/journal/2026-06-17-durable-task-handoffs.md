---
title: "Durable Task Handoffs"
date: 2026-06-17
---

Vibemacs already had task handoff bundles that could be copied to the kill ring.
This cycle makes that evidence durable inside the task file itself.

The new `vibemacs-agent-insert-current-task-handoff` command appends a timestamped handoff under `## Agent Handoff Bundle` in the current persisted task file.
It reuses the existing current-task handoff renderer, so the entry includes the task file path, current task text, fresh project evidence, changed files, recent verification, and requested outcome.

The command is available as `C-c v H` from the global Vibemacs prefix, as `C-c C-y` inside persisted task files, and as "Write handoff" in the cockpit.
The existing lowercase `h` command still copies a task handoff to the kill ring.

This matters because agentic programming often crosses a boundary: a task moves from one agent to another, from one session to another, or from scratch context back into a persistent file.
Copyable handoffs are useful at the boundary.
Durable handoffs are useful after the boundary has passed, when someone needs to reconstruct what was known and what was asked.

The readiness report already checked whether an `Agent Handoff Bundle` section was present.
Now Vibemacs has the command that writes that section.
Tests cover the timestamped renderer, task-file insertion, task-mode binding, and cockpit discoverability.
