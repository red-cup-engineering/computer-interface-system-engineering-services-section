---
title: "Durable Scope Audits"
date: 2026-06-17
---

Vibemacs already had a scratch scope-audit packet for checking whether changed files still matched the task.
This cycle makes that audit durable inside the persisted task file.

The new `vibemacs-agent-insert-current-task-scope-audit` command appends a timestamped audit under `## Scope Audits`.
It records the task goal, open acceptance checks, changed files, diff stat, recent verification, and the same scope questions used by the scratch packet.

The command is available as `C-c v O` from the global Vibemacs prefix, as `C-c C-z` inside persisted task files, and as "Write scope" in the cockpit.
The existing `C-c v S` and `C-c C-u` commands still open the scratch scope-audit buffer.

This is useful because scope drift is easiest to notice while the work is fresh, but easiest to lose once a session moves on.
Persisting the audit gives the next reader a record of which changes were visible, which checks were still open, and which questions the agent had to answer before handoff.

Tests now cover timestamped scope-audit rendering, insertion into task files, task-mode binding, and cockpit discoverability.
Vibemacs keeps turning task-local reasoning into durable Emacs artifacts.
