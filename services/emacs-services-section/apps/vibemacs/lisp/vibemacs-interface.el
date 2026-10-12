;;; vibemacs-interface.el --- Interactive controls for Vibemacs -*- lexical-binding: t; -*-

;;; Commentary:
;; The cockpit, task board, action palette, and interactive commands.

;;; Code:

(require 'subr-x)
(require 'cl-lib)
(require 'vibemacs-foundation)
(require 'vibemacs-workflow)
(require 'vibemacs-evidence)
(require 'vibemacs-artifacts)
(defun vibemacs-cockpit-actions ()
  "Return cockpit action descriptors.
Each descriptor is (KEY LABEL COMMAND DESCRIPTION)."
  '(("p" "Prompt packet" vibemacs-open-prompt-packet
     "Draft an agent-ready task prompt.")
    ("A" "Next actions" vibemacs-open-current-task-next-actions
     "Open a next-action packet for the current task file.")
    ("L" "Write next" vibemacs-insert-current-task-next-actions
     "Append a next-actions packet to the current task file.")
    ("P" "Task prompt" vibemacs-open-current-task-prompt
     "Open an agent prompt packet seeded from the current task file.")
    ("X" "Write prompt" vibemacs-insert-current-task-prompt
     "Append an agent prompt packet to the current task file.")
    ("T" "Task review" vibemacs-open-current-task-review
     "Open a review packet for the current task, readiness, closeout, and diff.")
    ("a" "Task buffer" vibemacs-open-task
     "Create or reopen a persisted task file from project evidence.")
    ("b" "Task board" vibemacs-open-task-board
     "Open a tabulated board of persisted task files.")
    ("r" "Recent task" vibemacs-open-recent-task
     "Open an existing persisted task file.")
    ("x" "Context packet" vibemacs-open-context-packet
     "Collect project evidence for a handoff.")
    ("i" "Artifact index" vibemacs-open-artifact-index
     "Open a resume map of tasks, journals, notes, buffers, and verification.")
    ("f" "Source packet" vibemacs-open-source-context
     "Open a line-numbered packet for the selected code or current definition.")
    ("F" "Final response" vibemacs-open-current-task-final-response
     "Open a final-response draft from the current task file.")
    ("I" "Write final" vibemacs-insert-current-task-final-response
     "Append a final-response draft to the current task file.")
    ("S" "Scope audit" vibemacs-open-current-task-scope-audit
     "Open a scope audit packet for the current task and Git changes.")
    ("O" "Write scope" vibemacs-insert-current-task-scope-audit
     "Append a scope audit to the current task file.")
    ("K" "Risk register" vibemacs-open-current-task-risk-register
     "Open a risk register packet for the current task and remaining checks.")
    ("U" "Write risks" vibemacs-insert-current-task-risk-register
     "Append a risk register to the current task file.")
    ("M" "Dependency map" vibemacs-open-current-task-dependency-map
     "Open a dependency map for changed files in the current task.")
    ("B" "Write deps" vibemacs-insert-current-task-dependency-map
     "Append a dependency map to the current task file.")
    ("Q" "Review checklist" vibemacs-insert-task-review-checklist
     "Append a durable review checklist to the current task file.")
    ("d" "Change review" vibemacs-open-change-review
     "Open a packet summarizing Git status, diff stat, diff excerpt, and verification.")
    ("G" "Verify guide" vibemacs-open-current-task-verification-plan
     "Open a verification plan packet for the current task file.")
    ("N" "Write verify" vibemacs-insert-current-task-verification-plan
     "Append a verification plan to the current task file.")
    ("t" "Transcript" vibemacs-open-transcript
     "Open the working command transcript.")
    ("v" "Verify" vibemacs-run-verification
     "Run and record a verification command.")
    ("V" "Verify suite" vibemacs-run-verification-suite
     "Run every configured verification command in sequence.")
    ("e" "Insert evidence" vibemacs-insert-latest-verification-evidence
     "Append the latest verification result to the current task file.")
    ("E" "Evidence snapshot" vibemacs-insert-verification-history-snapshot
     "Append the current verification history to the current task file.")
    ("k" "Checkpoint task" vibemacs-insert-task-checkpoint
     "Append changed files, open buffers, and verification to the current task file.")
    ("h" "Task handoff" vibemacs-copy-current-task-handoff
     "Copy the current task file plus fresh project evidence for another agent.")
    ("H" "Write handoff" vibemacs-insert-current-task-handoff
     "Append a fresh task handoff bundle to the current task file.")
    ("D" "Record decision" vibemacs-insert-task-decision
     "Append a timestamped decision and rationale to the current task file.")
    ("n" "Next check" vibemacs-next-task-checkbox
     "Move to the next unchecked Markdown task checkbox.")
    ("m" "Toggle check" vibemacs-toggle-task-checkbox
     "Toggle the Markdown task checkbox on the current line.")
    ("R" "Task readiness" vibemacs-open-task-readiness
     "Open a readiness report for the current task file.")
    ("W" "Write readiness" vibemacs-insert-task-readiness
     "Append a readiness snapshot to the current task file.")
    ("o" "Closeout task" vibemacs-insert-task-closeout
     "Append a concise closeout summary to the current task file.")
    ("c" "Cycle note" vibemacs-start-cycle
     "Start a local development cycle note.")
    ("j" "Journal" vibemacs-open-journal-entry
     "Open today's public development journal entry.")
    ("J" "Task journal" vibemacs-open-task-journal-entry
     "Open a public journal draft seeded from the current task file.")
    ("s" "Ship checklist" vibemacs-insert-shipping-checklist
     "Insert the end-of-cycle checklist.")
    ("w" "Save session" vibemacs-save-session
     "Persist recent session evidence to the project.")
    ("l" "Load session" vibemacs-load-session
     "Reload persisted session evidence.")
    ("y" "Copy handoff" vibemacs-copy-handoff-bundle
     "Copy a full agent handoff bundle to the kill ring.")))

(defconst vibemacs-task-action-commands
  '(vibemacs-open-current-task-next-actions
    vibemacs-insert-current-task-next-actions
    vibemacs-open-current-task-prompt
    vibemacs-insert-current-task-prompt
    vibemacs-open-current-task-review
    vibemacs-open-current-task-final-response
    vibemacs-insert-current-task-final-response
    vibemacs-open-current-task-scope-audit
    vibemacs-insert-current-task-scope-audit
    vibemacs-open-current-task-risk-register
    vibemacs-insert-current-task-risk-register
    vibemacs-open-current-task-dependency-map
    vibemacs-insert-current-task-dependency-map
    vibemacs-insert-task-review-checklist
    vibemacs-open-current-task-verification-plan
    vibemacs-insert-current-task-verification-plan
    vibemacs-run-verification
    vibemacs-run-verification-suite
    vibemacs-insert-latest-verification-evidence
    vibemacs-insert-verification-history-snapshot
    vibemacs-insert-task-checkpoint
    vibemacs-copy-current-task-handoff
    vibemacs-insert-current-task-handoff
    vibemacs-insert-task-decision
    vibemacs-next-task-checkbox
    vibemacs-toggle-task-checkbox
    vibemacs-open-task-readiness
    vibemacs-insert-task-readiness
    vibemacs-insert-task-closeout
    vibemacs-open-task-journal-entry)
  "Commands shown in the persisted task action menu.")

(defun vibemacs-task-actions ()
  "Return cockpit descriptors that are meaningful in persisted task files."
  (seq-filter
   (lambda (action)
     (memq (nth 2 action) vibemacs-task-action-commands))
   (vibemacs-cockpit-actions)))

(defun vibemacs-task-action-candidates (&optional actions)
  "Return completion candidates for task ACTIONS.
Each candidate is a cons cell whose car is display text and whose cdr is
the original action descriptor."
  (mapcar (lambda (action)
            (pcase-let ((`(,key ,label ,_command ,description) action))
              (cons (format "[%s] %s - %s" key label description)
                    action)))
          (or actions (vibemacs-task-actions))))

(defun vibemacs-task-action-command (choice &optional actions)
  "Return the command selected by CHOICE from task ACTIONS."
  (let ((action (cdr (assoc choice (vibemacs-task-action-candidates actions)))))
    (unless action
      (user-error "Unknown Vibemacs task action: %s" choice))
    (nth 2 action)))

(defun vibemacs-dispatch-task-action ()
  "Prompt for and run an action against the current persisted task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((candidates (vibemacs-task-action-candidates))
         (choice (completing-read "Task action: "
                                  (mapcar #'car candidates)
                                  nil
                                  t))
         (command (vibemacs-task-action-command
                   choice
                   (mapcar #'cdr candidates))))
    (call-interactively command)
    command))

(defun vibemacs-render-cockpit (snapshot)
  "Render SNAPSHOT as a plain-text cockpit overview."
  (let-alist snapshot
    (let ((changed-count (length .changed-files))
          (open-count (length .open-files))
          (verify-count (length .verification)))
      (string-join
       (list
        "Vibemacs"
        "========"
        ""
        "Project"
        "-------"
        (format "Root: %s" .root)
        (format "Branch: %s" .branch)
        (format "Session: %s" .session-file)
        (format "Status: %s, %s, %s"
                (vibemacs--plural changed-count "changed file" "changed files")
                (vibemacs--plural open-count "open project buffer" "open project buffers")
                (vibemacs--plural verify-count "verification command" "verification commands"))
        ""
        "Actions"
        "-------"
        (string-join
         (mapcar (lambda (action)
                   (pcase-let ((`(,key ,label ,_command ,description) action))
                     (format "[%s] %-15s %s" key label description)))
                 (vibemacs-cockpit-actions))
         "\n")
        ""
        "Diagnostics"
        "-----------"
        (if .diagnostics
            (string-join .diagnostics "\n")
          "No project diagnostics available.")
        ""
        "Changed Files"
        "-------------"
        (if .changed-files
            (string-join .changed-files "\n")
          "No Git changes detected.")
        ""
        "Recent Task Files"
        "-----------------"
        (if .task-files
            (string-join .task-files "\n")
          "No persisted task files found.")
        ""
        "Recent Task Status"
        "------------------"
        (if .task-summaries
            (string-join .task-summaries "\n")
          "No task status available.")
        ""
        "Suggested Verification"
        "----------------------"
        (if .verification
            (string-join .verification "\n")
          "No verification commands configured.")
        ""
        "Recent Verification"
        "-------------------"
        (vibemacs-render-verification-history .verification-history)
        "")
       "\n"))))

(defun vibemacs--insert-cockpit-button (key label command description)
  "Insert one cockpit action button for KEY LABEL COMMAND and DESCRIPTION."
  (insert (format "[%s] " key))
  (insert-text-button label
                      'follow-link t
                      'help-echo description
                      'action (lambda (_button)
                                (call-interactively command)))
  (insert (format "\n    %s\n" description)))

(defun vibemacs-refresh-task-board ()
  "Refresh the current Vibemacs task board."
  (interactive)
  (unless (derived-mode-p 'vibemacs-task-board-mode)
    (user-error "Current buffer is not a Vibemacs task board"))
  (setq tabulated-list-entries
        (vibemacs-task-board-entries vibemacs-task-board-root))
  (tabulated-list-print t)
  tabulated-list-entries)

(defun vibemacs-task-board-open-task ()
  "Open the task on the current task board row."
  (interactive)
  (let ((file (tabulated-list-get-id)))
    (unless file
      (user-error "No Vibemacs task on this row"))
    (find-file (expand-file-name
                file
                (file-name-as-directory
                 (or vibemacs-task-board-root
                     (vibemacs-project-root)))))))

(defun vibemacs-open-task-board ()
  "Open a tabulated board of persisted Vibemacs task files."
  (interactive)
  (let ((root (file-name-as-directory (vibemacs-project-root)))
        (buffer (get-buffer-create vibemacs-task-board-buffer-name)))
    (with-current-buffer buffer
      (vibemacs-task-board-mode)
      (setq vibemacs-task-board-root root)
      (vibemacs-refresh-task-board))
    (pop-to-buffer buffer)
    buffer))

(defun vibemacs-open-cockpit ()
  "Open the Vibemacs agentic programming cockpit."
  (interactive)
  (let ((buffer (get-buffer-create vibemacs-cockpit-buffer-name))
        (snapshot (vibemacs-project-snapshot "Cockpit")))
    (with-current-buffer buffer
      (vibemacs-cockpit-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (let-alist snapshot
          (insert "Vibemacs\n========\n\n")
          (insert "Project\n-------\n")
          (insert (format "Root: %s\n" .root))
          (insert (format "Branch: %s\n" .branch))
          (insert (format "Session: %s\n" .session-file))
          (insert (format "Status: %s, %s, %s\n\n"
                          (vibemacs--plural (length .changed-files)
                                                  "changed file" "changed files")
                          (vibemacs--plural (length .open-files)
                                                  "open project buffer"
                                                  "open project buffers")
                          (vibemacs--plural (length .verification)
                                                  "verification command"
                                                  "verification commands")))
          (insert "Actions\n-------\n")
          (dolist (action (vibemacs-cockpit-actions))
            (pcase-let ((`(,key ,label ,command ,description) action))
              (vibemacs--insert-cockpit-button key label command description)))
          (insert "\nDiagnostics\n-----------\n")
          (insert (if .diagnostics
                      (string-join .diagnostics "\n")
                    "No project diagnostics available."))
          (insert "\nChanged Files\n-------------\n")
          (insert (if .changed-files
                      (string-join .changed-files "\n")
                    "No Git changes detected."))
          (insert "\n\nRecent Task Files\n-----------------\n")
          (insert (if .task-files
                      (string-join .task-files "\n")
                    "No persisted task files found."))
          (insert "\n\nRecent Task Status\n------------------\n")
          (insert (if .task-summaries
                      (string-join .task-summaries "\n")
                    "No task status available."))
          (insert "\n\nSuggested Verification\n----------------------\n")
          (insert (if .verification
                      (string-join .verification "\n")
                    "No verification commands configured."))
          (insert "\n\nRecent Verification\n-------------------\n")
          (insert (vibemacs-render-verification-history .verification-history))
          (insert "\n\nKeys: g refresh, q quit\n")))
      (goto-char (point-min)))
    (pop-to-buffer buffer)))

(defun vibemacs-copy-handoff-bundle (&optional title)
  "Copy a full agent handoff bundle for TITLE to the kill ring."
  (interactive "sHandoff title: ")
  (let* ((heading (if (and title (not (string-empty-p (string-trim title))))
                      title
                    "Agent Handoff"))
         (bundle (vibemacs-render-handoff-bundle
                  (vibemacs-project-snapshot heading))))
    (kill-new bundle)
    (message "Copied Vibemacs handoff bundle (%d characters)" (length bundle))
    bundle))

(defun vibemacs-copy-current-task-handoff ()
  "Copy the current persisted task plus fresh project evidence to the kill ring."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (task-file (file-relative-name buffer-file-name root))
         (task-text (vibemacs-current-task-text))
         (bundle (vibemacs-render-current-task-handoff
                  task-file
                  task-text
                  (vibemacs-project-snapshot "Current Task"))))
    (kill-new bundle)
    (message "Copied Vibemacs task handoff (%d characters)" (length bundle))
    bundle))

(defun vibemacs-insert-current-task-handoff ()
  "Append a fresh handoff bundle to the current persisted task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (task-file (file-relative-name buffer-file-name root))
         (task-text (vibemacs-current-task-text))
         (entry (vibemacs-render-current-task-handoff-entry
                 task-file
                 task-text
                 (vibemacs-project-snapshot
                  (vibemacs-current-task-title)))))
    (vibemacs-append-task-section-entry "Agent Handoff Bundle" entry)
    (vibemacs-refresh-task-status)
    (message "Inserted Vibemacs task handoff bundle")
    entry))

(defun vibemacs-open-current-task-prompt ()
  "Open an agent prompt packet seeded from the current persisted task."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (task-file (file-relative-name buffer-file-name root))
         (task-text (vibemacs-current-task-text))
         (prompt (vibemacs-render-current-task-prompt
                  task-file
                  task-text
                  (vibemacs-project-snapshot
                   (vibemacs-current-task-title)))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-prompt*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert prompt)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-insert-current-task-prompt ()
  "Append an agent prompt packet to the current persisted task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (task-file (file-relative-name buffer-file-name root))
         (task-text (vibemacs-current-task-text))
         (entry (vibemacs-render-current-task-prompt-entry
                 task-file
                 task-text
                 (vibemacs-project-snapshot
                  (vibemacs-current-task-title)))))
    (vibemacs-append-task-section-entry "Task Prompt Packets" entry)
    (vibemacs-refresh-task-status)
    (message "Inserted Vibemacs task prompt packet")
    entry))

(defun vibemacs-open-current-task-review ()
  "Open a review packet for the current persisted task."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (task-text (vibemacs-current-task-text))
         (readiness (vibemacs-render-task-readiness task-file))
         (closeout (or (vibemacs-task-section-content "Closeout")
                       "No task closeout recorded yet."))
         (change-review
          (vibemacs-render-change-review
           (vibemacs-change-review-snapshot
            (format "Current Task: %s" title))))
         (review (vibemacs-render-current-task-review
                  task-file
                  task-text
                  readiness
                  closeout
                  change-review
                  (vibemacs-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-review*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert review)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-open-current-task-next-actions ()
  "Open a next-action packet for the current persisted task."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (progress (vibemacs-task-checkbox-progress))
         (goal (vibemacs-task-section-content "Goal"))
         (open-checks (vibemacs-task-checkbox-items 'open))
         (packet (vibemacs-render-current-task-next-actions
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  open-checks
                  (plist-get progress :complete)
                  (plist-get progress :total)
                  (vibemacs-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-next-actions*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-insert-current-task-next-actions ()
  "Append a next-actions packet to the current persisted task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (progress (vibemacs-task-checkbox-progress))
         (goal (vibemacs-task-section-content "Goal"))
         (open-checks (vibemacs-task-checkbox-items 'open))
         (entry (vibemacs-render-current-task-next-actions-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 open-checks
                 (plist-get progress :complete)
                 (plist-get progress :total)
                 (vibemacs-project-snapshot title))))
    (vibemacs-append-task-section-entry "Next Actions" entry)
    (vibemacs-refresh-task-status)
    (message "Inserted Vibemacs task next actions")
    entry))

(defun vibemacs-open-current-task-verification-plan ()
  "Open a verification plan packet for the current persisted task."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-task-section-content "Goal"))
         (open-checks (vibemacs-task-checkbox-items 'open))
         (packet (vibemacs-render-current-task-verification-plan
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  open-checks
                  (vibemacs-verification-suite-plan)
                  (vibemacs-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-verification-plan*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-insert-current-task-verification-plan ()
  "Append a verification plan to the current persisted task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-task-section-content "Goal"))
         (open-checks (vibemacs-task-checkbox-items 'open))
         (entry (vibemacs-render-current-task-verification-plan-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 open-checks
                 (vibemacs-verification-suite-plan)
                 (vibemacs-project-snapshot title))))
    (vibemacs-append-task-section-entry "Verification Plans" entry)
    (vibemacs-refresh-task-status)
    (message "Inserted Vibemacs task verification plan")
    entry))

(defun vibemacs-open-current-task-final-response ()
  "Open a final-response draft for the current persisted task."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-task-section-content "Goal"))
         (open-checks (vibemacs-task-checkbox-items 'open))
         (closeout (vibemacs-task-section-content "Closeout"))
         (packet (vibemacs-render-current-task-final-response
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  open-checks
                  (if (and closeout (not (string-empty-p closeout)))
                      closeout
                    "No task closeout recorded yet.")
                  (vibemacs-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-final-response*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-insert-current-task-final-response ()
  "Append a final-response draft to the current persisted task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-task-section-content "Goal"))
         (open-checks (vibemacs-task-checkbox-items 'open))
         (closeout (vibemacs-task-section-content "Closeout"))
         (entry (vibemacs-render-current-task-final-response-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 open-checks
                 (if (and closeout (not (string-empty-p closeout)))
                     closeout
                   "No task closeout recorded yet.")
                 (vibemacs-project-snapshot title))))
    (vibemacs-append-task-section-entry "Final Response Drafts" entry)
    (vibemacs-refresh-task-status)
    (message "Inserted Vibemacs final response draft")
    entry))

(defun vibemacs-open-current-task-scope-audit ()
  "Open a scope audit packet for the current persisted task."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-task-section-content "Goal"))
         (open-checks (vibemacs-task-checkbox-items 'open))
         (packet (vibemacs-render-current-task-scope-audit
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  open-checks
                  (or (vibemacs-git-changed-files root) '())
                  (or (vibemacs-git-diff-stat root) '())
                  (vibemacs-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-scope-audit*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-insert-current-task-scope-audit ()
  "Append a scope audit to the current persisted task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-task-section-content "Goal"))
         (open-checks (vibemacs-task-checkbox-items 'open))
         (entry (vibemacs-render-current-task-scope-audit-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 open-checks
                 (or (vibemacs-git-changed-files root) '())
                 (or (vibemacs-git-diff-stat root) '())
                 (vibemacs-project-snapshot title))))
    (vibemacs-append-task-section-entry "Scope Audits" entry)
    (vibemacs-refresh-task-status)
    (message "Inserted Vibemacs task scope audit")
    entry))

(defun vibemacs-open-current-task-risk-register ()
  "Open a risk register packet for the current persisted task."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-task-section-content "Goal"))
         (open-checks (vibemacs-task-checkbox-items 'open))
         (packet (vibemacs-render-current-task-risk-register
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  open-checks
                  (or (vibemacs-git-changed-files root) '())
                  (vibemacs-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-risk-register*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-insert-current-task-risk-register ()
  "Append a risk register to the current persisted task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-task-section-content "Goal"))
         (open-checks (vibemacs-task-checkbox-items 'open))
         (entry (vibemacs-render-current-task-risk-register-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 open-checks
                 (or (vibemacs-git-changed-files root) '())
                 (vibemacs-project-snapshot title))))
    (vibemacs-append-task-section-entry "Risk Registers" entry)
    (vibemacs-refresh-task-status)
    (message "Inserted Vibemacs task risk register")
    entry))

(defun vibemacs-open-current-task-dependency-map ()
  "Open a dependency map packet for the current persisted task."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-task-section-content "Goal"))
         (changed-files (or (vibemacs-git-changed-files root) '()))
         (packet (vibemacs-render-current-task-dependency-map
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  changed-files
                  (vibemacs-changed-file-dependency-map
                   root
                   changed-files)
                  (vibemacs-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-dependency-map*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-insert-current-task-dependency-map ()
  "Append a dependency map to the current persisted task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-task-section-content "Goal"))
         (changed-files (or (vibemacs-git-changed-files root) '()))
         (entry (vibemacs-render-current-task-dependency-map-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 changed-files
                 (vibemacs-changed-file-dependency-map
                  root
                  changed-files)
                 (vibemacs-project-snapshot title))))
    (vibemacs-append-task-section-entry "Dependency Maps" entry)
    (vibemacs-refresh-task-status)
    (message "Inserted Vibemacs task dependency map")
    entry))

(defun vibemacs-open-task (title)
  "Open a persisted structured Vibemacs task file for TITLE."
  (interactive "sTask title: ")
  (let* ((heading (if (string-empty-p (string-trim title)) "Agent Task" title))
         (file (vibemacs-task-path heading)))
    (vibemacs-ensure-directory (file-name-directory file))
    (find-file file)
    (vibemacs-maybe-enable-task-mode)
    (when (= (buffer-size) 0)
      (insert (vibemacs-render-task
               (vibemacs-project-snapshot heading)))
      (goto-char (point-min)))
    (current-buffer)))

(defun vibemacs-open-recent-task (task)
  "Open existing persisted TASK selected from project task files."
  (interactive
   (let ((tasks (vibemacs-task-files)))
     (list (completing-read "Task file: " tasks nil t nil nil (car tasks)))))
  (let ((file (expand-file-name task (vibemacs-project-root))))
    (find-file file)
    (vibemacs-maybe-enable-task-mode)))

(defun vibemacs-open-prompt-packet ()
  "Open a prompt packet buffer for the current context."
  (interactive)
  (let ((buffer (vibemacs-new-scratch-buffer "*vibemacs-prompt*" #'vibemacs-markdown-mode)))
    (when (= (buffer-size buffer) 0)
      (insert (vibemacs-prompt-template)))
    buffer))

(defun vibemacs-open-transcript ()
  "Open an agent transcript buffer."
  (interactive)
  (let ((buffer (vibemacs-new-scratch-buffer vibemacs-transcript-buffer-name
                                             #'vibemacs-markdown-mode)))
    (when (= (buffer-size buffer) 0)
      (insert (vibemacs-transcript-template)))
    buffer))

(defun vibemacs-read-verification-command ()
  "Read a verification command from `vibemacs-verification-commands'."
  (completing-read "Verify command: "
                   vibemacs-verification-commands
                   nil nil nil nil
                   (car vibemacs-verification-commands)))

(defun vibemacs-run-verification (command)
  "Run verification COMMAND from the project root and record it."
  (interactive (list (vibemacs-read-verification-command)))
  (vibemacs--start-verification-command command))

(defun vibemacs-run-verification-suite (&optional commands)
  "Run COMMANDS as a sequential verification suite.
When COMMANDS is nil, use `vibemacs-verification-commands'."
  (interactive)
  (let ((plan (vibemacs-verification-suite-plan commands)))
    (unless plan
      (user-error "No verification commands configured"))
    (message "Running Vibemacs verification suite: %d commands" (length plan))
    (vibemacs--start-verification-command
     (car plan)
     (cdr plan)
     (vibemacs-project-root))))

(defun vibemacs-insert-latest-verification-evidence ()
  "Append the latest verification result to the current task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((entry (vibemacs-latest-verification-result)))
    (unless entry
      (user-error "No verification results recorded"))
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "^## Verification Evidence\\b" nil t)
          (progn
            (forward-line 1)
            (unless (looking-at-p "\\s-*$")
              (insert "\n")))
        (goto-char (point-max))
        (unless (bolp)
          (insert "\n"))
        (insert "\n## Verification Evidence\n\n"))
      (while (and (not (eobp))
                  (not (looking-at-p "^## ")))
        (forward-line 1))
      (unless (or (bobp) (save-excursion
                           (forward-line -1)
                           (looking-at-p "\\s-*$")))
        (insert "\n"))
      (insert (vibemacs-render-verification-entry entry) "\n")
      (when (looking-at-p "^## ")
        (insert "\n")))
    (message "Inserted latest Vibemacs verification evidence")
    entry))

(defun vibemacs-insert-verification-history-snapshot ()
  "Append the current verification history to the current task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (unless vibemacs-verification-history
    (user-error "No verification results recorded"))
  (let ((snapshot (vibemacs-render-verification-history-snapshot)))
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "^## Verification Evidence\\b" nil t)
          (progn
            (forward-line 1)
            (unless (looking-at-p "\\s-*$")
              (insert "\n")))
        (goto-char (point-max))
        (unless (bolp)
          (insert "\n"))
        (insert "\n## Verification Evidence\n\n"))
      (while (and (not (eobp))
                  (not (looking-at-p "^## ")))
        (forward-line 1))
      (unless (or (bobp) (save-excursion
                           (forward-line -1)
                           (looking-at-p "\\s-*$")))
        (insert "\n"))
      (insert snapshot)
      (when (looking-at-p "^## ")
        (insert "\n")))
    (message "Inserted Vibemacs verification history snapshot")
    snapshot))

(defun vibemacs-insert-task-checkpoint ()
  "Append a project checkpoint to the current task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((checkpoint (vibemacs-render-task-checkpoint
                     (vibemacs-project-snapshot "Task Checkpoint"))))
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "^## Checkpoints\\b" nil t)
          (progn
            (forward-line 1)
            (unless (looking-at-p "\\s-*$")
              (insert "\n")))
        (goto-char (point-max))
        (unless (bolp)
          (insert "\n"))
        (insert "\n## Checkpoints\n\n"))
      (while (and (not (eobp))
                  (not (looking-at-p "^## ")))
        (forward-line 1))
      (unless (or (bobp) (save-excursion
                           (forward-line -1)
                           (looking-at-p "\\s-*$")))
        (insert "\n"))
      (insert checkpoint)
      (when (looking-at-p "^## ")
        (insert "\n")))
    (message "Inserted Vibemacs task checkpoint")
    checkpoint))

(defun vibemacs-insert-task-decision (decision rationale)
  "Append DECISION and RATIONALE to the current task file."
  (interactive "sDecision: \nsRationale: ")
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (when (string-empty-p (string-trim decision))
    (user-error "Decision cannot be empty"))
  (let ((entry (vibemacs-render-task-decision
                decision
                (if (string-empty-p (string-trim rationale))
                    "No rationale recorded."
                  rationale))))
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "^## Decisions\\b" nil t)
          (progn
            (forward-line 1)
            (unless (looking-at-p "\\s-*$")
              (insert "\n")))
        (goto-char (point-max))
        (unless (bolp)
          (insert "\n"))
        (insert "\n## Decisions\n\n"))
      (while (and (not (eobp))
                  (not (looking-at-p "^## ")))
        (forward-line 1))
      (unless (or (bobp) (save-excursion
                           (forward-line -1)
                           (looking-at-p "\\s-*$")))
        (insert "\n"))
      (insert entry)
      (when (looking-at-p "^## ")
        (insert "\n")))
    (message "Inserted Vibemacs task decision")
    entry))

(defun vibemacs-next-task-checkbox ()
  "Move point to the next unchecked checkbox in the current task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((origin (point))
        found)
    (while (and (not found)
                (re-search-forward vibemacs-task-checkbox-regexp nil t))
      (when (string= (match-string 1) " ")
        (setq found (match-beginning 1))))
    (unless found
      (goto-char (point-min))
      (while (and (not found)
                  (< (point) origin)
                  (re-search-forward vibemacs-task-checkbox-regexp origin t))
        (when (string= (match-string 1) " ")
          (setq found (match-beginning 1)))))
    (unless found
      (goto-char origin)
      (user-error "No unchecked task checkboxes found"))
    (goto-char found)
    (message "Moved to unchecked Vibemacs task checkbox")
    found))

(defun vibemacs-toggle-task-checkbox ()
  "Toggle the Markdown task checkbox on the current line."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((line-end (line-end-position))
        replacement)
    (save-excursion
      (beginning-of-line)
      (unless (re-search-forward vibemacs-task-checkbox-regexp line-end t)
        (user-error "Current line is not a task checkbox"))
      (setq replacement (if (string= (match-string 1) " ") "x" " "))
      (replace-match replacement t t nil 1))
    (let* ((progress (vibemacs-task-checkbox-progress))
           (message-text (format "%d/%d checks complete"
                                 (plist-get progress :complete)
                                 (plist-get progress :total))))
      (message "Vibemacs task checkbox toggled: %s" message-text)
      message-text)))

(defun vibemacs-open-task-readiness ()
  "Open a readiness report for the current task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((report (vibemacs-render-task-readiness)))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-readiness*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert report)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-insert-task-readiness ()
  "Append a readiness snapshot to the current task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((snapshot (vibemacs-render-task-readiness-snapshot)))
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "^## Readiness Reports\\b" nil t)
          (progn
            (forward-line 1)
            (unless (looking-at-p "\\s-*$")
              (insert "\n")))
        (goto-char (point-max))
        (unless (bolp)
          (insert "\n"))
        (insert "\n## Readiness Reports\n\n"))
      (while (and (not (eobp))
                  (not (looking-at-p "^## ")))
        (forward-line 1))
      (unless (or (bobp) (save-excursion
                           (forward-line -1)
                           (looking-at-p "\\s-*$")))
        (insert "\n"))
      (insert snapshot)
      (when (looking-at-p "^## ")
        (insert "\n")))
    (message "Inserted Vibemacs task readiness snapshot")
    snapshot))

(defun vibemacs-insert-task-closeout ()
  "Append a closeout summary to the current task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((closeout (vibemacs-render-task-closeout)))
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "^## Closeout\\b" nil t)
          (progn
            (forward-line 1)
            (unless (looking-at-p "\\s-*$")
              (insert "\n")))
        (goto-char (point-max))
        (unless (bolp)
          (insert "\n"))
        (insert "\n## Closeout\n\n"))
      (while (and (not (eobp))
                  (not (looking-at-p "^## ")))
        (forward-line 1))
      (unless (or (bobp) (save-excursion
                           (forward-line -1)
                           (looking-at-p "\\s-*$")))
        (insert "\n"))
      (insert closeout)
      (when (looking-at-p "^## ")
        (insert "\n")))
    (message "Inserted Vibemacs task closeout")
    closeout))

(defun vibemacs-insert-task-review-checklist ()
  "Append a review checklist to the current task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((checklist (vibemacs-render-task-review-checklist)))
    (vibemacs-append-task-section-entry "Review Checklist" checklist)
    (vibemacs-refresh-task-status)
    (message "Inserted Vibemacs task review checklist")
    checklist))

(defun vibemacs-open-context-packet (title)
  "Open a project context packet buffer named by TITLE."
  (interactive "sContext title: ")
  (let ((buffer (vibemacs-new-scratch-buffer "*vibemacs-context*" #'vibemacs-markdown-mode)))
    (erase-buffer)
    (insert (vibemacs-render-context-packet
             (vibemacs-project-snapshot
              (if (string-empty-p (string-trim title)) "Agent Context" title))))
    (goto-char (point-min))
    buffer))

(defun vibemacs-open-artifact-index ()
  "Open a Markdown index of Vibemacs project artifacts."
  (interactive)
  (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-artifacts*"
                                                    #'vibemacs-markdown-mode)
    (erase-buffer)
    (insert (vibemacs-render-artifact-index
             (vibemacs-artifact-snapshot "Project Artifacts")))
    (goto-char (point-min))
    (current-buffer)))

(defun vibemacs-open-source-context ()
  "Open a line-numbered source context packet for the current source range."
  (interactive)
  (let ((packet (vibemacs-render-source-context
                 (vibemacs-code-context-snapshot))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-source-context*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-open-change-review (&optional title)
  "Open a Markdown change review packet for TITLE."
  (interactive "sReview title: ")
  (let* ((heading (if (and title (not (string-empty-p (string-trim title))))
                      title
                    "Change Review"))
         (packet (vibemacs-render-change-review
                  (vibemacs-change-review-snapshot heading))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-change-review*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-start-cycle (title)
  "Create a local development cycle note named from TITLE."
  (interactive "sCycle title: ")
  (let* ((directory (vibemacs-ensure-directory
                     (vibemacs-expand-project-file vibemacs-notes-directory)))
         (file (expand-file-name
                (format "%s-%s.md" (vibemacs-today) (vibemacs-slugify title))
                directory)))
    (find-file file)
    (when (= (buffer-size) 0)
      (insert (vibemacs-cycle-template title)))))

(defun vibemacs-open-journal-entry (title)
  "Open today's public journal entry for TITLE."
  (interactive "sJournal title: ")
  (let* ((directory (vibemacs-ensure-directory
                     (vibemacs-expand-project-file vibemacs-cycle-directory)))
         (slug (vibemacs-slugify title))
         (file (expand-file-name (format "%s-%s.md" (vibemacs-today) slug) directory)))
    (find-file file)
    (when (= (buffer-size) 0)
      (insert
       (vibemacs-render-journal-entry
       title
       slug
       (vibemacs-project-snapshot title))))))

(defun vibemacs-open-task-journal-entry ()
  "Open today's public journal entry seeded from the current task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((title (vibemacs-current-task-title))
         (slug (vibemacs-slugify title))
         (snapshot (vibemacs-task-journal-snapshot title))
         (directory (vibemacs-ensure-directory
                     (vibemacs-expand-project-file vibemacs-cycle-directory)))
         (file (expand-file-name (format "%s-%s.md" (vibemacs-today) slug)
                                 directory)))
    (find-file file)
    (when (= (buffer-size) 0)
      (insert
       (vibemacs-render-task-journal-entry title slug snapshot)))
    (current-buffer)))

(defun vibemacs-insert-shipping-checklist ()
  "Insert the Vibemacs shipping checklist at point."
  (interactive)
  (insert (vibemacs-shipping-checklist)))

(defun vibemacs-apply-defaults ()
  "Install default Vibemacs agentic workflow bindings."
  (add-hook 'compilation-finish-functions #'vibemacs--compilation-finished)
  (add-hook 'find-file-hook #'vibemacs-maybe-enable-task-mode)
  (vibemacs-load-session)
  (define-key vibemacs-prefix-map (kbd "RET") #'vibemacs-open-cockpit)
  (define-key vibemacs-prefix-map (kbd "C") #'vibemacs-dispatch-task-action)
  (define-key vibemacs-prefix-map (kbd "A") #'vibemacs-open-current-task-next-actions)
  (define-key vibemacs-prefix-map (kbd "L") #'vibemacs-insert-current-task-next-actions)
  (define-key vibemacs-prefix-map (kbd "a") #'vibemacs-open-task)
  (define-key vibemacs-prefix-map (kbd "b") #'vibemacs-open-task-board)
  (define-key vibemacs-prefix-map (kbd "r") #'vibemacs-open-recent-task)
  (define-key vibemacs-prefix-map (kbd "p") #'vibemacs-open-prompt-packet)
  (define-key vibemacs-prefix-map (kbd "P") #'vibemacs-open-current-task-prompt)
  (define-key vibemacs-prefix-map (kbd "X") #'vibemacs-insert-current-task-prompt)
  (define-key vibemacs-prefix-map (kbd "t") #'vibemacs-open-transcript)
  (define-key vibemacs-prefix-map (kbd "T") #'vibemacs-open-current-task-review)
  (define-key vibemacs-prefix-map (kbd "x") #'vibemacs-open-context-packet)
  (define-key vibemacs-prefix-map (kbd "i") #'vibemacs-open-artifact-index)
  (define-key vibemacs-prefix-map (kbd "f") #'vibemacs-open-source-context)
  (define-key vibemacs-prefix-map (kbd "F") #'vibemacs-open-current-task-final-response)
  (define-key vibemacs-prefix-map (kbd "I") #'vibemacs-insert-current-task-final-response)
  (define-key vibemacs-prefix-map (kbd "S") #'vibemacs-open-current-task-scope-audit)
  (define-key vibemacs-prefix-map (kbd "O") #'vibemacs-insert-current-task-scope-audit)
  (define-key vibemacs-prefix-map (kbd "K") #'vibemacs-open-current-task-risk-register)
  (define-key vibemacs-prefix-map (kbd "U") #'vibemacs-insert-current-task-risk-register)
  (define-key vibemacs-prefix-map (kbd "M") #'vibemacs-open-current-task-dependency-map)
  (define-key vibemacs-prefix-map (kbd "B") #'vibemacs-insert-current-task-dependency-map)
  (define-key vibemacs-prefix-map (kbd "Q") #'vibemacs-insert-task-review-checklist)
  (define-key vibemacs-prefix-map (kbd "d") #'vibemacs-open-change-review)
  (define-key vibemacs-prefix-map (kbd "G") #'vibemacs-open-current-task-verification-plan)
  (define-key vibemacs-prefix-map (kbd "N") #'vibemacs-insert-current-task-verification-plan)
  (define-key vibemacs-prefix-map (kbd "v") #'vibemacs-run-verification)
  (define-key vibemacs-prefix-map (kbd "V") #'vibemacs-run-verification-suite)
  (define-key vibemacs-prefix-map (kbd "c") #'vibemacs-start-cycle)
  (define-key vibemacs-prefix-map (kbd "j") #'vibemacs-open-journal-entry)
  (define-key vibemacs-prefix-map (kbd "J") #'vibemacs-open-task-journal-entry)
  (define-key vibemacs-prefix-map (kbd "s") #'vibemacs-insert-shipping-checklist)
  (define-key vibemacs-prefix-map (kbd "w") #'vibemacs-save-session)
  (define-key vibemacs-prefix-map (kbd "l") #'vibemacs-load-session)
  (define-key vibemacs-prefix-map (kbd "y") #'vibemacs-copy-handoff-bundle)
  (define-key vibemacs-prefix-map (kbd "e") #'vibemacs-insert-latest-verification-evidence)
  (define-key vibemacs-prefix-map (kbd "E") #'vibemacs-insert-verification-history-snapshot)
  (define-key vibemacs-prefix-map (kbd "k") #'vibemacs-insert-task-checkpoint)
  (define-key vibemacs-prefix-map (kbd "h") #'vibemacs-copy-current-task-handoff)
  (define-key vibemacs-prefix-map (kbd "H") #'vibemacs-insert-current-task-handoff)
  (define-key vibemacs-prefix-map (kbd "D") #'vibemacs-insert-task-decision)
  (define-key vibemacs-prefix-map (kbd "n") #'vibemacs-next-task-checkbox)
  (define-key vibemacs-prefix-map (kbd "m") #'vibemacs-toggle-task-checkbox)
  (define-key vibemacs-prefix-map (kbd "R") #'vibemacs-open-task-readiness)
  (define-key vibemacs-prefix-map (kbd "W") #'vibemacs-insert-task-readiness)
  (define-key vibemacs-prefix-map (kbd "o") #'vibemacs-insert-task-closeout))

(provide 'vibemacs-interface)

;;; vibemacs-interface.el ends here
