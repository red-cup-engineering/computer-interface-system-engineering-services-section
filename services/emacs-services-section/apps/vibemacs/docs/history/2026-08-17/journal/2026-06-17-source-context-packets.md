---
title: "Source Context Packets"
date: 2026-06-17
---


This cycle added a smaller, code-level handoff surface to Vibemacs.
The earlier agent tools focused on project context: cockpit state, task files, verification history, and full handoff bundles.
That is useful when another agent needs to understand the whole working session, but it is too broad when the immediate question is about one function, one selected region, or one suspicious line.

`C-c v f` now opens a source context packet.
If a region is active, Vibemacs captures that region.
Otherwise it prefers the current definition and falls back to the current line.
The packet includes the project root, branch, file path, line range, selection scope, and a line-numbered Markdown excerpt.

The feature is deliberately plain text.
It does not require an external package or a custom protocol for agents.
It produces a reviewable Markdown buffer that can be copied into a chat, kept beside a task file, or used as a starting point for a more focused prompt.

This moves Vibemacs closer to the intended shape: an Emacs configuration for agentic programmers, where the editor can quickly turn live programming context into durable, inspectable material for collaboration with coding agents.
