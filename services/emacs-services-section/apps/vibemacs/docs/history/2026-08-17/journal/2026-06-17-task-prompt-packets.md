---
title: "Task Prompt Packets"
date: 2026-06-17
---

Vibemacs already had a generic prompt packet command, and it had durable task files.
This cycle connects those ideas so a persisted task can produce an agent-ready prompt without losing the evidence that has accumulated in Emacs.

The new `vibemacs-agent-open-current-task-prompt` command opens a scratch Markdown packet seeded from the current task file.
The packet includes the task path, full task text, fresh project evidence, changed files, recent verification, standing agent constraints, and explicit acceptance checks for the next agent cycle.

The command is available as `C-c v P` from the global Vibemacs prefix, as `C-c C-p` inside persisted task files, and as "Task prompt" in the cockpit.
The existing `C-c v p` command remains the general-purpose prompt packet for work that has not yet been captured in a task file.

This keeps the center of gravity in the Emacs configuration.
A task file remains the durable source of truth; the task prompt is the transient packet an agent can paste into a coding session when it is time to continue the work.

The tests now cover task prompt rendering, scratch prompt creation, task-mode binding, and cockpit discoverability.
The result is a smoother handoff from persistent task evidence to immediate agent instruction.
