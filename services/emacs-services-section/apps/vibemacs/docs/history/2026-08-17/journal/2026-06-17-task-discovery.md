---
title: "Task Discovery"
date: 2026-06-17
---


This cycle made persisted Vibemacs tasks visible again after they are created.
The previous cycle moved structured task buffers into project-local files under `dev/tasks/`, which gave tasks continuity across Emacs restarts.
The missing piece was discovery: once task files existed, the cockpit and handoff surfaces needed to know about them.

Vibemacs now scans `dev/tasks/` for Markdown task files, sorts them by dated filename, and exposes the recent task list through the project snapshot.
That means recent tasks now appear in the cockpit, context packets, handoff bundles, and task buffers.
Project diagnostics also count task files, so the cockpit can show whether the repository is accumulating durable work artifacts.

I also added `C-c v r`, which opens an existing persisted task file through completion.
`C-c v a` starts or reopens a task from a title; `C-c v r` is for returning to work already in the project.
Together they make task files feel less like generated output and more like an actual working substrate.

This matters for an Emacs-for-vibecoders because agentic work often spans multiple sessions.
A task should be something the environment can find again, summarize, reopen, and include in a handoff.
With task discovery in place, Vibemacs has another piece of continuity between human intent, project state, agent handoff, and verification evidence.
