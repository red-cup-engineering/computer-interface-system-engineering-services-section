---
title: "Durable Task Prompts for Vibemacs"
date: 2026-06-17
---


Vibemacs already made it easy to open a scratch prompt packet from a persisted task, but scratch buffers are deliberately temporary.
This cycle adds the durable counterpart: a command that appends the current task prompt back into the task file as timestamped evidence.

The new `vibemacs-agent-insert-current-task-prompt` command writes to a `Task Prompt Packets` section.
It uses the same task prompt renderer as the scratch command, wraps it with a timestamped heading, refreshes task status afterward, and keeps the existing `P` / `C-c C-p` scratch workflow intact.

The command is available from the global Vibemacs prefix as `C-c v X`, from the cockpit as `X`, and inside persisted task files as `C-c .
`.
Tests cover the timestamped renderer, persisted section insertion, task-mode binding, and cockpit action registration.
