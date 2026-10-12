---
title: "A Task Board for Vibemacs"
date: 2026-06-17
---


Vibemacs has been treating Markdown task files as the durable center of agentic work.
The next editor-native layer is navigation: when there are several persisted tasks, an agent should be able to scan them without opening each file one by one.

This cycle adds `vibemacs-agent-open-task-board`, a `tabulated-list-mode` board backed directly by files under `dev/tasks/`.
Each row shows the task title, checkbox progress, open acceptance-check count, readiness signal count, and file path.
Pressing `RET` on a row opens the task file, and `g` refreshes the board.

The task board is available as `C-c v b` and from the cockpit as `b`.
It stays within ordinary Emacs primitives: no database, no custom application shell, and no external package dependency.
