---
title: "Task Dependency Maps"
date: 2026-06-17
---

Vibemacs is becoming an Emacs configuration that helps an agent keep the shape of a task in view while editing.
This cycle adds a dependency map packet for changed source files.

The new `vibemacs-agent-open-current-task-dependency-map` command opens a scratch Markdown buffer from the current persisted task file.
It includes the task path, goal, changed files, parsed source dependencies, blast-radius questions, and recent verification.

The dependency map currently recognizes Emacs Lisp `require` and `load` forms, plus common JavaScript and TypeScript `import` and `require` forms.
That keeps the feature small and local: it reads the changed files already present in the working tree and turns their dependencies into a reviewable packet.

The command is available as `C-c v M` from the global Vibemacs prefix, as `C-c C-b` inside persisted task files, and as "Dependency map" in the cockpit.

This matters for agentic programming because changed files are not isolated facts.
A changed Emacs Lisp module may rely on upstream helpers; a TypeScript file may quietly expand the affected surface through imports.
The packet gives the agent a fast way to ask what else should be opened, tested, or named in the handoff.

Tests now cover Git status path normalization, dependency extraction, packet rendering, interactive scratch-buffer creation, task-mode binding, and cockpit discoverability.
