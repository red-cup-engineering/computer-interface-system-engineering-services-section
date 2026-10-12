---
title: "Project Diagnostics in the Cockpit"
date: 2026-06-17
---


This cycle made Vibemacs better at describing the project before an agent starts editing it.
The cockpit and context packets already knew about Git status, open buffers, verification commands, and recent verification evidence.
That helped with session state, but it did not yet summarize the shape of the repository itself.

Vibemacs now computes a small set of project diagnostics from the local tree: which entrypoint files are present, how many Emacs Lisp modules exist under `lisp/`, how many ERT tests are present under `test/`, how many public journal entries exist, and whether `package.json` is present.
These diagnostics are included in both the cockpit and the agent context packet.

The point is not to replace deeper code search or project indexing.
The point is to give the programmer and the agent an immediate orientation layer.
Before a handoff says "change the config," Vibemacs can now show whether the config has entrypoints, modules, tests, journals, package metadata, and enough visible surface area to make the next move responsibly.

This keeps the project moving toward an Emacs-for-vibecoders rather than a bag of isolated commands.
The cockpit is becoming an operating surface: current state, available actions, verification evidence, persistent session memory, and now project diagnostics all live in one inspectable Emacs buffer.
