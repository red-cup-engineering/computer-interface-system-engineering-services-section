---
title: "A Task Action Menu for Vibemacs"
date: 2026-06-17
---


Vibemacs has accumulated a lot of task-local commands: prompt packets, verification plans, risk registers, dependency maps, handoffs, decisions, closeouts, and more.
Keyboard shortcuts are still the fast path, but an agentic Emacs configuration should also make the available moves discoverable from inside the task buffer.

This cycle adds `vibemacs-agent-dispatch-task-action`, a built-in completing-read menu for persisted task files.
The command reuses the existing cockpit action descriptors, filters them down to commands that make sense against the current task, and dispatches the selected command interactively.

The menu is available globally as `C-c v C` when point is in a task file, and locally as `C-c C-c` from `vibemacs-agent-task-mode`.
No external package is required; the feature works with standard Emacs completion and will automatically benefit from whatever completion UI the user configures later.
