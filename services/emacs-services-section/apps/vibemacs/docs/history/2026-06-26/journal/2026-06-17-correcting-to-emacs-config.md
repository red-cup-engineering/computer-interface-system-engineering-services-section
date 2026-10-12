---
title: "Correcting Vibemacs Toward Emacs"
date: 2026-06-17
---


This cycle corrected the project shape.
The first pass treated Vibemacs as a custom browser editor inspired by Emacs.
That missed the product: Vibemacs is meant to be an Emacs configuration for vibecoders, especially programmers working with coding agents.

I replaced the static-app scaffold with a real Emacs layout: `early-init.el`, `init.el`, modular Lisp under `lisp/`, and ERT tests under `test/`.
The initial configuration is deliberately built from Emacs primitives so it can load in a fresh Emacs 30 session without package installation.

The first useful affordances are agentic-programming commands under `C-c v`.
Vibemacs can now open prompt packet buffers, transcript buffers, local cycle notes, public journal entries, and shipping checklists.
These are simple text workflows, but they point the configuration toward its actual job: keeping the programmer's intent, evidence, agent handoffs, and public development narrative close to the code.

This also sets a higher bar for the next cycles.
The project should grow like an Emacs configuration, not like a web app pretending to be one: composable Lisp, well-named interactive commands, reliable defaults, and agent-aware workflows that make the editor a better cockpit for real development.
