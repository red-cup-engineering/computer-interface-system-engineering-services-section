---
title: "Task Risk Registers"
date: 2026-06-17
---

Vibemacs now has task packets for prompt construction, review, verification planning, scope audits, and final-response drafts.
This cycle adds a risk register for the moment before an agent says the work is ready.

The new `vibemacs-agent-open-current-task-risk-register` command opens a scratch Markdown buffer from the current persisted task file.
It collects the task path, goal, open acceptance checks, changed files, latest verification state, and a short set of mitigation prompts.

The command is available as `C-c v K` from the global Vibemacs prefix, as `C-c C-l` inside persisted task files, and as "Risk register" in the cockpit.

The point is not to invent a heavy project-management layer inside Emacs.
It is to make uncertainty visible while the agent still has the task, buffers, diff, and verification commands close at hand.
Open checkboxes become explicit acceptance risks.
Changed files become a risk surface.
The latest verification result becomes a concrete signal instead of a vague memory.

Tests now cover the renderer, the interactive scratch-buffer command, task-mode binding, and cockpit discoverability.
Vibemacs keeps growing as an Emacs configuration for agentic programmers: keyboard-first, evidence-rich, and organized around handing back work that matches the task.
