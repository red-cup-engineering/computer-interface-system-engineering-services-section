---
title: "Task Next Actions"
date: 2026-06-17
---

Vibemacs now has several strong task surfaces: prompt packets, review packets, readiness reports, closeouts, handoffs, and public journal drafts.
This cycle adds a smaller surface for the moment before all of those are needed: resuming the next piece of work.

The new `vibemacs-agent-open-current-task-next-actions` command opens a scratch Markdown packet from the current persisted task file.
It shows the task path, checkbox progress, the first unchecked item as the immediate next action, the full remaining checklist, the task goal, changed files, recent verification, and a short set of resume moves.

The command is available as `C-c v A` from the global Vibemacs prefix, as `C-c C-a` inside persisted task files, and as "Next actions" in the cockpit.

This is intentionally smaller than a handoff or review packet.
A handoff tells another agent how to continue; a review packet asks whether the work is ready; a next-action packet answers the practical question, "What should I do next from here?"

The tests now cover next-action rendering, scratch-buffer creation from a persisted task, task-mode binding, and cockpit discoverability.
Vibemacs can now move from task evidence to immediate work without asking the user to re-read the whole task file just to find the next unchecked line.
