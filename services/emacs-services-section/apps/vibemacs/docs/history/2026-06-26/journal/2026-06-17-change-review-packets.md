---
title: "Change Review Packets"
date: 2026-06-17
---


This cycle added a review surface for the moment after coding and before handoff.
Vibemacs already had project context packets, source context packets, task files, verification history, and handoff bundles.
What was missing was a compact way to ask, "What changed, and is this ready to review?"

`C-c v d` now opens a change review packet.
It collects Git status, the current branch, diff stats, a capped diff excerpt, and recent verification evidence into one Markdown buffer.
The packet also includes review prompts that nudge the programmer or agent to check whether the diff matches the task, whether unrelated changes slipped in, and which verification result supports the work.

The command is intentionally conservative.
It does not try to replace Git, a test runner, or human review.
It gives the agentic programmer a fast text-native summary that can be copied into a chat, compared against a task file, or used before writing a final handoff.

This makes Vibemacs more like a working cockpit for agent-assisted software development: it can frame the task, capture source context, run verification, record evidence, and now prepare the actual diff for review.
