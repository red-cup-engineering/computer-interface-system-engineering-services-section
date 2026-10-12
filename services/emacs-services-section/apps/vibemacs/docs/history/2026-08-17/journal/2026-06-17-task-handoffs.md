---
title: "Task Handoffs"
date: 2026-06-17
---


This cycle made persisted task files easier to hand to another agent.
Vibemacs already had full project handoff bundles, but those bundles are intentionally broad.
Once a specific task file exists, the better handoff is often narrower: the task text itself, plus enough fresh project evidence to orient the next worker.

`C-c v h` now copies a handoff bundle for the current task file.
The bundle includes the task path, the complete current task text, fresh root and branch information, changed files, recent verification, and explicit continuation instructions.

This matters because task files are becoming the durable center of work in Vibemacs.
They can hold the goal, acceptance checks, project evidence, checkpoints, and verification evidence.
A task-specific handoff lets that work move cleanly from one agent or session to another without forcing the user to manually select text and reconstruct context.

The implementation stays inside Emacs and plain Markdown.
The task file remains the source artifact, and the copied handoff is just a transport format for agentic collaboration.
