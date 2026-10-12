# Vibemacs

Vibemacs is Emacs as an agent-controlled knowledge, research, and development
system.  It is a project-local Emacs application: an agent or person can make
the state of work inspectable, record evidence, and leave another agent enough
context to continue without inventing a second task tracker or an external
agent harness.

## What it retains

Vibemacs deliberately retains the complete recovered capability set from its
three legacy copies:

- structured Markdown task files, task-local action menus, checkbox progress,
  a tabulated task board, and readiness/status headers;
- durable session evidence and bounded verification history, with individual
  checks and configured verification suites recorded through Emacs compilation;
- project, Git, buffer, note, journal, and task discovery; source-context and
  change-review packets; and dependency maps for changed source files;
- inspectable prompt, context, handoff, review, next-action, verification-plan,
  final-response, scope-audit, risk-register, dependency-map, readiness,
  checkpoint, decision, closeout, and review-checklist artifacts;
- development-cycle notes, project journals, and task-seeded public journals;
- a cockpit, task board, transcript, keyboard bindings, and a task-local
  completion menu for carrying out those workflows in Emacs; and
- the built-in editor defaults and restrained interface profile used by the
  legacy application.

Artifacts are Markdown buffers or entries in the task that produced them.
Session evidence is stored at `dev/.vibemacs-session.el`; task files are stored
at `dev/tasks/`.  Those carriers remain inspectable and usable without a
running agent.

## Architecture

The application is organized by the effect it provides, not by the old
monolith's report names:

- `vibemacs-foundation.el` owns project location, editor defaults, and shared
  utilities.
- `vibemacs-workflow.el` owns task state, task-file interaction, transcript,
  verification, and session persistence.
- `vibemacs-evidence.el` observes Git, project files, buffers, and source
  dependencies.
- `vibemacs-artifacts.el` turns durable work state and evidence into
  inspectable Markdown artifacts.
- `vibemacs-interface.el` provides the cockpit, board, action palette, and
  interactive entry points.
- `vibemacs.el` composes those capabilities and activates the application.

The direct legacy implementations have been retired.  Their complete workflow
journals are retained under `docs/history/`: the two divergent revisions stay
separately inspectable, including the meaningful wording correction between
them.  They are documentation, not a second runtime.

## Use

Start Emacs with this directory as its configuration directory:

```sh
emacs --init-directory /path/to/emacs-services-section/apps/vibemacs
```

Or load it from an existing Emacs configuration:

```elisp
(add-to-list 'load-path "/path/to/emacs-services-section/apps/vibemacs/lisp")
(require 'vibemacs)
(vibemacs-activate)
```

`C-c v RET` opens the cockpit.  `C-c v C` opens the task-local action palette,
and `C-c v b` opens the task board.  The cockpit presents every other workflow
with its key binding and a description.
