---
title: "Task Final Response Drafts"
date: 2026-06-17
---

Vibemacs has been building a task-centered agent workflow inside Emacs: prompt packets, next actions, verification plans, review packets, readiness, closeouts, and durable evidence.
This cycle adds a small surface for the last moment of a coding cycle: drafting the response back to the user.

The new `vibemacs-agent-open-current-task-final-response` command opens a scratch Markdown buffer from the current persisted task file.
It pulls together changed files, recent verification history, remaining task checks, the task goal, and closeout evidence, then frames that material as a concise final-response draft.

The command is available as `C-c v F` from the global Vibemacs prefix, as `C-c C-f` inside persisted task files, and as "Final response" in the cockpit.

This is not meant to automate judgment or replace the agent's final answer.
It is a drafting surface that keeps the response grounded in the same evidence the task file has been accumulating.
The result should still be edited down to the concrete facts that matter.

The tests now cover final-response rendering, scratch-buffer creation from a persisted task, task-mode binding, and cockpit discoverability.
Vibemacs now helps carry work from task evidence all the way to a concise user-facing closeout.
