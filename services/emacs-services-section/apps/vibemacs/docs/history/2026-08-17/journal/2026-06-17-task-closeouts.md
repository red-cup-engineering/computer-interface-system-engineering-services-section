---
title: "Task Closeouts"
date: 2026-06-17
---

Vibemacs has been accumulating the pieces of an agentic Emacs workflow: task files, verification evidence, checkpoints, decisions, readiness reports, and handoff bundles.
This cycle adds a small but important closure move: a task closeout that can be written directly into the persisted task file.

The new `vibemacs-agent-insert-task-closeout` command appends a timestamped `## Closeout` entry.
It records checkbox completion, the latest verification result, any remaining unchecked items, and a short handoff note that points back to readiness and verification evidence.

The command is available from the global Vibemacs prefix as `C-c v o`, from task files as `C-c C-o`, and from the cockpit as "Closeout task".
It is intentionally an Emacs configuration feature, not a separate project-management app: the artifact lives in Markdown beside the task evidence an agent is already using.

The implementation also adds a checkbox item extractor so closeouts can name the actual remaining checks rather than only reporting a count.
Tests now cover checkbox filtering, closeout rendering, task-file insertion, task-mode binding, and cockpit discoverability.

The workflow is now more complete: open or create a task, work through checks, record verification and decisions, inspect readiness, write a readiness snapshot, and then append a closeout summary that another agent can read without reconstructing the final state from scattered context.
