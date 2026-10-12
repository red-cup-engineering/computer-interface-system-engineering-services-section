---
title: "Task Review Packets"
date: 2026-06-17
---

Vibemacs had the ingredients for review scattered across several useful commands: a persisted task file, a readiness report, closeout evidence, and a project-level change review.
This cycle combines them into a single task-specific review packet.

The new `vibemacs-agent-open-current-task-review` command opens a scratch Markdown buffer for reviewing the current task before handoff.
It includes the task path, full task text, rendered readiness report, closeout section, rendered change review, and a short set of review questions about diff alignment, verification evidence, unresolved checks, and public journal readiness.

The command is available as `C-c v T` from the global Vibemacs prefix, as `C-c C-v` inside persisted task files, and as "Task review" in the cockpit.

This is still an Emacs configuration feature, not a separate review app. The durable record remains the task file; the review packet is a temporary cockpit surface for deciding whether the current task is actually ready to hand off.

The tests now cover review packet rendering, scratch-buffer creation from a persisted task, task-mode binding, and cockpit discoverability.
The workflow now has a clearer pre-handoff checkpoint: review the task, its readiness, its closeout, and its diff together before claiming the cycle is done.
