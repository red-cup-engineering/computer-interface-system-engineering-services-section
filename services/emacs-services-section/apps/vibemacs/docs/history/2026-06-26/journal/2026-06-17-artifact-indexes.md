---
title: "Artifact Indexes"
date: 2026-06-17
---


This cycle added a resume map for Vibemacs work.
The configuration has been growing a family of agentic artifacts: task files, public journal entries, local notes, session evidence, source context packets, change reviews, and verification history.
Those pieces are useful individually, but a programmer returning to a project still needs a quick answer to a simpler question: where is the work?

`C-c v i` now opens a project artifact index.
The index gathers the current branch, session evidence path, changed files, open project buffers, recent task files, task status, public journal entries, local notes, and recent verification results into one Markdown buffer.

The command is intentionally read-only.
It does not replace the cockpit or task files; it gives the programmer a map for resuming work, deciding which task to reopen, and seeing which evidence exists before asking another agent to continue.

This fits the direction of Vibemacs as an Emacs configuration for agentic programmers.
The editor should not only produce artifacts for agents, but also make those artifacts easy to find again when context has gone cold.
