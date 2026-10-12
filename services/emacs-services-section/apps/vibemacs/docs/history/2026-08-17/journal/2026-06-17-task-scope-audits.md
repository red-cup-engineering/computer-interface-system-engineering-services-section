---
title: "Task Scope Audits"
date: 2026-06-17
---

Vibemacs has a growing set of task packets for prompting, reviewing, planning verification, and drafting final responses.
This cycle adds a packet for a quieter but important question: does the work still match the task?

The new `vibemacs-agent-open-current-task-scope-audit` command opens a scratch Markdown buffer from the current persisted task file.
It includes the task path, goal, open acceptance checks, changed files, diff stat, recent verification, and explicit scope questions.

The command is available as `C-c v S` from the global Vibemacs prefix, as `C-c C-u` inside persisted task files, and as "Scope audit" in the cockpit.

This is different from the broader change review packet.
Change review shows the diff; scope audit asks whether the diff belongs to the task.
That distinction matters when an agent is moving quickly through a large Emacs session with many adjacent useful changes available.

The tests now cover scope-audit rendering, scratch-buffer creation from a persisted task, task-mode binding, and cockpit discoverability.
Vibemacs now has a direct pre-handoff check for scope drift: changed files, diff stats, and task intent in one buffer.
