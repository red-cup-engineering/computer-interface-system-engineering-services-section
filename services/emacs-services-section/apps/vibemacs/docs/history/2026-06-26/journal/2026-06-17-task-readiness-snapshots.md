---
title: "Task Readiness Snapshots"
date: 2026-06-17
---

Vibemacs already had a readiness report: a scratch buffer that answers the practical question an agent asks before closing a task.
Does the task have a goal?
Are acceptance checks present?
Are the boxes complete?
Is verification evidence attached?
Are checkpoints, decisions, and handoff notes in place?

This cycle turns that report into durable task-file evidence.

The new `vibemacs-agent-insert-task-readiness` command appends a timestamped readiness snapshot to the current persisted task file under `## Readiness Reports`.
It is available from the global Vibemacs prefix as `C-c v W`, from task buffers as `C-c C-w`, and from the cockpit action list as "Write readiness".
If the section does not exist yet, Vibemacs creates it before inserting the report.

That gives agentic programmers a clean closeout rhythm.
Use the scratch readiness report when surveying the task, repair whatever is missing, then write the readiness snapshot back into the task file as a permanent record of the state that was actually reviewed.

The implementation stays inside the Emacs configuration.
It reuses the existing readiness renderer, adds a small timestamped wrapper, and teaches task-mode and cockpit about the new command.
The tests now cover snapshot rendering, section creation, task-mode binding, and cockpit discoverability, so readiness evidence is treated as a first-class part of the workflow rather than an incidental note.
