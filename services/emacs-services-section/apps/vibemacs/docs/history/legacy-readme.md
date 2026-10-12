# Vibemacs

Vibemacs is a next-generation Emacs configuration for agentic programmers: keyboard-first, prompt-aware, transcript-friendly, and organized around shipping work with coding agents.

This repository is an Emacs configuration, not a custom editor app. It starts with a small built-in-only core so it can be loaded and tested before external package choices are made.

## Use

Run Emacs with this directory as `user-emacs-directory`:

```sh
emacs --init-directory .
```

Or load it in batch for validation:

```sh
emacs -Q --batch -L lisp -l init.el
```

## Test

```sh
npm test
```

## Current Shape

- `early-init.el` trims startup UI and package initialization behavior.
- `init.el` loads the Vibemacs modules and applies the default profile.
- `lisp/vibemacs-core.el` provides editor defaults, keymaps, and project notes.
- `lisp/vibemacs-agent.el` provides agent prompt, transcript, and cycle commands.
- `lisp/vibemacs-ui.el` provides a restrained dark theme and interface polish.
- ERT tests cover the core agentic workflow helpers.
- The cockpit shows project state, action buttons, and recent verification results.
- Context packets and the cockpit include lightweight project diagnostics.
- Verification evidence can be saved to and loaded from `dev/.vibemacs-session.el`.
- Structured task buffers are persisted under `dev/tasks/`.
- A task board lists persisted task files with progress and readiness signals.
- The cockpit, context packets, and handoff bundles include recent task files and checkbox status.
- Task files can absorb the latest verification result as durable evidence.
- Task files can absorb timestamped verification history snapshots.
- Source context packets capture selected code or the current definition with line numbers.
- Change review packets summarize Git status, diff stats, diff excerpts, and verification.
- Task review packets combine the current task, readiness, closeout, and change review.
- Task scope audits compare the current task with changed files and diff stats.
- Task scope audits can be appended back into persisted task files.
- Task risk registers surface open checks, changed files, and verification risk.
- Task risk registers can be appended back into persisted task files.
- Task dependency maps show source dependencies for changed files.
- Task dependency maps can be appended back into persisted task files.
- Task review checklists can be appended into persisted task files.
- Task next-action packets summarize the first unchecked task item and resume evidence.
- Task next-action packets can be appended back into persisted task files.
- Task verification plans pair open checks with the configured verification commands.
- Task verification plans can be appended back into persisted task files.
- Task final-response drafts turn task evidence into concise handoff text.
- Task final-response drafts can be appended back into persisted task files.
- Verification suites run every configured check in sequence and record each result.
- Journal drafts are seeded with project evidence, changed files, tasks, and verification.
- Task journal drafts are seeded from the current persisted task file.
- Task prompt packets are seeded from the current persisted task file.
- Artifact indexes map tasks, journals, notes, buffers, changes, and verification for resuming work.
- Task checkpoints append changed files, open buffers, and verification to persisted task files.
- Task handoffs copy the current task file with fresh project evidence for another agent.
- Task handoff bundles can be appended back into persisted task files.
- Task decisions record timestamped decisions and rationale in persisted task files.
- Task checkbox commands jump through and toggle Markdown acceptance checks.
- Task prompt packets can be appended back into persisted task files.
- Task action menus provide a built-in completing-read palette for task-local workflows.
- `vibemacs-agent-task-mode` turns on local task workflow keys inside persisted task files.
- Task buffers show a live status header with checkbox progress and recent verification.
- Task readiness reports inspect whether a task has enough evidence for handoff.
- Task readiness snapshots can be appended back into persisted task files.
- Task closeouts summarize completion, latest verification, and remaining checks.

## First Commands

- `C-c v RET` opens the Vibemacs cockpit.
- `C-c v C` prompts for a task action in the current task file.
- `C-c v A` opens a next-action packet for the current task file.
- `C-c v L` inserts a next-actions packet into the current task file.
- `C-c v a` opens a persisted structured task file.
- `C-c v b` opens the persisted task board.
- `C-c v r` opens an existing persisted task file.
- `C-c v p` opens a prompt packet buffer for the current project.
- `C-c v P` opens a prompt packet from the current task file.
- `C-c v X` inserts a task prompt packet into the current task file.
- `C-c v t` opens an agent transcript buffer.
- `C-c v T` opens a review packet for the current task file.
- `C-c v x` opens an agent context packet with project evidence.
- `C-c v i` opens a project artifact index.
- `C-c v f` opens a line-numbered source context packet.
- `C-c v F` opens a final-response draft for the current task file.
- `C-c v I` inserts a final-response draft into the current task file.
- `C-c v S` opens a scope audit for the current task file.
- `C-c v O` inserts a scope audit into the current task file.
- `C-c v K` opens a risk register for the current task file.
- `C-c v U` inserts a risk register into the current task file.
- `C-c v M` opens a dependency map for the current task file.
- `C-c v B` inserts a dependency map into the current task file.
- `C-c v Q` inserts a review checklist into the current task file.
- `C-c v d` opens a change review packet for the current Git diff.
- `C-c v G` opens a verification plan for the current task file.
- `C-c v N` inserts a verification plan into the current task file.
- `C-c v v` runs a verification command and records it in the transcript.
- `C-c v V` runs the configured verification suite.
- `C-c v e` inserts the latest verification result into the current task file.
- `C-c v E` inserts a verification history snapshot into the current task file.
- `C-c v k` inserts a project checkpoint into the current task file.
- `C-c v D` records a decision in the current task file.
- `C-c v n` jumps to the next unchecked task checkbox.
- `C-c v m` toggles the task checkbox on the current line.
- `C-c v R` opens a readiness report for the current task file.
- `C-c v W` inserts a readiness snapshot into the current task file.
- `C-c v o` inserts a closeout summary into the current task file.
- `C-c v c` starts a development cycle note.
- `C-c v s` inserts a shipping checklist.
- `C-c v w` saves session evidence.
- `C-c v l` loads session evidence.
- `C-c v y` copies an agent handoff bundle.
- `C-c v h` copies a handoff bundle for the current task file.
- `C-c v H` inserts a handoff bundle into the current task file.
- `C-c v j` opens today's public journal draft.
- `C-c v J` opens today's public journal draft from the current task file.

## Task File Keys

Persisted files under `dev/tasks/` enable `vibemacs-agent-task-mode`.

- `C-c C-n` jumps to the next unchecked task checkbox.
- `C-c C-c` prompts for a task action.
- `C-c C-m` toggles the task checkbox on the current line.
- `C-c C-a` opens a next-action packet for the current task file.
- `C-c ,` inserts a next-actions packet into the current task file.
- `C-c C-p` opens a prompt packet from the current task file.
- `C-c .
  ` inserts a task prompt packet into the current task file.
- `C-c C-f` opens a final-response draft for the current task file.
- `C-c C-g` opens a verification plan for the current task file.
- `C-c ;` inserts a verification plan into the current task file.
- `C-c C-e` inserts the latest verification result.
- `C-c C-E` inserts a verification history snapshot.
- `C-c C-k` inserts a project checkpoint.
- `C-c C-d` records a decision.
- `C-c C-h` copies a task handoff.
- `C-c C-y` inserts a task handoff bundle.
- `C-c C-v` opens a review packet for the current task file.
- `C-c C-i` inserts a final-response draft into the current task file.
- `C-c C-u` opens a scope audit for the current task file.
- `C-c C-z` inserts a scope audit into the current task file.
- `C-c C-l` opens a risk register for the current task file.
- `C-c C-x` inserts a risk register into the current task file.
- `C-c C-b` opens a dependency map for the current task file.
- `C-c C-t` inserts a dependency map into the current task file.
- `C-c C-q` inserts a review checklist into the current task file.
- `C-c C-s` refreshes and reports task status.
- `C-c C-r` opens a task readiness report.
- `C-c C-w` inserts a readiness snapshot.
- `C-c C-o` inserts a closeout summary.
- `C-c C-j` opens a public journal draft from the current task file.
