;;; vibemacs-artifacts.el --- Durable work artifacts for Vibemacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Renderers for task, handoff, review, journal, and planning artifacts.

;;; Code:

(require 'subr-x)
(require 'cl-lib)
(require 'vibemacs-foundation)
(require 'vibemacs-workflow)
(require 'vibemacs-evidence)
(defun vibemacs-render-task (snapshot)
  "Render SNAPSHOT as a structured Vibemacs task buffer."
  (let-alist snapshot
    (string-join
     (list
      (format "# Vibemacs Task: %s" .title)
      ""
      "## Goal"
      ""
      "- "
      ""
      "## Acceptance Checks"
      ""
      "- [ ] The implementation serves the requested end state."
      "- [ ] Project evidence was inspected before editing."
      "- [ ] Relevant verification passed or the failure is documented."
      "- [ ] Public journal entry added under `dev/docs/journal/`."
      ""
      "## Project Evidence"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Session evidence: `%s`" .session-file)
      ""
      "## Diagnostics"
      ""
      (vibemacs--markdown-list .diagnostics "No project diagnostics available.")
      ""
      "## Changed Files"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Open Project Buffers"
      ""
      (vibemacs--markdown-list .open-files "No project files are open.")
      ""
      "## Recent Task Files"
      ""
      (vibemacs--markdown-list .task-files "No persisted task files found.")
      ""
      "## Recent Task Status"
      ""
      (vibemacs--markdown-list .task-summaries "No task status available.")
      ""
      "## Verification Plan"
      ""
      (vibemacs--markdown-list .verification "No verification commands configured.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "## Agent Handoff Bundle"
      ""
      (vibemacs-render-handoff-bundle snapshot)
      "")
     "\n")))

(defun vibemacs-render-task-checkpoint (snapshot &optional time)
  "Render SNAPSHOT as a Markdown task checkpoint.
Optional TIME supplies the checkpoint timestamp."
  (let-alist snapshot
    (string-join
     (list
      (format "### %s Checkpoint" (or time (format-time-string "%H:%M")))
      ""
      "#### Changed Files"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "#### Open Project Buffers"
      ""
      (vibemacs--markdown-list .open-files "No project files are open.")
      ""
      "#### Recent Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "#### Next"
      ""
      "- "
      "")
     "\n")))

(defun vibemacs-render-task-decision (decision rationale &optional time)
  "Render DECISION and RATIONALE as a Markdown task decision.
Optional TIME supplies the decision timestamp."
  (string-join
   (list
    (format "### %s Decision" (or time (format-time-string "%H:%M")))
    ""
    "#### Decision"
    ""
    (format "- %s" (string-trim decision))
    ""
    "#### Rationale"
    ""
    (format "- %s" (string-trim rationale))
    "")
   "\n"))

(defun vibemacs-render-current-task-handoff (task-file task-text snapshot)
  "Render TASK-FILE and TASK-TEXT with fresh project SNAPSHOT as a handoff."
  (let-alist snapshot
    (string-join
     (list
      (format "# Vibemacs Task Handoff: %s" .title)
      ""
      "## Operating Frame"
      ""
      "You are receiving a persisted Vibemacs task. Treat the task text as session evidence, then inspect the repository before editing."
      ""
      "## Task File"
      ""
      (format "- Path: `%s`" task-file)
      ""
      "## Current Task Text"
      ""
      "```markdown"
      task-text
      "```"
      ""
      "## Fresh Project Evidence"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Session evidence: `%s`" .session-file)
      ""
      "## Changed Files"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "## Requested Outcome"
      ""
      "- Continue the task from the persisted evidence."
      "- Preserve unrelated user changes."
      "- Run relevant verification and append evidence back to the task."
      "")
     "\n")))

(defun vibemacs-render-current-task-handoff-entry
    (task-file task-text snapshot &optional time)
  "Render a timestamped current-task handoff entry.
TASK-FILE, TASK-TEXT, and SNAPSHOT are passed through to
`vibemacs-render-current-task-handoff'.  Optional TIME supplies
the displayed timestamp."
  (string-join
   (list
    (format "### %s Task Handoff" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-render-current-task-handoff task-file task-text snapshot))
   "\n"))

(defun vibemacs-render-current-task-prompt (task-file task-text snapshot)
  "Render TASK-FILE and TASK-TEXT with SNAPSHOT as an agent prompt packet."
  (let-alist snapshot
    (string-join
     (list
      (format "# Task Prompt: %s" .title)
      ""
      "## Goal"
      ""
      "- Continue the persisted Vibemacs task below."
      "- Inspect the repository before editing."
      "- Preserve unrelated user changes."
      ""
      "## Task File"
      ""
      (format "- Path: `%s`" task-file)
      ""
      "## Current Task Text"
      ""
      "```markdown"
      task-text
      "```"
      ""
      "## Fresh Project Evidence"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Session evidence: `%s`" .session-file)
      ""
      "## Changed Files"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "## Constraints"
      ""
      (string-join (mapcar (lambda (item) (concat "- " item))
                           vibemacs-default-constraints)
                   "\n")
      ""
      "## Acceptance Checks"
      ""
      "- [ ] Implementation moves the real task end state forward."
      "- [ ] Relevant verification has passed or failure is documented."
      "- [ ] Task evidence is updated before handoff."
      "- [ ] Public journal entry is written before the cycle closes."
      "")
     "\n")))

(defun vibemacs-render-current-task-prompt-entry
    (task-file task-text snapshot &optional time)
  "Render a timestamped current-task prompt packet entry.
TASK-FILE, TASK-TEXT, and SNAPSHOT are passed through to
`vibemacs-render-current-task-prompt'.  Optional TIME supplies
the displayed timestamp."
  (string-join
   (list
    (format "### %s Task Prompt" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-render-current-task-prompt task-file task-text snapshot))
   "\n"))

(defun vibemacs-render-current-task-review
    (task-file task-text readiness closeout change-review snapshot)
  "Render a task review packet.
TASK-FILE and TASK-TEXT describe the persisted task.  READINESS,
CLOSEOUT, and CHANGE-REVIEW are rendered evidence blocks.  SNAPSHOT
supplies project metadata."
  (let-alist snapshot
    (string-join
     (list
      (format "# Task Review: %s" .title)
      ""
      "## Project"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Task file: `%s`" task-file)
      ""
      "## Current Task Text"
      ""
      "```markdown"
      task-text
      "```"
      ""
      "## Readiness Report"
      ""
      readiness
      ""
      "## Closeout Evidence"
      ""
      closeout
      ""
      "## Change Review"
      ""
      change-review
      ""
      "## Review Questions"
      ""
      "- Does the diff match the task goal and acceptance checks?"
      "- Is every claimed verification result recorded in the task?"
      "- Are unresolved checks or follow-ups explicit before handoff?"
      "- Is the public journal entry ready or clearly still pending?"
      "")
     "\n")))

(defun vibemacs-render-current-task-next-actions
    (task-file task-goal open-checks complete total snapshot)
  "Render a next-action packet for TASK-FILE.
TASK-GOAL is the current task goal text.  OPEN-CHECKS are unchecked
acceptance checks.  COMPLETE and TOTAL describe checkbox progress.
SNAPSHOT supplies project evidence."
  (let-alist snapshot
    (string-join
     (list
      (format "# Task Next Actions: %s" .title)
      ""
      "## Task"
      ""
      (format "- Path: `%s`" task-file)
      (format "- Acceptance checks: `%d/%d complete`" complete total)
      ""
      "## Immediate Next Action"
      ""
      (if open-checks
          (format "- [ ] %s" (car open-checks))
        "- No unchecked acceptance checks remain.")
      ""
      "## Remaining Checks"
      ""
      (if open-checks
          (string-join (mapcar (lambda (item) (concat "- [ ] " item))
                               open-checks)
                       "\n")
        "- All task checks are complete.")
      ""
      "## Task Goal"
      ""
      task-goal
      ""
      "## Changed Files"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "## Resume Moves"
      ""
      "- Reopen the task file and inspect the goal before editing."
      "- Work the immediate next action before broadening scope."
      "- Run relevant verification and append evidence back to the task."
      "- Refresh readiness, closeout, and the public journal before handoff."
      "")
     "\n")))

(defun vibemacs-render-current-task-next-actions-entry
    (task-file task-goal open-checks complete total snapshot &optional time)
  "Render a timestamped next-actions entry.
TASK-FILE, TASK-GOAL, OPEN-CHECKS, COMPLETE, TOTAL, and SNAPSHOT are
passed through to `vibemacs-render-current-task-next-actions'.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Next Actions" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-render-current-task-next-actions
     task-file
     task-goal
     open-checks
     complete
     total
     snapshot))
   "\n"))

(defun vibemacs-render-current-task-verification-plan
    (task-file task-goal open-checks commands snapshot)
  "Render a verification plan packet for TASK-FILE.
TASK-GOAL is the current task goal text.  OPEN-CHECKS are unchecked
acceptance checks.  COMMANDS are suggested verification commands.
SNAPSHOT supplies project evidence."
  (let-alist snapshot
    (string-join
     (list
      (format "# Task Verification Plan: %s" .title)
      ""
      "## Task"
      ""
      (format "- Path: `%s`" task-file)
      ""
      "## Goal"
      ""
      task-goal
      ""
      "## Open Acceptance Checks"
      ""
      (if open-checks
          (string-join (mapcar (lambda (item) (concat "- [ ] " item))
                               open-checks)
                       "\n")
        "- All task checks are complete.")
      ""
      "## Suggested Verification"
      ""
      (vibemacs--markdown-list commands "No verification commands configured.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "## Changed Files"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Verification Notes"
      ""
      "- Run the narrowest command that proves the edited behavior first."
      "- Escalate to the full suite before handoff when shared behavior changed."
      "- Append the latest verification evidence back into the task file."
      "- Refresh readiness and closeout after verification changes."
      "")
     "\n")))

(defun vibemacs-render-current-task-verification-plan-entry
    (task-file task-goal open-checks commands snapshot &optional time)
  "Render a timestamped verification plan entry.
TASK-FILE, TASK-GOAL, OPEN-CHECKS, COMMANDS, and SNAPSHOT are passed
through to `vibemacs-render-current-task-verification-plan'.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Verification Plan" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-render-current-task-verification-plan
     task-file
     task-goal
     open-checks
     commands
     snapshot))
   "\n"))

(defun vibemacs-render-current-task-final-response
    (task-file task-goal open-checks closeout snapshot)
  "Render a final-response draft for TASK-FILE.
TASK-GOAL is the task goal text.  OPEN-CHECKS are unchecked
acceptance checks.  CLOSEOUT is the task closeout text.  SNAPSHOT
supplies project evidence."
  (let-alist snapshot
    (string-join
     (list
      (format "# Final Response Draft: %s" .title)
      ""
      "## Draft"
      ""
      "Implemented the current Vibemacs task."
      ""
      "Changed:"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "Verification:"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "Task status:"
      ""
      (if open-checks
          (string-join (mapcar (lambda (item) (concat "- Remaining: " item))
                               open-checks)
                       "\n")
        "- All task checks are complete.")
      ""
      "## Evidence"
      ""
      (format "- Task file: `%s`" task-file)
      ""
      "### Goal"
      ""
      task-goal
      ""
      "### Closeout"
      ""
      closeout
      ""
      "## Response Checklist"
      ""
      "- [ ] Name the files or surfaces changed."
      "- [ ] State the verification commands that passed."
      "- [ ] Mention remaining work only when it is real."
      "- [ ] Keep the final answer concise."
      "")
     "\n")))

(defun vibemacs-render-current-task-final-response-entry
    (task-file task-goal open-checks closeout snapshot &optional time)
  "Render a timestamped final-response draft entry.
TASK-FILE, TASK-GOAL, OPEN-CHECKS, CLOSEOUT, and SNAPSHOT are passed
through to `vibemacs-render-current-task-final-response'.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Final Response Draft" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-render-current-task-final-response
     task-file
     task-goal
     open-checks
     closeout
     snapshot))
   "\n"))

(defun vibemacs-render-current-task-scope-audit
    (task-file task-goal open-checks changed-files diff-stat snapshot)
  "Render a scope audit packet for TASK-FILE.
TASK-GOAL is the task goal text.  OPEN-CHECKS are unchecked
acceptance checks.  CHANGED-FILES and DIFF-STAT describe the current
working tree.  SNAPSHOT supplies project evidence."
  (let-alist snapshot
    (string-join
     (list
      (format "# Task Scope Audit: %s" .title)
      ""
      "## Task"
      ""
      (format "- Path: `%s`" task-file)
      ""
      "## Goal"
      ""
      task-goal
      ""
      "## Open Acceptance Checks"
      ""
      (if open-checks
          (string-join (mapcar (lambda (item) (concat "- [ ] " item))
                               open-checks)
                       "\n")
        "- All task checks are complete.")
      ""
      "## Changed Files"
      ""
      (vibemacs--markdown-list changed-files "No Git changes detected.")
      ""
      "## Diff Stat"
      ""
      (vibemacs--markdown-list diff-stat "No diff stat available.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "## Scope Questions"
      ""
      "- Does every changed file support the task goal or an acceptance check?"
      "- Are there unrelated edits that should be split out before handoff?"
      "- Is any open acceptance check contradicted by the diff?"
      "- Does the final response name only the work actually completed?"
      "")
     "\n")))

(defun vibemacs-render-current-task-scope-audit-entry
    (task-file task-goal open-checks changed-files diff-stat snapshot &optional time)
  "Render a timestamped scope audit entry.
TASK-FILE, TASK-GOAL, OPEN-CHECKS, CHANGED-FILES, DIFF-STAT, and
SNAPSHOT are passed through to
`vibemacs-render-current-task-scope-audit'.  Optional TIME
supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Scope Audit" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-render-current-task-scope-audit
     task-file
     task-goal
     open-checks
     changed-files
     diff-stat
     snapshot))
   "\n"))

(defun vibemacs-render-current-task-risk-register
    (task-file task-goal open-checks changed-files snapshot)
  "Render a risk register packet for TASK-FILE.
TASK-GOAL is the task goal text.  OPEN-CHECKS are unchecked
acceptance checks.  CHANGED-FILES describes the current working tree.
SNAPSHOT supplies project evidence."
  (let-alist snapshot
    (let ((latest (car .verification-history)))
      (string-join
       (list
        (format "# Task Risk Register: %s" .title)
        ""
        "## Task"
        ""
        (format "- Path: `%s`" task-file)
        ""
        "## Goal"
        ""
        task-goal
        ""
        "## Risk Signals"
        ""
        (format "- Open acceptance checks: `%d`" (length open-checks))
        (format "- Changed files: `%d`" (length changed-files))
        (if latest
            (format "- Latest verification: `%s` `%s`"
                    (plist-get latest :status)
                    (plist-get latest :command))
          "- Latest verification: none recorded.")
        ""
        "## Open Risks"
        ""
        (if open-checks
            (string-join
             (mapcar (lambda (item)
                       (concat "- [ ] Acceptance risk: " item))
                     open-checks)
             "\n")
          "- No open acceptance risks from task checkboxes.")
        ""
        "## Changed Files Under Risk"
        ""
        (vibemacs--markdown-list changed-files "No Git changes detected.")
        ""
        "## Mitigation Prompts"
        ""
        "- Which unchecked item could invalidate the current implementation?"
        "- Which changed file has the weakest direct tie to the task goal?"
        "- Which verification command would most reduce remaining uncertainty?"
        "- What should the handoff call out as residual risk?"
        ""
        "## Recent Verification"
        ""
        (vibemacs-render-verification-history .verification-history)
        "")
       "\n"))))

(defun vibemacs-render-current-task-risk-register-entry
    (task-file task-goal open-checks changed-files snapshot &optional time)
  "Render a timestamped risk register entry.
TASK-FILE, TASK-GOAL, OPEN-CHECKS, CHANGED-FILES, and SNAPSHOT are
passed through to `vibemacs-render-current-task-risk-register'.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Risk Register" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-render-current-task-risk-register
     task-file
     task-goal
     open-checks
     changed-files
     snapshot))
   "\n"))

(defun vibemacs-render-current-task-dependency-map
    (task-file task-goal changed-files dependency-map snapshot)
  "Render a dependency map packet for TASK-FILE.
TASK-GOAL is the task goal text.  CHANGED-FILES are Git status
lines.  DEPENDENCY-MAP contains parsed dependency entries.  SNAPSHOT
supplies project evidence."
  (let-alist snapshot
    (string-join
     (list
      (format "# Task Dependency Map: %s" .title)
      ""
      "## Task"
      ""
      (format "- Path: `%s`" task-file)
      ""
      "## Goal"
      ""
      task-goal
      ""
      "## Changed Files"
      ""
      (vibemacs--markdown-list changed-files "No Git changes detected.")
      ""
      "## Source Dependencies"
      ""
      (vibemacs-render-dependency-map dependency-map)
      ""
      "## Blast Radius Questions"
      ""
      "- Which dependency should be opened before editing further?"
      "- Which changed file has dependencies that are not covered by verification?"
      "- Does any changed file imply a README, test, or journal update?"
      "- Should the final handoff mention a dependency or downstream surface?"
      ""
      "## Recent Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      "")
     "\n")))

(defun vibemacs-render-current-task-dependency-map-entry
    (task-file task-goal changed-files dependency-map snapshot &optional time)
  "Render a timestamped dependency map entry.
TASK-FILE, TASK-GOAL, CHANGED-FILES, DEPENDENCY-MAP, and SNAPSHOT
are passed through to `vibemacs-render-current-task-dependency-map'.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Dependency Map" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-render-current-task-dependency-map
     task-file
     task-goal
     changed-files
     dependency-map
     snapshot))
   "\n"))

(defun vibemacs-render-artifact-index (snapshot)
  "Render SNAPSHOT as a Markdown Vibemacs artifact index."
  (let-alist snapshot
    (string-join
     (list
      (format "# Vibemacs Artifact Index: %s" .title)
      ""
      "## Project"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Session evidence: `%s`%s"
              .session-file
              (if .session-present " (present)" " (missing)"))
      ""
      "## Current Working Set"
      ""
      "### Changed Files"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "### Open Project Buffers"
      ""
      (vibemacs--markdown-list .open-files "No project files are open.")
      ""
      "## Persistent Artifacts"
      ""
      "### Task Files"
      ""
      (vibemacs--markdown-list .task-files "No persisted task files found.")
      ""
      "### Task Status"
      ""
      (vibemacs--markdown-list .task-summaries "No task status available.")
      ""
      "### Public Journal Entries"
      ""
      (vibemacs--markdown-list .journal-files "No journal entries found.")
      ""
      "### Local Notes"
      ""
      (vibemacs--markdown-list .note-files "No local notes found.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "## Resume Prompts"
      ""
      "- Which task file should be reopened first?"
      "- Which changed file needs source context or review?"
      "- Which verification result is missing or stale?"
      "")
     "\n")))

(defun vibemacs-render-journal-entry (title slug snapshot)
  "Render a public development journal entry for TITLE and SLUG.
SNAPSHOT supplies project evidence for the draft."
  (let-alist snapshot
    (string-join
     (list
      "---"
      (format "title: \"%s\"" title)
      (format "date: %s" (vibemacs-today))
      (format "slug: \"%s\"" slug)
      "---"
      ""
      (format "# %s" title)
      ""
      "## What Changed"
      ""
      "This cycle advanced Vibemacs as an Emacs configuration for agentic programmers."
      ""
      "## Development Notes"
      ""
      "- "
      ""
      "## Project Evidence"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Session evidence: `%s`" .session-file)
      ""
      "## Changed Files"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Recent Task Status"
      ""
      (vibemacs--markdown-list .task-summaries "No task status available.")
      ""
      "## Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "## Public Summary"
      ""
      "- "
     "")
     "\n")))

(defun vibemacs-task-journal-snapshot (title)
  "Return project and task evidence for a task-derived journal TITLE."
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (task-file (file-relative-name buffer-file-name root))
         (progress (vibemacs-task-checkbox-progress))
         (goal (vibemacs-task-section-content "Goal"))
         (closeout (vibemacs-task-section-content "Closeout"))
         (open-checks (vibemacs-task-checkbox-items 'open)))
    (append
     (vibemacs-project-snapshot title)
     `((task-file . ,task-file)
       (task-title . ,(vibemacs-current-task-title))
       (task-goal . ,(if (and goal (not (string-empty-p goal)))
                         goal
                       "No task goal recorded yet."))
       (task-closeout . ,(if (and closeout (not (string-empty-p closeout)))
                             closeout
                           "No task closeout recorded yet."))
       (task-checks-complete . ,(plist-get progress :complete))
       (task-checks-total . ,(plist-get progress :total))
       (task-open-checks . ,open-checks)))))

(defun vibemacs-render-task-journal-entry (title slug snapshot)
  "Render a public development journal entry from task SNAPSHOT.
TITLE and SLUG become the journal frontmatter."
  (let-alist snapshot
    (string-join
     (list
      "---"
      (format "title: \"%s\"" title)
      (format "date: %s" (vibemacs-today))
      (format "slug: \"%s\"" slug)
      "---"
      ""
      (format "# %s" title)
      ""
      "## What Changed"
      ""
      "This cycle advanced Vibemacs through a persisted task file, carrying implementation evidence into the public development journal."
      ""
      "## Task Evidence"
      ""
      (format "- Task file: `%s`" .task-file)
      (format "- Task title: `%s`" .task-title)
      (format "- Acceptance checks: `%d/%d complete`"
              .task-checks-complete
              .task-checks-total)
      ""
      "### Goal"
      ""
      .task-goal
      ""
      "### Remaining Checks"
      ""
      (if .task-open-checks
          (string-join (mapcar (lambda (item) (concat "- [ ] " item))
                               .task-open-checks)
                       "\n")
        "- All task checks are complete.")
      ""
      "### Closeout Evidence"
      ""
      .task-closeout
      ""
      "## Project Evidence"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Session evidence: `%s`" .session-file)
      ""
      "## Changed Files"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Verification"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "## Public Summary"
      ""
      "- "
      "")
     "\n")))


(provide 'vibemacs-artifacts)

;;; vibemacs-artifacts.el ends here
