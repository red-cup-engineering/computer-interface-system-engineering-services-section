;;; vibemacs-workflow.el --- Durable agent-work state for Vibemacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Persisted sessions, verification evidence, structured task files, and task state.

;;; Code:

(require 'subr-x)
(require 'cl-lib)
(require 'compile)
(require 'seq)
(require 'tabulated-list)
(require 'thingatpt)
(require 'vibemacs-foundation)

(defgroup vibemacs-workflow nil
  "Agentic programming affordances for Vibemacs."
  :group 'vibemacs)

(defcustom vibemacs-default-constraints
  '("Read the current code before editing."
    "Prefer existing project conventions over new abstractions."
    "Run the narrowest meaningful verification before handing work back."
    "Write a public development journal entry at the end of the cycle.")
  "Default constraints inserted into prompt packets."
  :type '(repeat string)
  :group 'vibemacs-workflow)

(defcustom vibemacs-verification-commands
  '("npm test"
    "npm run compile"
    "emacs -Q --batch -L lisp -l init.el")
  "Default verification commands included in context packets."
  :type '(repeat string)
  :group 'vibemacs-workflow)

(defcustom vibemacs-transcript-buffer-name "*vibemacs-transcript*"
  "Buffer name used for Vibemacs agent transcripts."
  :type 'string
  :group 'vibemacs-workflow)

(defcustom vibemacs-cockpit-buffer-name "*vibemacs*"
  "Buffer name used for the Vibemacs cockpit."
  :type 'string
  :group 'vibemacs-workflow)

(defcustom vibemacs-task-board-buffer-name "*vibemacs-tasks*"
  "Buffer name used for the Vibemacs task board."
  :type 'string
  :group 'vibemacs-workflow)

(defcustom vibemacs-verification-history-limit 8
  "Maximum number of verification results kept in memory."
  :type 'integer
  :group 'vibemacs-workflow)

(defcustom vibemacs-session-file "dev/.vibemacs-session.el"
  "Project-relative file used to persist Vibemacs session evidence."
  :type 'string
  :group 'vibemacs-workflow)

(defcustom vibemacs-task-directory "dev/tasks"
  "Project-relative directory used for persisted Vibemacs task files."
  :type 'string
  :group 'vibemacs-workflow)

(defcustom vibemacs-task-list-limit 8
  "Maximum number of recent task files shown in Vibemacs surfaces."
  :type 'integer
  :group 'vibemacs-workflow)

(defcustom vibemacs-artifact-list-limit 12
  "Maximum number of recent artifacts shown in index surfaces."
  :type 'integer
  :group 'vibemacs-workflow)

(defcustom vibemacs-source-context-line-limit 160
  "Maximum source lines included in a source context packet."
  :type 'integer
  :group 'vibemacs-workflow)

(defcustom vibemacs-change-review-line-limit 260
  "Maximum diff lines included in a change review packet."
  :type 'integer
  :group 'vibemacs-workflow)

(defcustom vibemacs-dependency-map-file-limit 12
  "Maximum changed files included in a task dependency map."
  :type 'integer
  :group 'vibemacs-workflow)

(defcustom vibemacs-save-session-on-verification t
  "When non-nil, save session evidence after verification finishes."
  :type 'boolean
  :group 'vibemacs-workflow)

(defvar vibemacs-verification-history nil
  "Recent verification result plists.
Each entry contains :time, :command, :status, and :detail.")

(defvar-local vibemacs--verification-command nil
  "Verification command associated with a compilation buffer.")

(defvar-local vibemacs--verification-queue nil
  "Remaining verification commands associated with a compilation buffer.")

(defvar-local vibemacs--verification-root nil
  "Project root associated with a verification compilation buffer.")

(defvar-local vibemacs-task-mode--previous-header-line-format nil
  "Header line value restored when `vibemacs-task-mode' is disabled.")

(defconst vibemacs-task-checkbox-regexp "^\\s-*[-*] \\[\\([ xX]\\)\\] "
  "Regexp matching a Markdown task checkbox line.")

(defvar vibemacs-cockpit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'vibemacs-open-cockpit)
    (define-key map (kbd "A") #'vibemacs-open-current-task-next-actions)
    (define-key map (kbd "L") #'vibemacs-insert-current-task-next-actions)
    (define-key map (kbd "p") #'vibemacs-open-prompt-packet)
    (define-key map (kbd "P") #'vibemacs-open-current-task-prompt)
    (define-key map (kbd "X") #'vibemacs-insert-current-task-prompt)
    (define-key map (kbd "t") #'vibemacs-open-transcript)
    (define-key map (kbd "T") #'vibemacs-open-current-task-review)
    (define-key map (kbd "x") #'vibemacs-open-context-packet)
    (define-key map (kbd "i") #'vibemacs-open-artifact-index)
    (define-key map (kbd "f") #'vibemacs-open-source-context)
    (define-key map (kbd "F") #'vibemacs-open-current-task-final-response)
    (define-key map (kbd "I") #'vibemacs-insert-current-task-final-response)
    (define-key map (kbd "S") #'vibemacs-open-current-task-scope-audit)
    (define-key map (kbd "O") #'vibemacs-insert-current-task-scope-audit)
    (define-key map (kbd "K") #'vibemacs-open-current-task-risk-register)
    (define-key map (kbd "U") #'vibemacs-insert-current-task-risk-register)
    (define-key map (kbd "M") #'vibemacs-open-current-task-dependency-map)
    (define-key map (kbd "B") #'vibemacs-insert-current-task-dependency-map)
    (define-key map (kbd "Q") #'vibemacs-insert-task-review-checklist)
    (define-key map (kbd "d") #'vibemacs-open-change-review)
    (define-key map (kbd "G") #'vibemacs-open-current-task-verification-plan)
    (define-key map (kbd "N") #'vibemacs-insert-current-task-verification-plan)
    (define-key map (kbd "v") #'vibemacs-run-verification)
    (define-key map (kbd "V") #'vibemacs-run-verification-suite)
    (define-key map (kbd "c") #'vibemacs-start-cycle)
    (define-key map (kbd "j") #'vibemacs-open-journal-entry)
    (define-key map (kbd "J") #'vibemacs-open-task-journal-entry)
    (define-key map (kbd "s") #'vibemacs-insert-shipping-checklist)
    (define-key map (kbd "w") #'vibemacs-save-session)
    (define-key map (kbd "l") #'vibemacs-load-session)
    (define-key map (kbd "y") #'vibemacs-copy-handoff-bundle)
    (define-key map (kbd "H") #'vibemacs-insert-current-task-handoff)
    (define-key map (kbd "a") #'vibemacs-open-task)
    (define-key map (kbd "b") #'vibemacs-open-task-board)
    (define-key map (kbd "r") #'vibemacs-open-recent-task)
    (define-key map (kbd "e") #'vibemacs-insert-latest-verification-evidence)
    (define-key map (kbd "E") #'vibemacs-insert-verification-history-snapshot)
    (define-key map (kbd "k") #'vibemacs-insert-task-checkpoint)
    (define-key map (kbd "h") #'vibemacs-copy-current-task-handoff)
    (define-key map (kbd "D") #'vibemacs-insert-task-decision)
    (define-key map (kbd "n") #'vibemacs-next-task-checkbox)
    (define-key map (kbd "m") #'vibemacs-toggle-task-checkbox)
    (define-key map (kbd "R") #'vibemacs-open-task-readiness)
    (define-key map (kbd "W") #'vibemacs-insert-task-readiness)
    (define-key map (kbd "o") #'vibemacs-insert-task-closeout)
    map)
  "Keymap for `vibemacs-cockpit-mode'.")

(define-derived-mode vibemacs-cockpit-mode special-mode "Vibemacs"
  "Major mode for the Vibemacs agentic programming cockpit.")

(defvar vibemacs-task-board-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "RET") #'vibemacs-task-board-open-task)
    (define-key map (kbd "g") #'vibemacs-refresh-task-board)
    map)
  "Keymap for `vibemacs-task-board-mode'.")

(defvar-local vibemacs-task-board-root nil
  "Project root displayed by the current Vibemacs task board.")

(define-derived-mode vibemacs-task-board-mode tabulated-list-mode "VTasks"
  "Major mode for the Vibemacs persisted task board."
  (setq tabulated-list-format
        [("Task" 32 t)
         ("Checks" 10 t)
         ("Open" 6 tabulated-list-sort-numeric)
         ("Ready" 8 t)
         ("File" 48 t)])
  (setq tabulated-list-padding 2)
  (setq tabulated-list-sort-key (cons "File" nil))
  (tabulated-list-init-header))

(defvar vibemacs-task-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'vibemacs-dispatch-task-action)
    (define-key map (kbd "C-c C-n") #'vibemacs-next-task-checkbox)
    (define-key map (kbd "C-c C-m") #'vibemacs-toggle-task-checkbox)
    (define-key map (kbd "C-c C-a") #'vibemacs-open-current-task-next-actions)
    (define-key map (kbd "C-c ,") #'vibemacs-insert-current-task-next-actions)
    (define-key map (kbd "C-c C-e") #'vibemacs-insert-latest-verification-evidence)
    (define-key map (kbd "C-c C-E") #'vibemacs-insert-verification-history-snapshot)
    (define-key map (kbd "C-c C-k") #'vibemacs-insert-task-checkpoint)
    (define-key map (kbd "C-c C-d") #'vibemacs-insert-task-decision)
    (define-key map (kbd "C-c C-f") #'vibemacs-open-current-task-final-response)
    (define-key map (kbd "C-c C-i") #'vibemacs-insert-current-task-final-response)
    (define-key map (kbd "C-c C-g") #'vibemacs-open-current-task-verification-plan)
    (define-key map (kbd "C-c ;") #'vibemacs-insert-current-task-verification-plan)
    (define-key map (kbd "C-c C-p") #'vibemacs-open-current-task-prompt)
    (define-key map (kbd "C-c .") #'vibemacs-insert-current-task-prompt)
    (define-key map (kbd "C-c C-h") #'vibemacs-copy-current-task-handoff)
    (define-key map (kbd "C-c C-y") #'vibemacs-insert-current-task-handoff)
    (define-key map (kbd "C-c C-v") #'vibemacs-open-current-task-review)
    (define-key map (kbd "C-c C-u") #'vibemacs-open-current-task-scope-audit)
    (define-key map (kbd "C-c C-z") #'vibemacs-insert-current-task-scope-audit)
    (define-key map (kbd "C-c C-l") #'vibemacs-open-current-task-risk-register)
    (define-key map (kbd "C-c C-x") #'vibemacs-insert-current-task-risk-register)
    (define-key map (kbd "C-c C-b") #'vibemacs-open-current-task-dependency-map)
    (define-key map (kbd "C-c C-t") #'vibemacs-insert-current-task-dependency-map)
    (define-key map (kbd "C-c C-q") #'vibemacs-insert-task-review-checklist)
    (define-key map (kbd "C-c C-s") #'vibemacs-refresh-task-status)
    (define-key map (kbd "C-c C-r") #'vibemacs-open-task-readiness)
    (define-key map (kbd "C-c C-w") #'vibemacs-insert-task-readiness)
    (define-key map (kbd "C-c C-o") #'vibemacs-insert-task-closeout)
    (define-key map (kbd "C-c C-j") #'vibemacs-open-task-journal-entry)
    map)
  "Keymap for `vibemacs-task-mode'.")

(define-minor-mode vibemacs-task-mode
  "Minor mode for persisted Vibemacs task files."
  :lighter " VTask"
  :keymap vibemacs-task-mode-map
  (if vibemacs-task-mode
      (progn
        (setq vibemacs-task-mode--previous-header-line-format header-line-format)
        (vibemacs-refresh-task-status))
    (setq header-line-format vibemacs-task-mode--previous-header-line-format)))

(defun vibemacs-prompt-template (&optional title)
  "Return a prompt packet template for TITLE."
  (let ((heading (or title (vibemacs-buffer-heading))))
    (string-join
     (append
      (list
       (format "# Prompt Packet: %s" heading)
       ""
       "## Goal"
       ""
       "## Current Evidence"
       ""
       "## Constraints")
      (mapcar (lambda (item) (concat "- " item)) vibemacs-default-constraints)
      (list
       ""
       "## Acceptance Checks"
       ""
       "- [ ] Implementation matches the requested end state."
       "- [ ] Relevant tests or manual checks passed."
       "- [ ] Public journal entry added under `dev/docs/journal/`."
       ""
       "## Handoff Notes"
       ""))
     "\n")))

(defun vibemacs-transcript-template ()
  "Return a transcript buffer template."
  (string-join
   (list
    (format "# Agent Transcript: %s" (vibemacs-today))
    ""
    "## Intent"
    ""
    "## Commands"
    ""
    "| Time | Action | Evidence |"
    "| --- | --- | --- |"
    ""
    "## Decisions"
    ""
    "## Follow-up"
    "")
   "\n"))

(defun vibemacs--markdown-table-cell (value)
  "Escape VALUE for use inside a Markdown table cell."
  (string-replace "|" "\\|" (string-trim (format "%s" value))))

(defun vibemacs-transcript-row (command evidence &optional time)
  "Return a transcript row for COMMAND with EVIDENCE.
Optional TIME supplies the displayed timestamp."
  (format "| %s | `%s` | %s |"
          (vibemacs--markdown-table-cell
           (or time (format-time-string "%H:%M")))
          (vibemacs--markdown-table-cell command)
          (vibemacs--markdown-table-cell evidence)))

(defun vibemacs-append-transcript-entry (command evidence &optional time buffer)
  "Append a transcript entry for COMMAND and EVIDENCE.
Optional TIME overrides the timestamp.  Optional BUFFER receives the entry."
  (let ((target (get-buffer-create (or buffer vibemacs-transcript-buffer-name))))
    (with-current-buffer target
      (unless (derived-mode-p 'text-mode 'markdown-mode)
        (vibemacs-markdown-mode))
      (when (= (buffer-size) 0)
        (insert (vibemacs-transcript-template)))
      (save-excursion
        (goto-char (point-min))
        (if (search-forward "| --- | --- | --- |" nil t)
            (progn
              (end-of-line)
              (insert "\n" (vibemacs-transcript-row command evidence time)))
          (goto-char (point-max))
          (unless (bolp)
            (insert "\n"))
          (insert "\n## Commands\n\n| Time | Action | Evidence |\n| --- | --- | --- |\n"
                  (vibemacs-transcript-row command evidence time)))))
    target))

(defun vibemacs-verification-status (message)
  "Return a symbolic verification status from compilation MESSAGE."
  (if (string-match-p "\\bfinished\\b" message)
      "passed"
    "failed"))

(defun vibemacs-record-verification-result (command status detail &optional time)
  "Record verification COMMAND with STATUS, DETAIL, and optional TIME.

STATUS is normalized to text because verification evidence is serialized and
later rendered in Markdown as well as retained in the live session."
  (let ((entry (list :time (or time (format-time-string "%H:%M"))
                     :command command
                     :status (format "%s" status)
                     :detail (string-trim detail))))
    (setq vibemacs-verification-history
          (seq-take (cons entry vibemacs-verification-history)
                    vibemacs-verification-history-limit))
    entry))

(defun vibemacs-session-path (&optional root)
  "Return the Vibemacs session path for ROOT or the current project."
  (expand-file-name vibemacs-session-file
                    (file-name-as-directory (or root (vibemacs-project-root)))))

(defun vibemacs-task-path (title &optional root)
  "Return a project-local task file path for TITLE under ROOT."
  (expand-file-name
   (format "%s-%s.md" (vibemacs-today) (vibemacs-slugify title))
   (expand-file-name vibemacs-task-directory
                     (file-name-as-directory (or root (vibemacs-project-root))))))

(defun vibemacs-project-files (directory regexp &optional root limit)
  "Return project-relative files under DIRECTORY matching REGEXP.
ROOT defaults to the current project.  LIMIT caps the newest-first result."
  (let* ((project-root (file-name-as-directory (or root (vibemacs-project-root))))
         (target (expand-file-name directory project-root)))
    (if (file-directory-p target)
        (let ((files (sort
                      (mapcar (lambda (file) (file-relative-name file project-root))
                              (directory-files-recursively target regexp))
                      #'string>)))
          (if limit (seq-take files limit) files))
      '())))

(defun vibemacs-task-files (&optional root)
  "Return project-relative task files for ROOT, newest filename first."
  (vibemacs-project-files vibemacs-task-directory "\\.md\\'" root))

(defun vibemacs-recent-task-files (&optional root)
  "Return recent project-relative task files for ROOT."
  (seq-take (vibemacs-task-files root) vibemacs-task-list-limit))

(defun vibemacs-task-file-p (&optional file root)
  "Return non-nil when FILE is a Vibemacs task file under ROOT."
  (when-let ((source (or file buffer-file-name)))
    (let* ((project-root (file-name-as-directory (or root (vibemacs-project-root))))
           (task-root (file-name-as-directory
                       (expand-file-name vibemacs-task-directory project-root)))
           (target (expand-file-name source)))
      (and (string-prefix-p task-root target)
           (string-suffix-p ".md" target)))))

(defun vibemacs-task-checkbox-progress ()
  "Return checkbox progress for the current buffer as a plist."
  (let ((complete 0)
        (total 0))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward vibemacs-task-checkbox-regexp nil t)
        (setq total (1+ total))
        (when (member (match-string 1) '("x" "X"))
          (setq complete (1+ complete)))))
    (list :complete complete :total total)))

(defun vibemacs-task-checkbox-items (&optional state)
  "Return Markdown checkbox item text from the current buffer.
When STATE is `complete', return checked items.  When STATE is
`open', return unchecked items.  Any other value returns all checkbox
items."
  (let (items)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward vibemacs-task-checkbox-regexp nil t)
        (let* ((mark (match-string 1))
               (checked (member mark '("x" "X")))
               (line-end (line-end-position))
               (text (string-trim
                      (buffer-substring-no-properties (point) line-end))))
          (when (or (null state)
                    (and (eq state 'complete) checked)
                    (and (eq state 'open) (not checked)))
            (push text items)))))
    (nreverse items)))

(defun vibemacs-task-status-text ()
  "Return a compact status string for the current task buffer."
  (let* ((progress (vibemacs-task-checkbox-progress))
         (latest (vibemacs-latest-verification-result))
         (file (if buffer-file-name
                   (file-relative-name buffer-file-name (vibemacs-project-root))
                 (buffer-name))))
    (format "Vibemacs Task: %s | %d/%d checks | %s"
            file
            (plist-get progress :complete)
            (plist-get progress :total)
            (if latest
                (format "%s `%s`"
                        (plist-get latest :status)
                        (plist-get latest :command))
              "no verification yet"))))

(defun vibemacs-refresh-task-status ()
  "Refresh the task header status in the current task file."
  (interactive)
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (setq header-line-format '(:eval (vibemacs-task-status-text)))
  (force-mode-line-update)
  (when (called-interactively-p 'interactive)
    (message "%s" (vibemacs-task-status-text)))
  header-line-format)

(defun vibemacs-task-section-content (heading)
  "Return text under Markdown section HEADING in the current buffer."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (format "^## %s\\b" (regexp-quote heading)) nil t)
      (let ((start (progn (forward-line 1) (point)))
            (end (or (save-excursion
                       (when (re-search-forward "^## " nil t)
                         (match-beginning 0)))
                     (point-max))))
        (string-trim (buffer-substring-no-properties start end))))))

(defun vibemacs-task-section-present-p (heading)
  "Return non-nil when Markdown section HEADING is present."
  (not (null (vibemacs-task-section-content heading))))

(defun vibemacs-task-section-has-content-p (heading)
  "Return non-nil when Markdown section HEADING has non-placeholder content."
  (when-let ((content (vibemacs-task-section-content heading)))
    (seq-some
     (lambda (line)
       (let ((trimmed (string-trim line)))
         (and (not (string-empty-p trimmed))
              (not (member trimmed '("-" "- ")))
              (not (string-prefix-p "```" trimmed)))))
     (split-string content "\n"))))

(defun vibemacs--task-title-in-buffer (&optional fallback)
  "Return the task title in the current buffer.
FALLBACK is used when no Markdown title is present."
  (save-excursion
    (goto-char (point-min))
    (let ((title (if (re-search-forward "^# +\\(.+\\)$" nil t)
                     (string-trim (match-string 1))
                   fallback)))
      (string-remove-prefix "Vibemacs Task: " (or title "")))))

(defun vibemacs--task-heading-in-buffer (&optional fallback)
  "Return the raw Markdown task heading in the current buffer.
FALLBACK is used when no Markdown title is present."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^# +\\(.+\\)$" nil t)
        (string-trim (match-string 1))
      fallback)))

(defun vibemacs-task-readiness-progress ()
  "Return readiness progress for the current task buffer as a plist."
  (let* ((progress (vibemacs-task-checkbox-progress))
         (complete (plist-get progress :complete))
         (total (plist-get progress :total))
         (checks (list
                  (vibemacs-task-section-has-content-p "Goal")
                  (> total 0)
                  (and (> total 0) (= complete total))
                  (vibemacs-task-section-has-content-p "Verification Evidence")
                  (vibemacs-task-section-has-content-p "Checkpoints")
                  (vibemacs-task-section-present-p "Agent Handoff Bundle"))))
    (list :complete (cl-count-if #'identity checks)
          :total (length checks))))

(defun vibemacs-task-record (file &optional root)
  "Return structured task metadata for project-relative FILE under ROOT."
  (let* ((project-root (file-name-as-directory (or root (vibemacs-project-root))))
         (absolute-file (expand-file-name file project-root))
         (title file)
         (progress '(:complete 0 :total 0))
         (readiness '(:complete 0 :total 6))
         (open-count 0))
    (when (file-readable-p absolute-file)
      (with-temp-buffer
        (insert-file-contents absolute-file)
        (setq title (vibemacs--task-title-in-buffer file))
        (setq progress (vibemacs-task-checkbox-progress))
        (setq readiness (vibemacs-task-readiness-progress))
        (setq open-count (length (vibemacs-task-checkbox-items 'open)))))
    (list :file file
          :title title
          :complete (plist-get progress :complete)
          :total (plist-get progress :total)
          :open open-count
          :readiness-complete (plist-get readiness :complete)
          :readiness-total (plist-get readiness :total))))

(defun vibemacs-task-board-entries (&optional root)
  "Return `tabulated-list-entries' rows for persisted tasks under ROOT."
  (let ((project-root (file-name-as-directory (or root (vibemacs-project-root)))))
    (mapcar
     (lambda (file)
       (let* ((record (vibemacs-task-record file project-root))
              (complete (plist-get record :complete))
              (total (plist-get record :total))
              (ready (plist-get record :readiness-complete))
              (ready-total (plist-get record :readiness-total)))
         (list file
               (vector
                (plist-get record :title)
                (format "%d/%d" complete total)
                (number-to-string (plist-get record :open))
                (format "%d/%d" ready ready-total)
                file))))
     (vibemacs-task-files project-root))))

(defun vibemacs-append-task-section-entry (heading entry)
  "Append ENTRY under Markdown section HEADING in the current task file."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward (format "^## %s\\b" (regexp-quote heading)) nil t)
        (progn
          (forward-line 1)
          (unless (looking-at-p "\\s-*$")
            (insert "\n")))
      (goto-char (point-max))
      (unless (bolp)
        (insert "\n"))
      (insert (format "\n## %s\n\n" heading)))
    (while (and (not (eobp))
                (not (looking-at-p "^## ")))
      (forward-line 1))
    (unless (or (bobp) (save-excursion
                         (forward-line -1)
                         (looking-at-p "\\s-*$")))
      (insert "\n"))
    (insert entry)
    (when (looking-at-p "^## ")
      (insert "\n"))))

(defun vibemacs--readiness-line (ready label detail)
  "Render a readiness line for READY LABEL and DETAIL."
  (format "- [%s] %s%s"
          (if ready "x" " ")
          label
          (if (and detail (not (string-empty-p detail)))
              (concat " - " detail)
            "")))

(defun vibemacs-render-task-readiness (&optional task-file)
  "Render a Markdown readiness report for the current task buffer.
Optional TASK-FILE supplies the displayed project-relative path."
  (let* ((progress (vibemacs-task-checkbox-progress))
         (complete (plist-get progress :complete))
         (total (plist-get progress :total))
         (checks-complete (and (> total 0) (= complete total)))
         (latest (vibemacs-latest-verification-result))
         (file (or task-file
                   (and buffer-file-name
                        (file-relative-name buffer-file-name (vibemacs-project-root)))
                   (buffer-name))))
    (string-join
     (list
      (format "# Task Readiness: %s" file)
      ""
      "## Summary"
      ""
      (format "- Acceptance checks: `%d/%d complete`" complete total)
      (if latest
          (format "- Latest verification: `%s %s`"
                  (plist-get latest :status)
                  (plist-get latest :command))
        "- Latest verification: `none recorded`")
      ""
      "## Readiness Checks"
      ""
      (vibemacs--readiness-line
       (vibemacs-task-section-has-content-p "Goal")
       "Goal has task-specific content."
       nil)
      (vibemacs--readiness-line
       (> total 0)
       "Acceptance checks exist."
       (format "%d checks" total))
      (vibemacs--readiness-line
       checks-complete
       "Acceptance checks are complete."
       (format "%d/%d complete" complete total))
      (vibemacs--readiness-line
       (vibemacs-task-section-has-content-p "Verification Evidence")
       "Verification evidence is recorded in the task."
       nil)
      (vibemacs--readiness-line
       (vibemacs-task-section-has-content-p "Checkpoints")
       "At least one checkpoint is recorded."
       nil)
      (vibemacs--readiness-line
       (vibemacs-task-section-has-content-p "Decisions")
       "At least one decision is recorded."
       nil)
      (vibemacs--readiness-line
       (vibemacs-task-section-present-p "Agent Handoff Bundle")
       "Agent handoff section is present."
       nil)
      ""
      "## Next Actions"
      ""
      "- Fill any unchecked readiness item before final handoff."
      "- Run verification and append evidence when behavior changes."
      "- Write or refresh the public journal entry before closing the cycle."
      "")
     "\n")))

(defun vibemacs-render-task-readiness-snapshot (&optional time)
  "Render a timestamped readiness snapshot for task insertion.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Readiness" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-render-task-readiness))
   "\n"))

(defun vibemacs-render-task-closeout (&optional time)
  "Render a timestamped task closeout summary.
Optional TIME supplies the displayed timestamp."
  (let* ((progress (vibemacs-task-checkbox-progress))
         (complete (plist-get progress :complete))
         (total (plist-get progress :total))
         (open-items (vibemacs-task-checkbox-items 'open))
         (latest (vibemacs-latest-verification-result)))
    (string-join
     (list
      (format "### %s Closeout" (or time (format-time-string "%H:%M")))
      ""
      "#### Status"
      ""
      (format "- Acceptance checks: `%d/%d complete`" complete total)
      (if latest
          (format "- Latest verification: `%s %s` - %s"
                  (plist-get latest :status)
                  (plist-get latest :command)
                  (plist-get latest :detail))
        "- Latest verification: `none recorded`")
      ""
      "#### Remaining Checks"
      ""
      (if open-items
          (string-join (mapcar (lambda (item) (concat "- [ ] " item))
                               open-items)
                       "\n")
        "- All acceptance checks complete.")
      ""
      "#### Handoff Note"
      ""
      "- Use this closeout with the readiness report and verification evidence before final handoff."
      "")
     "\n")))

(defun vibemacs-render-task-review-checklist (&optional time)
  "Render a timestamped review checklist for task insertion.
Optional TIME supplies the displayed timestamp."
  (let* ((progress (vibemacs-task-checkbox-progress))
         (complete (plist-get progress :complete))
         (total (plist-get progress :total))
         (open-items (vibemacs-task-checkbox-items 'open))
         (latest (vibemacs-latest-verification-result)))
    (string-join
     (list
      (format "### %s Review Checklist" (or time (format-time-string "%H:%M")))
      ""
      "#### Task State"
      ""
      (format "- Acceptance checks: `%d/%d complete`" complete total)
      (if latest
          (format "- Latest verification: `%s %s` - %s"
                  (plist-get latest :status)
                  (plist-get latest :command)
                  (plist-get latest :detail))
        "- Latest verification: `none recorded`")
      ""
      "#### Review Checks"
      ""
      "- [ ] The implementation still matches the task goal."
      "- [ ] Every changed file is intentional for this task."
      "- [ ] Source dependencies and downstream surfaces were considered."
      "- [ ] Remaining risks are recorded or explicitly accepted."
      "- [ ] Relevant verification passed after the latest edit."
      "- [ ] Public journal entry exists under `dev/docs/journal/`."
      "- [ ] Final response names only completed work and real residual risk."
      ""
      "#### Open Acceptance Checks"
      ""
      (if open-items
          (string-join (mapcar (lambda (item) (concat "- [ ] " item))
                               open-items)
                       "\n")
        "- All task acceptance checks are complete.")
      "")
     "\n")))

(defun vibemacs-task-summary (file &optional root)
  "Return a human-readable summary for task FILE under ROOT."
  (let* ((record (vibemacs-task-record file root))
         (project-root (file-name-as-directory (or root (vibemacs-project-root))))
         (absolute-file (expand-file-name file project-root))
         (title (if (file-readable-p absolute-file)
                    (with-temp-buffer
                      (insert-file-contents absolute-file)
                      (vibemacs--task-heading-in-buffer (plist-get record :title)))
                  (plist-get record :title))))
    (format "%s - %s - %d/%d checks complete"
            file
            title
            (plist-get record :complete)
            (plist-get record :total))))

(defun vibemacs-task-summaries (&optional root)
  "Return summaries for recent task files under ROOT."
  (let ((project-root (file-name-as-directory (or root (vibemacs-project-root)))))
    (mapcar (lambda (file) (vibemacs-task-summary file project-root))
            (vibemacs-recent-task-files project-root))))

(defun vibemacs-current-task-text ()
  "Return the current task buffer as text."
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (buffer-substring-no-properties (point-min) (point-max)))

(defun vibemacs-current-task-title ()
  "Return the title of the current persisted task file."
  (unless (vibemacs-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (vibemacs--task-title-in-buffer (file-name-base buffer-file-name)))

(defun vibemacs-maybe-enable-task-mode ()
  "Enable `vibemacs-task-mode' in persisted task files."
  (when (vibemacs-task-file-p)
    (vibemacs-task-mode 1)))

(defun vibemacs-journal-files (&optional root)
  "Return recent project-relative public journal files under ROOT."
  (vibemacs-project-files
   vibemacs-cycle-directory
   "\\.md\\'"
   root
   vibemacs-artifact-list-limit))

(defun vibemacs-note-files (&optional root)
  "Return recent project-relative local note files under ROOT."
  (vibemacs-project-files
   vibemacs-notes-directory
   "\\.md\\'"
   root
   vibemacs-artifact-list-limit))

(defun vibemacs--valid-verification-entry-p (entry)
  "Return non-nil when ENTRY is a valid verification history plist."
  (and (listp entry)
       (stringp (plist-get entry :time))
       (stringp (plist-get entry :command))
       (stringp (plist-get entry :status))
       (stringp (plist-get entry :detail))))

(defun vibemacs-session-data ()
  "Return serializable Vibemacs session data."
  (list :version 1
        :verification-history vibemacs-verification-history))

(defun vibemacs-save-session (&optional file)
  "Save Vibemacs session evidence to FILE.
When FILE is nil, use `vibemacs-session-path'."
  (interactive)
  (let ((target (or file (vibemacs-session-path))))
    (vibemacs-ensure-directory (file-name-directory target))
    (with-temp-file target
      (insert ";;; Vibemacs session evidence -*- mode: emacs-lisp; lexical-binding: t; -*-\n")
      (let ((print-length nil)
            (print-level nil))
        (prin1 (vibemacs-session-data) (current-buffer)))
      (insert "\n"))
    (when (called-interactively-p 'interactive)
      (message "Saved Vibemacs session to %s" (abbreviate-file-name target)))
    target))

(defun vibemacs-read-session-file (file)
  "Read Vibemacs session data from FILE."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (condition-case nil
          (read (current-buffer))
        (error nil)))))

(defun vibemacs-load-session (&optional file)
  "Load Vibemacs session evidence from FILE.
When FILE is nil, use `vibemacs-session-path'."
  (interactive)
  (let* ((source (or file (vibemacs-session-path)))
         (data (vibemacs-read-session-file source))
         (history (plist-get data :verification-history)))
    (when (listp history)
      (setq vibemacs-verification-history
            (seq-take (seq-filter #'vibemacs--valid-verification-entry-p history)
                      vibemacs-verification-history-limit)))
    (when (called-interactively-p 'interactive)
      (message "Loaded %d Vibemacs verification results from %s"
               (length vibemacs-verification-history)
               (abbreviate-file-name source)))
    vibemacs-verification-history))

(defun vibemacs-render-verification-history (history)
  "Render verification HISTORY as cockpit text."
  (if history
      (string-join
       (mapcar
        #'vibemacs-render-verification-entry
        history)
       "\n")
    "No verification results recorded yet."))

(defun vibemacs-render-verification-history-snapshot (&optional time history)
  "Render a timestamped verification HISTORY snapshot.
Optional TIME supplies the displayed timestamp.  HISTORY defaults to
`vibemacs-verification-history'."
  (string-join
   (list
    (format "### %s Verification Snapshot" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-render-verification-history
     (or history vibemacs-verification-history)))
   "\n"))

(defun vibemacs-latest-verification-result ()
  "Return the newest recorded verification result."
  (car vibemacs-verification-history))

(defun vibemacs-render-verification-entry (entry)
  "Render one verification ENTRY as a Markdown bullet."
  (format "- %s %s `%s` - %s"
          (plist-get entry :time)
          (plist-get entry :status)
          (plist-get entry :command)
          (plist-get entry :detail)))

(defun vibemacs-refresh-cockpit-if-open ()
  "Refresh the cockpit buffer when it already exists."
  (when (get-buffer vibemacs-cockpit-buffer-name)
    (vibemacs-open-cockpit)))

(defun vibemacs-verification-suite-plan (&optional commands)
  "Return normalized verification COMMANDS for a suite run."
  (seq-filter
   (lambda (command)
     (and (stringp command)
          (not (string-empty-p (string-trim command)))))
   (or commands vibemacs-verification-commands)))

(defun vibemacs--start-verification-command (command &optional queue root)
  "Start verification COMMAND with optional remaining QUEUE under ROOT."
  (let ((default-directory (or root (vibemacs-project-root))))
    (vibemacs-append-transcript-entry
     command
     (format "started in `%s`" (abbreviate-file-name default-directory)))
    (let ((buffer (compile command)))
      (with-current-buffer buffer
        (setq vibemacs--verification-command command)
        (setq vibemacs--verification-queue queue)
        (setq vibemacs--verification-root default-directory))
      buffer)))

(defun vibemacs--compilation-finished (buffer message)
  "Record Vibemacs verification result for compilation BUFFER and MESSAGE."
  (when-let ((command (buffer-local-value 'vibemacs--verification-command buffer)))
    (let ((status (vibemacs-verification-status message))
          (detail (string-trim message))
          (queue (buffer-local-value 'vibemacs--verification-queue buffer))
          (root (buffer-local-value 'vibemacs--verification-root buffer)))
      (vibemacs-record-verification-result command status detail)
      (vibemacs-append-transcript-entry
       command
       (format "%s: %s" status detail))
      (when vibemacs-save-session-on-verification
        (vibemacs-save-session))
      (vibemacs-refresh-cockpit-if-open)
      (when queue
        (vibemacs--start-verification-command (car queue) (cdr queue) root)))))

(defun vibemacs-cycle-template (title)
  "Return a development cycle note template for TITLE."
  (string-join
   (list
    (format "# %s" title)
    ""
    (format "Date: %s" (vibemacs-today))
    ""
    "## Objective"
    ""
    "## Plan"
    ""
    "- [ ] Inspect current state."
    "- [ ] Make the smallest coherent improvement."
    "- [ ] Verify behavior."
    "- [ ] Publish the cycle journal."
    ""
    "## Evidence"
    ""
    "## Journal Angle"
    "")
   "\n"))

(defun vibemacs-shipping-checklist ()
  "Return a shipping checklist for agentic programming cycles."
  (string-join
   '("- [ ] The implementation serves the real requested end state."
     "- [ ] No unrelated user changes were reverted."
     "- [ ] Tests or checks cover the edited behavior."
     "- [ ] The final response names what changed and what was verified."
     "- [ ] The public journal entry narrates the cycle.")
   "\n"))


(provide 'vibemacs-workflow)

;;; vibemacs-workflow.el ends here
