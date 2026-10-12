---
title: "Agent Handoff Bundles"
date: 2026-06-17
---


This cycle made Vibemacs better at moving evidence out of Emacs when a coding agent needs it.
The cockpit already gathers project state, diagnostics, Git changes, open buffers, verification commands, and recent verification evidence.
That information is useful on screen, but agentic programming often still needs a clean handoff into a chat, issue, review, or another tool.

The new `C-c v y` command renders a full Markdown handoff bundle and copies it to the kill ring.
The bundle includes the operating frame, project root, branch, session evidence file, diagnostics, Git changes, open project buffers, verification commands, recent verification results, standing agent instructions, and an explicit requested-outcome section.

The important part is that this is not just a prompt template.
It is a generated handoff from live Vibemacs session state.
The user can still edit it after pasting, but the default path now carries concrete evidence instead of asking the programmer to manually stitch together context from the cockpit, transcript, Git status, and memory.

This moves Vibemacs closer to being a real Emacs-for-vibecoders: not a wrapper around agents, and not a pile of preferences, but a workspace that gathers the evidence a human-agent session needs and makes that evidence portable.
