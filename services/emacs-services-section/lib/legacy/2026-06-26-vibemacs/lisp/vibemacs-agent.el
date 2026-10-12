;;; vibemacs-agent.el --- Agentic programming workflows -*- lexical-binding: t; -*-

;;; Commentary:
;; Commands for prompt packets, transcripts, journal entries, and shipping.

;;; Code:

(require 'subr-x)
(require 'cl-lib)
(require 'compile)
(require 'seq)
(require 'tabulated-list)
(require 'thingatpt)
(require 'vibemacs-core)

(defgroup vibemacs-agent nil
  "Agentic programming affordances for Vibemacs."
  :group 'vibemacs)

(defcustom vibemacs-agent-default-constraints
  '("Read the current code before editing."
    "Prefer existing project conventions over new abstractions."
    "Run the narrowest meaningful verification before handing work back."
    "Write a public development journal entry at the end of the cycle.")
  "Default constraints inserted into prompt packets."
  :type '(repeat string)
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-verification-commands
  '("npm test"
    "npm run compile"
    "emacs -Q --batch -L lisp -l init.el")
  "Default verification commands included in context packets."
  :type '(repeat string)
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-transcript-buffer-name "*vibemacs-transcript*"
  "Buffer name used for Vibemacs agent transcripts."
  :type 'string
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-cockpit-buffer-name "*vibemacs*"
  "Buffer name used for the Vibemacs cockpit."
  :type 'string
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-task-board-buffer-name "*vibemacs-tasks*"
  "Buffer name used for the Vibemacs task board."
  :type 'string
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-verification-history-limit 8
  "Maximum number of verification results kept in memory."
  :type 'integer
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-session-file "dev/.vibemacs-session.el"
  "Project-relative file used to persist Vibemacs session evidence."
  :type 'string
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-task-directory "dev/tasks"
  "Project-relative directory used for persisted Vibemacs task files."
  :type 'string
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-task-list-limit 8
  "Maximum number of recent task files shown in Vibemacs surfaces."
  :type 'integer
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-artifact-list-limit 12
  "Maximum number of recent artifacts shown in index surfaces."
  :type 'integer
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-source-context-line-limit 160
  "Maximum source lines included in a source context packet."
  :type 'integer
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-change-review-line-limit 260
  "Maximum diff lines included in a change review packet."
  :type 'integer
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-dependency-map-file-limit 12
  "Maximum changed files included in a task dependency map."
  :type 'integer
  :group 'vibemacs-agent)

(defcustom vibemacs-agent-save-session-on-verification t
  "When non-nil, save session evidence after verification finishes."
  :type 'boolean
  :group 'vibemacs-agent)

(defvar vibemacs-agent-verification-history nil
  "Recent verification result plists.
Each entry contains :time, :command, :status, and :detail.")

(defvar-local vibemacs-agent--verification-command nil
  "Verification command associated with a compilation buffer.")

(defvar-local vibemacs-agent--verification-queue nil
  "Remaining verification commands associated with a compilation buffer.")

(defvar-local vibemacs-agent--verification-root nil
  "Project root associated with a verification compilation buffer.")

(defvar-local vibemacs-agent-task-mode--previous-header-line-format nil
  "Header line value restored when `vibemacs-agent-task-mode' is disabled.")

(defconst vibemacs-agent-task-checkbox-regexp "^\\s-*[-*] \\[\\([ xX]\\)\\] "
  "Regexp matching a Markdown task checkbox line.")

(defvar vibemacs-agent-cockpit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'vibemacs-agent-open-cockpit)
    (define-key map (kbd "A") #'vibemacs-agent-open-current-task-next-actions)
    (define-key map (kbd "L") #'vibemacs-agent-insert-current-task-next-actions)
    (define-key map (kbd "p") #'vibemacs-agent-open-prompt-packet)
    (define-key map (kbd "P") #'vibemacs-agent-open-current-task-prompt)
    (define-key map (kbd "X") #'vibemacs-agent-insert-current-task-prompt)
    (define-key map (kbd "t") #'vibemacs-agent-open-transcript)
    (define-key map (kbd "T") #'vibemacs-agent-open-current-task-review)
    (define-key map (kbd "x") #'vibemacs-agent-open-context-packet)
    (define-key map (kbd "i") #'vibemacs-agent-open-artifact-index)
    (define-key map (kbd "f") #'vibemacs-agent-open-source-context)
    (define-key map (kbd "F") #'vibemacs-agent-open-current-task-final-response)
    (define-key map (kbd "I") #'vibemacs-agent-insert-current-task-final-response)
    (define-key map (kbd "S") #'vibemacs-agent-open-current-task-scope-audit)
    (define-key map (kbd "O") #'vibemacs-agent-insert-current-task-scope-audit)
    (define-key map (kbd "K") #'vibemacs-agent-open-current-task-risk-register)
    (define-key map (kbd "U") #'vibemacs-agent-insert-current-task-risk-register)
    (define-key map (kbd "M") #'vibemacs-agent-open-current-task-dependency-map)
    (define-key map (kbd "B") #'vibemacs-agent-insert-current-task-dependency-map)
    (define-key map (kbd "Q") #'vibemacs-agent-insert-task-review-checklist)
    (define-key map (kbd "d") #'vibemacs-agent-open-change-review)
    (define-key map (kbd "G") #'vibemacs-agent-open-current-task-verification-plan)
    (define-key map (kbd "N") #'vibemacs-agent-insert-current-task-verification-plan)
    (define-key map (kbd "v") #'vibemacs-agent-run-verification)
    (define-key map (kbd "V") #'vibemacs-agent-run-verification-suite)
    (define-key map (kbd "c") #'vibemacs-agent-start-cycle)
    (define-key map (kbd "j") #'vibemacs-agent-open-journal-entry)
    (define-key map (kbd "J") #'vibemacs-agent-open-task-journal-entry)
    (define-key map (kbd "s") #'vibemacs-agent-insert-shipping-checklist)
    (define-key map (kbd "w") #'vibemacs-agent-save-session)
    (define-key map (kbd "l") #'vibemacs-agent-load-session)
    (define-key map (kbd "y") #'vibemacs-agent-copy-handoff-bundle)
    (define-key map (kbd "H") #'vibemacs-agent-insert-current-task-handoff)
    (define-key map (kbd "a") #'vibemacs-agent-open-task)
    (define-key map (kbd "b") #'vibemacs-agent-open-task-board)
    (define-key map (kbd "r") #'vibemacs-agent-open-recent-task)
    (define-key map (kbd "e") #'vibemacs-agent-insert-latest-verification-evidence)
    (define-key map (kbd "E") #'vibemacs-agent-insert-verification-history-snapshot)
    (define-key map (kbd "k") #'vibemacs-agent-insert-task-checkpoint)
    (define-key map (kbd "h") #'vibemacs-agent-copy-current-task-handoff)
    (define-key map (kbd "D") #'vibemacs-agent-insert-task-decision)
    (define-key map (kbd "n") #'vibemacs-agent-next-task-checkbox)
    (define-key map (kbd "m") #'vibemacs-agent-toggle-task-checkbox)
    (define-key map (kbd "R") #'vibemacs-agent-open-task-readiness)
    (define-key map (kbd "W") #'vibemacs-agent-insert-task-readiness)
    (define-key map (kbd "o") #'vibemacs-agent-insert-task-closeout)
    map)
  "Keymap for `vibemacs-agent-cockpit-mode'.")

(define-derived-mode vibemacs-agent-cockpit-mode special-mode "Vibemacs"
  "Major mode for the Vibemacs agentic programming cockpit.")

(defvar vibemacs-agent-task-board-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "RET") #'vibemacs-agent-task-board-open-task)
    (define-key map (kbd "g") #'vibemacs-agent-refresh-task-board)
    map)
  "Keymap for `vibemacs-agent-task-board-mode'.")

(defvar-local vibemacs-agent-task-board-root nil
  "Project root displayed by the current Vibemacs task board.")

(define-derived-mode vibemacs-agent-task-board-mode tabulated-list-mode "VTasks"
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

(defvar vibemacs-agent-task-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'vibemacs-agent-dispatch-task-action)
    (define-key map (kbd "C-c C-n") #'vibemacs-agent-next-task-checkbox)
    (define-key map (kbd "C-c C-m") #'vibemacs-agent-toggle-task-checkbox)
    (define-key map (kbd "C-c C-a") #'vibemacs-agent-open-current-task-next-actions)
    (define-key map (kbd "C-c ,") #'vibemacs-agent-insert-current-task-next-actions)
    (define-key map (kbd "C-c C-e") #'vibemacs-agent-insert-latest-verification-evidence)
    (define-key map (kbd "C-c C-E") #'vibemacs-agent-insert-verification-history-snapshot)
    (define-key map (kbd "C-c C-k") #'vibemacs-agent-insert-task-checkpoint)
    (define-key map (kbd "C-c C-d") #'vibemacs-agent-insert-task-decision)
    (define-key map (kbd "C-c C-f") #'vibemacs-agent-open-current-task-final-response)
    (define-key map (kbd "C-c C-i") #'vibemacs-agent-insert-current-task-final-response)
    (define-key map (kbd "C-c C-g") #'vibemacs-agent-open-current-task-verification-plan)
    (define-key map (kbd "C-c ;") #'vibemacs-agent-insert-current-task-verification-plan)
    (define-key map (kbd "C-c C-p") #'vibemacs-agent-open-current-task-prompt)
    (define-key map (kbd "C-c .") #'vibemacs-agent-insert-current-task-prompt)
    (define-key map (kbd "C-c C-h") #'vibemacs-agent-copy-current-task-handoff)
    (define-key map (kbd "C-c C-y") #'vibemacs-agent-insert-current-task-handoff)
    (define-key map (kbd "C-c C-v") #'vibemacs-agent-open-current-task-review)
    (define-key map (kbd "C-c C-u") #'vibemacs-agent-open-current-task-scope-audit)
    (define-key map (kbd "C-c C-z") #'vibemacs-agent-insert-current-task-scope-audit)
    (define-key map (kbd "C-c C-l") #'vibemacs-agent-open-current-task-risk-register)
    (define-key map (kbd "C-c C-x") #'vibemacs-agent-insert-current-task-risk-register)
    (define-key map (kbd "C-c C-b") #'vibemacs-agent-open-current-task-dependency-map)
    (define-key map (kbd "C-c C-t") #'vibemacs-agent-insert-current-task-dependency-map)
    (define-key map (kbd "C-c C-q") #'vibemacs-agent-insert-task-review-checklist)
    (define-key map (kbd "C-c C-s") #'vibemacs-agent-refresh-task-status)
    (define-key map (kbd "C-c C-r") #'vibemacs-agent-open-task-readiness)
    (define-key map (kbd "C-c C-w") #'vibemacs-agent-insert-task-readiness)
    (define-key map (kbd "C-c C-o") #'vibemacs-agent-insert-task-closeout)
    (define-key map (kbd "C-c C-j") #'vibemacs-agent-open-task-journal-entry)
    map)
  "Keymap for `vibemacs-agent-task-mode'.")

(define-minor-mode vibemacs-agent-task-mode
  "Minor mode for persisted Vibemacs task files."
  :lighter " VTask"
  :keymap vibemacs-agent-task-mode-map
  (if vibemacs-agent-task-mode
      (progn
        (setq vibemacs-agent-task-mode--previous-header-line-format header-line-format)
        (vibemacs-agent-refresh-task-status))
    (setq header-line-format vibemacs-agent-task-mode--previous-header-line-format)))

(defun vibemacs-agent-prompt-template (&optional title)
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
      (mapcar (lambda (item) (concat "- " item)) vibemacs-agent-default-constraints)
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

(defun vibemacs-agent-transcript-template ()
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

(defun vibemacs-agent--markdown-table-cell (value)
  "Escape VALUE for use inside a Markdown table cell."
  (string-replace "|" "\\|" (string-trim (format "%s" value))))

(defun vibemacs-agent-transcript-row (command evidence &optional time)
  "Return a transcript row for COMMAND with EVIDENCE.
Optional TIME supplies the displayed timestamp."
  (format "| %s | `%s` | %s |"
          (vibemacs-agent--markdown-table-cell
           (or time (format-time-string "%H:%M")))
          (vibemacs-agent--markdown-table-cell command)
          (vibemacs-agent--markdown-table-cell evidence)))

(defun vibemacs-agent-append-transcript-entry (command evidence &optional time buffer)
  "Append a transcript entry for COMMAND and EVIDENCE.
Optional TIME overrides the timestamp.  Optional BUFFER receives the entry."
  (let ((target (get-buffer-create (or buffer vibemacs-agent-transcript-buffer-name))))
    (with-current-buffer target
      (unless (derived-mode-p 'text-mode 'markdown-mode)
        (vibemacs-markdown-mode))
      (when (= (buffer-size) 0)
        (insert (vibemacs-agent-transcript-template)))
      (save-excursion
        (goto-char (point-min))
        (if (search-forward "| --- | --- | --- |" nil t)
            (progn
              (end-of-line)
              (insert "\n" (vibemacs-agent-transcript-row command evidence time)))
          (goto-char (point-max))
          (unless (bolp)
            (insert "\n"))
          (insert "\n## Commands\n\n| Time | Action | Evidence |\n| --- | --- | --- |\n"
                  (vibemacs-agent-transcript-row command evidence time)))))
    target))

(defun vibemacs-agent-verification-status (message)
  "Return a symbolic verification status from compilation MESSAGE."
  (if (string-match-p "\\bfinished\\b" message)
      "passed"
    "failed"))

(defun vibemacs-agent-record-verification-result (command status detail &optional time)
  "Record verification COMMAND with STATUS, DETAIL, and optional TIME."
  (let ((entry (list :time (or time (format-time-string "%H:%M"))
                     :command command
                     :status status
                     :detail (string-trim detail))))
    (setq vibemacs-agent-verification-history
          (seq-take (cons entry vibemacs-agent-verification-history)
                    vibemacs-agent-verification-history-limit))
    entry))

(defun vibemacs-agent-session-path (&optional root)
  "Return the Vibemacs session path for ROOT or the current project."
  (expand-file-name vibemacs-agent-session-file
                    (file-name-as-directory (or root (vibemacs-project-root)))))

(defun vibemacs-agent-task-path (title &optional root)
  "Return a project-local task file path for TITLE under ROOT."
  (expand-file-name
   (format "%s-%s.md" (vibemacs-today) (vibemacs-slugify title))
   (expand-file-name vibemacs-agent-task-directory
                     (file-name-as-directory (or root (vibemacs-project-root))))))

(defun vibemacs-agent-project-files (directory regexp &optional root limit)
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

(defun vibemacs-agent-task-files (&optional root)
  "Return project-relative task files for ROOT, newest filename first."
  (vibemacs-agent-project-files vibemacs-agent-task-directory "\\.md\\'" root))

(defun vibemacs-agent-recent-task-files (&optional root)
  "Return recent project-relative task files for ROOT."
  (seq-take (vibemacs-agent-task-files root) vibemacs-agent-task-list-limit))

(defun vibemacs-agent-task-file-p (&optional file root)
  "Return non-nil when FILE is a Vibemacs task file under ROOT."
  (when-let ((source (or file buffer-file-name)))
    (let* ((project-root (file-name-as-directory (or root (vibemacs-project-root))))
           (task-root (file-name-as-directory
                       (expand-file-name vibemacs-agent-task-directory project-root)))
           (target (expand-file-name source)))
      (and (string-prefix-p task-root target)
           (string-suffix-p ".md" target)))))

(defun vibemacs-agent-task-checkbox-progress ()
  "Return checkbox progress for the current buffer as a plist."
  (let ((complete 0)
        (total 0))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward vibemacs-agent-task-checkbox-regexp nil t)
        (setq total (1+ total))
        (when (member (match-string 1) '("x" "X"))
          (setq complete (1+ complete)))))
    (list :complete complete :total total)))

(defun vibemacs-agent-task-checkbox-items (&optional state)
  "Return Markdown checkbox item text from the current buffer.
When STATE is `complete', return checked items.  When STATE is
`open', return unchecked items.  Any other value returns all checkbox
items."
  (let (items)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward vibemacs-agent-task-checkbox-regexp nil t)
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

(defun vibemacs-agent-task-status-text ()
  "Return a compact status string for the current task buffer."
  (let* ((progress (vibemacs-agent-task-checkbox-progress))
         (latest (vibemacs-agent-latest-verification-result))
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

(defun vibemacs-agent-refresh-task-status ()
  "Refresh the task header status in the current task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (setq header-line-format '(:eval (vibemacs-agent-task-status-text)))
  (force-mode-line-update)
  (when (called-interactively-p 'interactive)
    (message "%s" (vibemacs-agent-task-status-text)))
  header-line-format)

(defun vibemacs-agent-task-section-content (heading)
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

(defun vibemacs-agent-task-section-present-p (heading)
  "Return non-nil when Markdown section HEADING is present."
  (not (null (vibemacs-agent-task-section-content heading))))

(defun vibemacs-agent-task-section-has-content-p (heading)
  "Return non-nil when Markdown section HEADING has non-placeholder content."
  (when-let ((content (vibemacs-agent-task-section-content heading)))
    (seq-some
     (lambda (line)
       (let ((trimmed (string-trim line)))
         (and (not (string-empty-p trimmed))
              (not (member trimmed '("-" "- ")))
              (not (string-prefix-p "```" trimmed)))))
     (split-string content "\n"))))

(defun vibemacs-agent--task-title-in-buffer (&optional fallback)
  "Return the task title in the current buffer.
FALLBACK is used when no Markdown title is present."
  (save-excursion
    (goto-char (point-min))
    (let ((title (if (re-search-forward "^# +\\(.+\\)$" nil t)
                     (string-trim (match-string 1))
                   fallback)))
      (string-remove-prefix "Vibemacs Task: " (or title "")))))

(defun vibemacs-agent--task-heading-in-buffer (&optional fallback)
  "Return the raw Markdown task heading in the current buffer.
FALLBACK is used when no Markdown title is present."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^# +\\(.+\\)$" nil t)
        (string-trim (match-string 1))
      fallback)))

(defun vibemacs-agent-task-readiness-progress ()
  "Return readiness progress for the current task buffer as a plist."
  (let* ((progress (vibemacs-agent-task-checkbox-progress))
         (complete (plist-get progress :complete))
         (total (plist-get progress :total))
         (checks (list
                  (vibemacs-agent-task-section-has-content-p "Goal")
                  (> total 0)
                  (and (> total 0) (= complete total))
                  (vibemacs-agent-task-section-has-content-p "Verification Evidence")
                  (vibemacs-agent-task-section-has-content-p "Checkpoints")
                  (vibemacs-agent-task-section-present-p "Agent Handoff Bundle"))))
    (list :complete (cl-count-if #'identity checks)
          :total (length checks))))

(defun vibemacs-agent-task-record (file &optional root)
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
        (setq title (vibemacs-agent--task-title-in-buffer file))
        (setq progress (vibemacs-agent-task-checkbox-progress))
        (setq readiness (vibemacs-agent-task-readiness-progress))
        (setq open-count (length (vibemacs-agent-task-checkbox-items 'open)))))
    (list :file file
          :title title
          :complete (plist-get progress :complete)
          :total (plist-get progress :total)
          :open open-count
          :readiness-complete (plist-get readiness :complete)
          :readiness-total (plist-get readiness :total))))

(defun vibemacs-agent-task-board-entries (&optional root)
  "Return `tabulated-list-entries' rows for persisted tasks under ROOT."
  (let ((project-root (file-name-as-directory (or root (vibemacs-project-root)))))
    (mapcar
     (lambda (file)
       (let* ((record (vibemacs-agent-task-record file project-root))
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
     (vibemacs-agent-task-files project-root))))

(defun vibemacs-agent-append-task-section-entry (heading entry)
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

(defun vibemacs-agent--readiness-line (ready label detail)
  "Render a readiness line for READY LABEL and DETAIL."
  (format "- [%s] %s%s"
          (if ready "x" " ")
          label
          (if (and detail (not (string-empty-p detail)))
              (concat " - " detail)
            "")))

(defun vibemacs-agent-render-task-readiness (&optional task-file)
  "Render a Markdown readiness report for the current task buffer.
Optional TASK-FILE supplies the displayed project-relative path."
  (let* ((progress (vibemacs-agent-task-checkbox-progress))
         (complete (plist-get progress :complete))
         (total (plist-get progress :total))
         (checks-complete (and (> total 0) (= complete total)))
         (latest (vibemacs-agent-latest-verification-result))
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
      (vibemacs-agent--readiness-line
       (vibemacs-agent-task-section-has-content-p "Goal")
       "Goal has task-specific content."
       nil)
      (vibemacs-agent--readiness-line
       (> total 0)
       "Acceptance checks exist."
       (format "%d checks" total))
      (vibemacs-agent--readiness-line
       checks-complete
       "Acceptance checks are complete."
       (format "%d/%d complete" complete total))
      (vibemacs-agent--readiness-line
       (vibemacs-agent-task-section-has-content-p "Verification Evidence")
       "Verification evidence is recorded in the task."
       nil)
      (vibemacs-agent--readiness-line
       (vibemacs-agent-task-section-has-content-p "Checkpoints")
       "At least one checkpoint is recorded."
       nil)
      (vibemacs-agent--readiness-line
       (vibemacs-agent-task-section-has-content-p "Decisions")
       "At least one decision is recorded."
       nil)
      (vibemacs-agent--readiness-line
       (vibemacs-agent-task-section-present-p "Agent Handoff Bundle")
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

(defun vibemacs-agent-render-task-readiness-snapshot (&optional time)
  "Render a timestamped readiness snapshot for task insertion.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Readiness" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-agent-render-task-readiness))
   "\n"))

(defun vibemacs-agent-render-task-closeout (&optional time)
  "Render a timestamped task closeout summary.
Optional TIME supplies the displayed timestamp."
  (let* ((progress (vibemacs-agent-task-checkbox-progress))
         (complete (plist-get progress :complete))
         (total (plist-get progress :total))
         (open-items (vibemacs-agent-task-checkbox-items 'open))
         (latest (vibemacs-agent-latest-verification-result)))
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

(defun vibemacs-agent-render-task-review-checklist (&optional time)
  "Render a timestamped review checklist for task insertion.
Optional TIME supplies the displayed timestamp."
  (let* ((progress (vibemacs-agent-task-checkbox-progress))
         (complete (plist-get progress :complete))
         (total (plist-get progress :total))
         (open-items (vibemacs-agent-task-checkbox-items 'open))
         (latest (vibemacs-agent-latest-verification-result)))
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

(defun vibemacs-agent-task-summary (file &optional root)
  "Return a human-readable summary for task FILE under ROOT."
  (let* ((record (vibemacs-agent-task-record file root))
         (project-root (file-name-as-directory (or root (vibemacs-project-root))))
         (absolute-file (expand-file-name file project-root))
         (title (if (file-readable-p absolute-file)
                    (with-temp-buffer
                      (insert-file-contents absolute-file)
                      (vibemacs-agent--task-heading-in-buffer (plist-get record :title)))
                  (plist-get record :title))))
    (format "%s - %s - %d/%d checks complete"
            file
            title
            (plist-get record :complete)
            (plist-get record :total))))

(defun vibemacs-agent-task-summaries (&optional root)
  "Return summaries for recent task files under ROOT."
  (let ((project-root (file-name-as-directory (or root (vibemacs-project-root)))))
    (mapcar (lambda (file) (vibemacs-agent-task-summary file project-root))
            (vibemacs-agent-recent-task-files project-root))))

(defun vibemacs-agent-current-task-text ()
  "Return the current task buffer as text."
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (buffer-substring-no-properties (point-min) (point-max)))

(defun vibemacs-agent-current-task-title ()
  "Return the title of the current persisted task file."
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (vibemacs-agent--task-title-in-buffer (file-name-base buffer-file-name)))

(defun vibemacs-agent-maybe-enable-task-mode ()
  "Enable `vibemacs-agent-task-mode' in persisted task files."
  (when (vibemacs-agent-task-file-p)
    (vibemacs-agent-task-mode 1)))

(defun vibemacs-agent-journal-files (&optional root)
  "Return recent project-relative public journal files under ROOT."
  (vibemacs-agent-project-files
   vibemacs-cycle-directory
   "\\.md\\'"
   root
   vibemacs-agent-artifact-list-limit))

(defun vibemacs-agent-note-files (&optional root)
  "Return recent project-relative local note files under ROOT."
  (vibemacs-agent-project-files
   vibemacs-notes-directory
   "\\.md\\'"
   root
   vibemacs-agent-artifact-list-limit))

(defun vibemacs-agent--valid-verification-entry-p (entry)
  "Return non-nil when ENTRY is a valid verification history plist."
  (and (listp entry)
       (stringp (plist-get entry :time))
       (stringp (plist-get entry :command))
       (stringp (plist-get entry :status))
       (stringp (plist-get entry :detail))))

(defun vibemacs-agent-session-data ()
  "Return serializable Vibemacs session data."
  (list :version 1
        :verification-history vibemacs-agent-verification-history))

(defun vibemacs-agent-save-session (&optional file)
  "Save Vibemacs session evidence to FILE.
When FILE is nil, use `vibemacs-agent-session-path'."
  (interactive)
  (let ((target (or file (vibemacs-agent-session-path))))
    (vibemacs-ensure-directory (file-name-directory target))
    (with-temp-file target
      (insert ";;; Vibemacs session evidence -*- mode: emacs-lisp; lexical-binding: t; -*-\n")
      (let ((print-length nil)
            (print-level nil))
        (prin1 (vibemacs-agent-session-data) (current-buffer)))
      (insert "\n"))
    (when (called-interactively-p 'interactive)
      (message "Saved Vibemacs session to %s" (abbreviate-file-name target)))
    target))

(defun vibemacs-agent-read-session-file (file)
  "Read Vibemacs session data from FILE."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (condition-case nil
          (read (current-buffer))
        (error nil)))))

(defun vibemacs-agent-load-session (&optional file)
  "Load Vibemacs session evidence from FILE.
When FILE is nil, use `vibemacs-agent-session-path'."
  (interactive)
  (let* ((source (or file (vibemacs-agent-session-path)))
         (data (vibemacs-agent-read-session-file source))
         (history (plist-get data :verification-history)))
    (when (listp history)
      (setq vibemacs-agent-verification-history
            (seq-take (seq-filter #'vibemacs-agent--valid-verification-entry-p history)
                      vibemacs-agent-verification-history-limit)))
    (when (called-interactively-p 'interactive)
      (message "Loaded %d Vibemacs verification results from %s"
               (length vibemacs-agent-verification-history)
               (abbreviate-file-name source)))
    vibemacs-agent-verification-history))

(defun vibemacs-agent-render-verification-history (history)
  "Render verification HISTORY as cockpit text."
  (if history
      (string-join
       (mapcar
        #'vibemacs-agent-render-verification-entry
        history)
       "\n")
    "No verification results recorded yet."))

(defun vibemacs-agent-render-verification-history-snapshot (&optional time history)
  "Render a timestamped verification HISTORY snapshot.
Optional TIME supplies the displayed timestamp.  HISTORY defaults to
`vibemacs-agent-verification-history'."
  (string-join
   (list
    (format "### %s Verification Snapshot" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-agent-render-verification-history
     (or history vibemacs-agent-verification-history)))
   "\n"))

(defun vibemacs-agent-latest-verification-result ()
  "Return the newest recorded verification result."
  (car vibemacs-agent-verification-history))

(defun vibemacs-agent-render-verification-entry (entry)
  "Render one verification ENTRY as a Markdown bullet."
  (format "- %s %s `%s` - %s"
          (plist-get entry :time)
          (plist-get entry :status)
          (plist-get entry :command)
          (plist-get entry :detail)))

(defun vibemacs-agent-refresh-cockpit-if-open ()
  "Refresh the cockpit buffer when it already exists."
  (when (get-buffer vibemacs-agent-cockpit-buffer-name)
    (vibemacs-agent-open-cockpit)))

(defun vibemacs-agent-verification-suite-plan (&optional commands)
  "Return normalized verification COMMANDS for a suite run."
  (seq-filter
   (lambda (command)
     (and (stringp command)
          (not (string-empty-p (string-trim command)))))
   (or commands vibemacs-agent-verification-commands)))

(defun vibemacs-agent--start-verification-command (command &optional queue root)
  "Start verification COMMAND with optional remaining QUEUE under ROOT."
  (let ((default-directory (or root (vibemacs-project-root))))
    (vibemacs-agent-append-transcript-entry
     command
     (format "started in `%s`" (abbreviate-file-name default-directory)))
    (let ((buffer (compile command)))
      (with-current-buffer buffer
        (setq vibemacs-agent--verification-command command)
        (setq vibemacs-agent--verification-queue queue)
        (setq vibemacs-agent--verification-root default-directory))
      buffer)))

(defun vibemacs-agent--compilation-finished (buffer message)
  "Record Vibemacs verification result for compilation BUFFER and MESSAGE."
  (when-let ((command (buffer-local-value 'vibemacs-agent--verification-command buffer)))
    (let ((status (vibemacs-agent-verification-status message))
          (detail (string-trim message))
          (queue (buffer-local-value 'vibemacs-agent--verification-queue buffer))
          (root (buffer-local-value 'vibemacs-agent--verification-root buffer)))
      (vibemacs-agent-record-verification-result command status detail)
      (vibemacs-agent-append-transcript-entry
       command
       (format "%s: %s" status detail))
      (when vibemacs-agent-save-session-on-verification
        (vibemacs-agent-save-session))
      (vibemacs-agent-refresh-cockpit-if-open)
      (when queue
        (vibemacs-agent--start-verification-command (car queue) (cdr queue) root)))))

(defun vibemacs-agent-cycle-template (title)
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

(defun vibemacs-agent-shipping-checklist ()
  "Return a shipping checklist for agentic programming cycles."
  (string-join
   '("- [ ] The implementation serves the real requested end state."
     "- [ ] No unrelated user changes were reverted."
     "- [ ] Tests or checks cover the edited behavior."
     "- [ ] The final response names what changed and what was verified."
     "- [ ] The public journal entry narrates the cycle.")
   "\n"))

(defun vibemacs-agent--process-lines (program &rest args)
  "Return trimmed output lines from PROGRAM called with ARGS.
Return nil when PROGRAM is missing or exits unsuccessfully."
  (when (executable-find program)
    (with-temp-buffer
      (when (= 0 (apply #'call-process program nil t nil args))
        (split-string (string-trim (buffer-string)) "\n" t)))))

(defun vibemacs-agent--process-output (program &rest args)
  "Return trimmed output from PROGRAM called with ARGS.
Return nil when PROGRAM is missing or exits unsuccessfully."
  (when (executable-find program)
    (with-temp-buffer
      (when (= 0 (apply #'call-process program nil t nil args))
        (string-trim-right (buffer-string))))))

(defun vibemacs-agent-git-branch (&optional root)
  "Return the Git branch for ROOT, or nil outside Git."
  (let ((default-directory (or root (vibemacs-project-root))))
    (car (vibemacs-agent--process-lines "git" "branch" "--show-current"))))

(defun vibemacs-agent-git-changed-files (&optional root)
  "Return changed Git files for ROOT as status-prefixed strings."
  (let ((default-directory (or root (vibemacs-project-root))))
    (vibemacs-agent--process-lines "git" "status" "--short")))

(defun vibemacs-agent-git-diff-stat (&optional root)
  "Return Git diff stat lines for ROOT."
  (let ((default-directory (or root (vibemacs-project-root))))
    (when-let ((output (vibemacs-agent--process-output
                        "git" "diff" "--stat" "HEAD" "--")))
      (split-string output "\n" t))))

(defun vibemacs-agent-git-diff-lines (&optional root)
  "Return Git diff lines for ROOT."
  (let ((default-directory (or root (vibemacs-project-root))))
    (when-let ((output (vibemacs-agent--process-output
                        "git" "diff" "--no-ext-diff" "--unified=3" "HEAD" "--")))
      (split-string output "\n"))))

(defun vibemacs-agent-git-status-file (status-line)
  "Return the file path from a Git porcelain STATUS-LINE."
  (let* ((trimmed (string-trim-left status-line))
         (path (cond
                ((string-match "\\`.. \\(.+\\)\\'" status-line)
                 (match-string 1 status-line))
                ((string-match "\\`[ A-Z?!][ A-Z?!]?[ \t]+\\(.+\\)\\'"
                               trimmed)
                 (match-string 1 trimmed))
                (t
                 status-line))))
    (if (string-match " -> \\(.+\\)\\'" path)
        (match-string 1 path)
      path)))

(defun vibemacs-agent-changed-file-paths (changed-files)
  "Return project-relative paths parsed from CHANGED-FILES status lines."
  (seq-take
   (delq nil
         (mapcar
          (lambda (line)
            (let ((path (string-trim
                         (vibemacs-agent-git-status-file line))))
              (unless (string-empty-p path)
                path)))
          changed-files))
   vibemacs-agent-dependency-map-file-limit))

(defun vibemacs-agent-source-dependencies (file)
  "Return source dependency strings detected in FILE."
  (let ((extension (downcase (or (file-name-extension file) "")))
        (dependencies nil))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (pcase extension
          ("el"
          (goto-char (point-min))
          (while (re-search-forward
                  "(\\s-*require\\s-+'\\([^][() \t\n]+\\)" nil t)
            (push (match-string 1) dependencies))
          (goto-char (point-min))
          (while (re-search-forward
                  "(\\s-*load\\s-+\"\\([^\"]+\\)\"" nil t)
            (push (match-string 1) dependencies)))
         ((or "js" "mjs" "cjs" "ts" "tsx" "jsx")
          (dolist (line (split-string (buffer-string) "\n"))
            (cond
             ((string-match
               "^[ \t]*import[ \t].*from[ \t]+['\"]\\([^'\"]+\\)['\"]"
               line)
              (push (match-string 1 line) dependencies))
             ((string-match
               "^[ \t]*import[ \t]+['\"]\\([^'\"]+\\)['\"]"
               line)
              (push (match-string 1 line) dependencies))
             ((string-match
               "require[ \t]*(?[ \t]*['\"]\\([^'\"]+\\)['\"]"
               line)
              (push (match-string 1 line) dependencies))))))))
    (delete-dups (nreverse dependencies))))

(defun vibemacs-agent-changed-file-dependency-map (root changed-files)
  "Return dependency entries for CHANGED-FILES under ROOT."
  (mapcar
   (lambda (path)
     (let ((file (expand-file-name path root)))
       (list :file path
             :readable (file-readable-p file)
             :dependencies (vibemacs-agent-source-dependencies file))))
   (vibemacs-agent-changed-file-paths changed-files)))

(defun vibemacs-agent-render-dependency-map (entries)
  "Render dependency map ENTRIES as Markdown bullets."
  (if entries
      (string-join
       (mapcar
        (lambda (entry)
          (let ((file (plist-get entry :file))
                (readable (plist-get entry :readable))
                (dependencies (plist-get entry :dependencies)))
            (cond
             ((not readable)
              (format "- `%s`: file is not readable in the working tree." file))
             (dependencies
              (format "- `%s`: %s"
                      file
                      (string-join
                       (mapcar (lambda (dependency)
                                 (format "`%s`" dependency))
                               dependencies)
                       ", ")))
             (t
              (format "- `%s`: no source dependencies detected." file)))))
        entries)
       "\n")
    "- No changed files available for dependency mapping."))

(defun vibemacs-agent-open-file-buffers (&optional root)
  "Return project-relative open file buffers under ROOT."
  (let ((project-root (file-name-as-directory (or root (vibemacs-project-root)))))
    (sort
     (delq nil
           (mapcar
            (lambda (buffer)
              (with-current-buffer buffer
                (when (and buffer-file-name
                           (file-in-directory-p buffer-file-name project-root))
                  (file-relative-name buffer-file-name project-root))))
            (buffer-list)))
     #'string<)))

(defun vibemacs-agent--files-in-directory (root directory regexp)
  "Return files under ROOT/DIRECTORY matching REGEXP."
  (let ((target (expand-file-name directory root)))
    (if (file-directory-p target)
        (directory-files-recursively target regexp)
      '())))

(defun vibemacs-agent--count-file-matches (files regexp)
  "Return the number of REGEXP matches across FILES."
  (let ((count 0))
    (dolist (file files count)
      (when (file-readable-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (while (re-search-forward regexp nil t)
            (setq count (1+ count))))))))

(defun vibemacs-agent--present-files (root files)
  "Return FILES that exist under ROOT."
  (seq-filter (lambda (file) (file-exists-p (expand-file-name file root))) files))

(defun vibemacs-agent-project-diagnostics (&optional root)
  "Return human-readable project diagnostics for ROOT."
  (let* ((project-root (file-name-as-directory (or root (vibemacs-project-root))))
         (entrypoints (vibemacs-agent--present-files
                       project-root
                       '("early-init.el" "init.el" "README.md" "package.json")))
         (lisp-files (vibemacs-agent--files-in-directory project-root "lisp" "\\.el\\'"))
         (test-files (vibemacs-agent--files-in-directory project-root "test" "\\.el\\'"))
         (journal-files (vibemacs-agent--files-in-directory
                         project-root "dev/docs/journal" "\\.md\\'"))
         (task-files (vibemacs-agent-task-files project-root))
         (ert-count (vibemacs-agent--count-file-matches test-files "^(ert-deftest\\_>")))
    (list
     (format "Entrypoints present: %s"
             (if entrypoints (string-join entrypoints ", ") "none"))
     (format "Emacs Lisp modules: %d under lisp/" (length lisp-files))
     (format "ERT coverage: %d tests across %d files" ert-count (length test-files))
     (format "Public journal entries: %d under dev/docs/journal/" (length journal-files))
     (format "Task files: %d under %s/" (length task-files) vibemacs-agent-task-directory)
     (format "Package metadata: %s"
             (if (file-exists-p (expand-file-name "package.json" project-root))
                 "package.json present"
               "package.json missing")))))

(defun vibemacs-agent-project-snapshot (&optional title)
  "Return an alist describing the current project for an agent packet.
Optional TITLE becomes the packet title."
  (let ((root (vibemacs-project-root)))
    `((title . ,(or title "Agent Context"))
      (root . ,root)
      (branch . ,(or (vibemacs-agent-git-branch root) "(none)"))
      (changed-files . ,(or (vibemacs-agent-git-changed-files root) '()))
      (open-files . ,(or (vibemacs-agent-open-file-buffers root) '()))
      (task-files . ,(vibemacs-agent-recent-task-files root))
      (task-summaries . ,(vibemacs-agent-task-summaries root))
      (journal-files . ,(vibemacs-agent-journal-files root))
      (note-files . ,(vibemacs-agent-note-files root))
      (diagnostics . ,(vibemacs-agent-project-diagnostics root))
      (verification . ,vibemacs-agent-verification-commands)
      (verification-history . ,vibemacs-agent-verification-history)
      (session-file . ,(vibemacs-agent-session-path root)))))

(defun vibemacs-agent-artifact-snapshot (&optional title)
  "Return an alist describing Vibemacs artifacts for TITLE."
  (let ((snapshot (vibemacs-agent-project-snapshot (or title "Artifact Index"))))
    `((title . ,(alist-get 'title snapshot))
      (root . ,(alist-get 'root snapshot))
      (branch . ,(alist-get 'branch snapshot))
      (session-file . ,(alist-get 'session-file snapshot))
      (session-present . ,(file-exists-p (alist-get 'session-file snapshot)))
      (changed-files . ,(alist-get 'changed-files snapshot))
      (open-files . ,(alist-get 'open-files snapshot))
      (task-files . ,(alist-get 'task-files snapshot))
      (task-summaries . ,(alist-get 'task-summaries snapshot))
      (journal-files . ,(alist-get 'journal-files snapshot))
      (note-files . ,(alist-get 'note-files snapshot))
      (verification-history . ,(alist-get 'verification-history snapshot)))))

(defun vibemacs-agent--markdown-list (items &optional empty-label)
  "Render ITEMS as a Markdown list.
Use EMPTY-LABEL when ITEMS is nil."
  (if items
      (string-join (mapcar (lambda (item) (concat "- `" item "`")) items) "\n")
    (concat "- " (or empty-label "(none)"))))

(defun vibemacs-agent--limit-lines (lines limit)
  "Return a plist containing LINES truncated to LIMIT."
  (let* ((items (or lines '()))
         (kept (seq-take items limit)))
    (list :lines kept
          :line-count (length items)
          :included-lines (length kept)
          :omitted-lines (max 0 (- (length items) (length kept))))))

(defun vibemacs-agent-source-language (file)
  "Return a Markdown fence language for FILE."
  (pcase (downcase (or (file-name-extension (or file "")) ""))
    ("el" "elisp")
    ("js" "javascript")
    ("mjs" "javascript")
    ("cjs" "javascript")
    ("ts" "typescript")
    ("tsx" "tsx")
    ("jsx" "jsx")
    ("json" "json")
    ("md" "markdown")
    ("css" "css")
    ("html" "html")
    ("py" "python")
    ("rs" "rust")
    ("sh" "sh")
    ("bash" "bash")
    ("toml" "toml")
    ("yaml" "yaml")
    ("yml" "yaml")
    (_ "")))

(defun vibemacs-agent-source-file-label (&optional file root)
  "Return a project-relative label for FILE under ROOT."
  (let* ((source (or file buffer-file-name))
         (project-root (file-name-as-directory (or root (vibemacs-project-root)))))
    (cond
     ((and source (file-in-directory-p source project-root))
      (file-relative-name source project-root))
     (source (abbreviate-file-name source))
     (t (buffer-name)))))

(defun vibemacs-agent-source-context-range ()
  "Return a plist describing the current source context range."
  (cond
   ((use-region-p)
    (list :start (region-beginning)
          :end (region-end)
          :scope "active region"))
   ((bounds-of-thing-at-point 'defun)
    (let ((bounds (bounds-of-thing-at-point 'defun)))
      (list :start (car bounds)
            :end (cdr bounds)
            :scope "current definition")))
   (t
    (list :start (line-beginning-position)
          :end (line-end-position)
          :scope "current line"))))

(defun vibemacs-agent-line-numbered-source (start end &optional limit)
  "Return source between START and END with line numbers.
LIMIT restricts the number of included lines."
  (let* ((max-lines (or limit vibemacs-agent-source-context-line-limit))
         (start-line (line-number-at-pos start))
         (text (buffer-substring-no-properties start end))
         (lines (split-string text "\n"))
         (line-count (length lines))
         (included-lines (seq-take lines max-lines))
         (omitted (max 0 (- line-count (length included-lines))))
         (rendered
          (string-join
           (cl-loop for line in included-lines
                    for number from start-line
                    collect (format "%4d | %s" number line))
           "\n")))
    (if (> omitted 0)
        (format "%s\n     | [... %d lines omitted ...]" rendered omitted)
      rendered)))

(defun vibemacs-agent-code-context-snapshot (&optional start end scope)
  "Return an alist describing source context between START and END.
SCOPE describes how the range was selected."
  (let* ((range (unless (and start end)
                  (vibemacs-agent-source-context-range)))
         (range-start (or start (plist-get range :start)))
         (range-end (or end (plist-get range :end)))
         (range-scope (or scope (plist-get range :scope)))
         (root (vibemacs-project-root))
         (file-label (vibemacs-agent-source-file-label buffer-file-name root))
         (source-lines (split-string
                        (buffer-substring-no-properties range-start range-end)
                        "\n"))
         (line-count (length source-lines))
         (included-count (min line-count vibemacs-agent-source-context-line-limit)))
    `((title . ,(format "%s:%d-%d"
                        file-label
                        (line-number-at-pos range-start)
                        (line-number-at-pos (max range-start (1- range-end)))))
      (root . ,root)
      (branch . ,(or (vibemacs-agent-git-branch root) "(none)"))
      (file . ,file-label)
      (scope . ,range-scope)
      (start-line . ,(line-number-at-pos range-start))
      (end-line . ,(line-number-at-pos (max range-start (1- range-end))))
      (line-count . ,line-count)
      (included-lines . ,included-count)
      (omitted-lines . ,(max 0 (- line-count included-count)))
      (language . ,(vibemacs-agent-source-language buffer-file-name))
      (source . ,(vibemacs-agent-line-numbered-source range-start range-end)))))

(defun vibemacs-agent-render-source-context (snapshot)
  "Render SNAPSHOT as a Markdown source context packet."
  (let-alist snapshot
    (string-join
     (append
      (list
       (format "# Source Context: %s" .title)
       ""
       "## Project"
       ""
       (format "- Root: `%s`" .root)
       (format "- Branch: `%s`" .branch)
       ""
       "## Source"
       ""
       (format "- File: `%s`" .file)
       (format "- Lines: `%d-%d`" .start-line .end-line)
       (format "- Scope: `%s`" .scope))
      (when (> .omitted-lines 0)
        (list (format "- Excerpt: first `%d` of `%d` lines"
                      .included-lines .line-count)))
      (list
       ""
       "## Line-Numbered Excerpt"
       ""
       (format "```%s" .language)
       .source
       "```"
       ""
      "## Agent Notes"
      ""
      "- Treat this excerpt as context, not as a substitute for reading adjacent code."
      "- Preserve local style and verify changes against the project gates."
      ""))
     "\n")))

(defun vibemacs-agent-change-review-snapshot (&optional title)
  "Return an alist describing the current Git changes for review."
  (let* ((root (vibemacs-project-root))
         (diff (vibemacs-agent--limit-lines
                (vibemacs-agent-git-diff-lines root)
                vibemacs-agent-change-review-line-limit)))
    `((title . ,(or title "Change Review"))
      (root . ,root)
      (branch . ,(or (vibemacs-agent-git-branch root) "(none)"))
      (changed-files . ,(or (vibemacs-agent-git-changed-files root) '()))
      (diff-stat . ,(or (vibemacs-agent-git-diff-stat root) '()))
      (diff-lines . ,(plist-get diff :lines))
      (diff-line-count . ,(plist-get diff :line-count))
      (included-diff-lines . ,(plist-get diff :included-lines))
      (omitted-diff-lines . ,(plist-get diff :omitted-lines))
      (verification-history . ,vibemacs-agent-verification-history))))

(defun vibemacs-agent-render-change-review (snapshot)
  "Render SNAPSHOT as a Markdown change review packet."
  (let-alist snapshot
    (string-join
     (append
      (list
       (format "# Change Review: %s" .title)
       ""
       "## Project"
       ""
       (format "- Root: `%s`" .root)
       (format "- Branch: `%s`" .branch)
       ""
       "## Changed Files"
       ""
       (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
       ""
       "## Diff Stat"
       ""
       (vibemacs-agent--markdown-list .diff-stat "No diff stat available.")
       ""
       "## Diff Excerpt"
       "")
      (when (> .omitted-diff-lines 0)
        (list (format "- Showing first `%d` of `%d` diff lines."
                      .included-diff-lines .diff-line-count)
              ""))
      (list
       "```diff"
       (if .diff-lines
           (string-join .diff-lines "\n")
         "No diff output available.")
       "```"
       ""
       "## Recent Verification"
       ""
       (vibemacs-agent-render-verification-history .verification-history)
       ""
       "## Review Prompts"
       ""
       "- Does the diff match the stated task?"
       "- Are there unrelated changes that should be split out?"
       "- Which verification result proves the changed behavior?"
       ""))
     "\n")))

(defun vibemacs-agent--plural (count singular plural)
  "Return COUNT with SINGULAR or PLURAL label."
  (format "%d %s" count (if (= count 1) singular plural)))

(defun vibemacs-agent-render-context-packet (snapshot)
  "Render SNAPSHOT as a Markdown project context packet."
  (let-alist snapshot
    (string-join
     (list
      (format "# Agent Context: %s" .title)
      ""
      "## Project"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Session: `%s`" .session-file)
      ""
      "## Project Diagnostics"
      ""
      (vibemacs-agent--markdown-list .diagnostics "No project diagnostics available.")
      ""
      "## Changed Files"
      ""
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Open Project Buffers"
      ""
      (vibemacs-agent--markdown-list .open-files "No project files are open.")
      ""
      "## Recent Task Files"
      ""
      (vibemacs-agent--markdown-list .task-files "No persisted task files found.")
      ""
      "## Recent Task Status"
      ""
      (vibemacs-agent--markdown-list .task-summaries "No task status available.")
      ""
      "## Suggested Verification"
      ""
      (vibemacs-agent--markdown-list .verification "No verification commands configured.")
      ""
      "## Agent Instructions"
      ""
      (string-join (mapcar (lambda (item) (concat "- " item))
                           vibemacs-agent-default-constraints)
                   "\n")
      ""
      "## Notes"
      "")
     "\n")))

(defun vibemacs-agent-render-handoff-bundle (snapshot)
  "Render SNAPSHOT as a copyable Markdown handoff bundle."
  (let-alist snapshot
    (string-join
     (list
      (format "# Vibemacs Agent Handoff: %s" .title)
      ""
      "## Operating Frame"
      ""
      "You are receiving a Vibemacs handoff bundle. Use it as session evidence, not as a substitute for reading the code."
      ""
      "## Project"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Session evidence: `%s`" .session-file)
      ""
      "## Diagnostics"
      ""
      (vibemacs-agent--markdown-list .diagnostics "No project diagnostics available.")
      ""
      "## Git Changes"
      ""
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Open Project Buffers"
      ""
      (vibemacs-agent--markdown-list .open-files "No project files are open.")
      ""
      "## Recent Task Files"
      ""
      (vibemacs-agent--markdown-list .task-files "No persisted task files found.")
      ""
      "## Recent Task Status"
      ""
      (vibemacs-agent--markdown-list .task-summaries "No task status available.")
      ""
      "## Verification Commands"
      ""
      (vibemacs-agent--markdown-list .verification "No verification commands configured.")
      ""
      "## Recent Verification Evidence"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "## Standing Agent Instructions"
      ""
      (string-join (mapcar (lambda (item) (concat "- " item))
                           vibemacs-agent-default-constraints)
                   "\n")
      ""
      "## Requested Outcome"
      ""
      "- Clarify the concrete task before editing."
      "- Make the smallest coherent change that moves the real goal forward."
      "- Report what changed and which checks prove it."
      "")
     "\n")))

(defun vibemacs-agent-render-task (snapshot)
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
      (vibemacs-agent--markdown-list .diagnostics "No project diagnostics available.")
      ""
      "## Changed Files"
      ""
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Open Project Buffers"
      ""
      (vibemacs-agent--markdown-list .open-files "No project files are open.")
      ""
      "## Recent Task Files"
      ""
      (vibemacs-agent--markdown-list .task-files "No persisted task files found.")
      ""
      "## Recent Task Status"
      ""
      (vibemacs-agent--markdown-list .task-summaries "No task status available.")
      ""
      "## Verification Plan"
      ""
      (vibemacs-agent--markdown-list .verification "No verification commands configured.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "## Agent Handoff Bundle"
      ""
      (vibemacs-agent-render-handoff-bundle snapshot)
      "")
     "\n")))

(defun vibemacs-agent-render-task-checkpoint (snapshot &optional time)
  "Render SNAPSHOT as a Markdown task checkpoint.
Optional TIME supplies the checkpoint timestamp."
  (let-alist snapshot
    (string-join
     (list
      (format "### %s Checkpoint" (or time (format-time-string "%H:%M")))
      ""
      "#### Changed Files"
      ""
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "#### Open Project Buffers"
      ""
      (vibemacs-agent--markdown-list .open-files "No project files are open.")
      ""
      "#### Recent Verification"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "#### Next"
      ""
      "- "
      "")
     "\n")))

(defun vibemacs-agent-render-task-decision (decision rationale &optional time)
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

(defun vibemacs-agent-render-current-task-handoff (task-file task-text snapshot)
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
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "## Requested Outcome"
      ""
      "- Continue the task from the persisted evidence."
      "- Preserve unrelated user changes."
      "- Run relevant verification and append evidence back to the task."
      "")
     "\n")))

(defun vibemacs-agent-render-current-task-handoff-entry
    (task-file task-text snapshot &optional time)
  "Render a timestamped current-task handoff entry.
TASK-FILE, TASK-TEXT, and SNAPSHOT are passed through to
`vibemacs-agent-render-current-task-handoff'.  Optional TIME supplies
the displayed timestamp."
  (string-join
   (list
    (format "### %s Task Handoff" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-agent-render-current-task-handoff task-file task-text snapshot))
   "\n"))

(defun vibemacs-agent-render-current-task-prompt (task-file task-text snapshot)
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
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "## Constraints"
      ""
      (string-join (mapcar (lambda (item) (concat "- " item))
                           vibemacs-agent-default-constraints)
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

(defun vibemacs-agent-render-current-task-prompt-entry
    (task-file task-text snapshot &optional time)
  "Render a timestamped current-task prompt packet entry.
TASK-FILE, TASK-TEXT, and SNAPSHOT are passed through to
`vibemacs-agent-render-current-task-prompt'.  Optional TIME supplies
the displayed timestamp."
  (string-join
   (list
    (format "### %s Task Prompt" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-agent-render-current-task-prompt task-file task-text snapshot))
   "\n"))

(defun vibemacs-agent-render-current-task-review
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

(defun vibemacs-agent-render-current-task-next-actions
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
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "## Resume Moves"
      ""
      "- Reopen the task file and inspect the goal before editing."
      "- Work the immediate next action before broadening scope."
      "- Run relevant verification and append evidence back to the task."
      "- Refresh readiness, closeout, and the public journal before handoff."
      "")
     "\n")))

(defun vibemacs-agent-render-current-task-next-actions-entry
    (task-file task-goal open-checks complete total snapshot &optional time)
  "Render a timestamped next-actions entry.
TASK-FILE, TASK-GOAL, OPEN-CHECKS, COMPLETE, TOTAL, and SNAPSHOT are
passed through to `vibemacs-agent-render-current-task-next-actions'.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Next Actions" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-agent-render-current-task-next-actions
     task-file
     task-goal
     open-checks
     complete
     total
     snapshot))
   "\n"))

(defun vibemacs-agent-render-current-task-verification-plan
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
      (vibemacs-agent--markdown-list commands "No verification commands configured.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "## Changed Files"
      ""
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Verification Notes"
      ""
      "- Run the narrowest command that proves the edited behavior first."
      "- Escalate to the full suite before handoff when shared behavior changed."
      "- Append the latest verification evidence back into the task file."
      "- Refresh readiness and closeout after verification changes."
      "")
     "\n")))

(defun vibemacs-agent-render-current-task-verification-plan-entry
    (task-file task-goal open-checks commands snapshot &optional time)
  "Render a timestamped verification plan entry.
TASK-FILE, TASK-GOAL, OPEN-CHECKS, COMMANDS, and SNAPSHOT are passed
through to `vibemacs-agent-render-current-task-verification-plan'.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Verification Plan" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-agent-render-current-task-verification-plan
     task-file
     task-goal
     open-checks
     commands
     snapshot))
   "\n"))

(defun vibemacs-agent-render-current-task-final-response
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
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "Verification:"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
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

(defun vibemacs-agent-render-current-task-final-response-entry
    (task-file task-goal open-checks closeout snapshot &optional time)
  "Render a timestamped final-response draft entry.
TASK-FILE, TASK-GOAL, OPEN-CHECKS, CLOSEOUT, and SNAPSHOT are passed
through to `vibemacs-agent-render-current-task-final-response'.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Final Response Draft" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-agent-render-current-task-final-response
     task-file
     task-goal
     open-checks
     closeout
     snapshot))
   "\n"))

(defun vibemacs-agent-render-current-task-scope-audit
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
      (vibemacs-agent--markdown-list changed-files "No Git changes detected.")
      ""
      "## Diff Stat"
      ""
      (vibemacs-agent--markdown-list diff-stat "No diff stat available.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "## Scope Questions"
      ""
      "- Does every changed file support the task goal or an acceptance check?"
      "- Are there unrelated edits that should be split out before handoff?"
      "- Is any open acceptance check contradicted by the diff?"
      "- Does the final response name only the work actually completed?"
      "")
     "\n")))

(defun vibemacs-agent-render-current-task-scope-audit-entry
    (task-file task-goal open-checks changed-files diff-stat snapshot &optional time)
  "Render a timestamped scope audit entry.
TASK-FILE, TASK-GOAL, OPEN-CHECKS, CHANGED-FILES, DIFF-STAT, and
SNAPSHOT are passed through to
`vibemacs-agent-render-current-task-scope-audit'.  Optional TIME
supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Scope Audit" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-agent-render-current-task-scope-audit
     task-file
     task-goal
     open-checks
     changed-files
     diff-stat
     snapshot))
   "\n"))

(defun vibemacs-agent-render-current-task-risk-register
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
        (vibemacs-agent--markdown-list changed-files "No Git changes detected.")
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
        (vibemacs-agent-render-verification-history .verification-history)
        "")
       "\n"))))

(defun vibemacs-agent-render-current-task-risk-register-entry
    (task-file task-goal open-checks changed-files snapshot &optional time)
  "Render a timestamped risk register entry.
TASK-FILE, TASK-GOAL, OPEN-CHECKS, CHANGED-FILES, and SNAPSHOT are
passed through to `vibemacs-agent-render-current-task-risk-register'.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Risk Register" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-agent-render-current-task-risk-register
     task-file
     task-goal
     open-checks
     changed-files
     snapshot))
   "\n"))

(defun vibemacs-agent-render-current-task-dependency-map
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
      (vibemacs-agent--markdown-list changed-files "No Git changes detected.")
      ""
      "## Source Dependencies"
      ""
      (vibemacs-agent-render-dependency-map dependency-map)
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
      (vibemacs-agent-render-verification-history .verification-history)
      "")
     "\n")))

(defun vibemacs-agent-render-current-task-dependency-map-entry
    (task-file task-goal changed-files dependency-map snapshot &optional time)
  "Render a timestamped dependency map entry.
TASK-FILE, TASK-GOAL, CHANGED-FILES, DEPENDENCY-MAP, and SNAPSHOT
are passed through to `vibemacs-agent-render-current-task-dependency-map'.
Optional TIME supplies the displayed timestamp."
  (string-join
   (list
    (format "### %s Dependency Map" (or time (format-time-string "%H:%M")))
    ""
    (vibemacs-agent-render-current-task-dependency-map
     task-file
     task-goal
     changed-files
     dependency-map
     snapshot))
   "\n"))

(defun vibemacs-agent-render-artifact-index (snapshot)
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
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "### Open Project Buffers"
      ""
      (vibemacs-agent--markdown-list .open-files "No project files are open.")
      ""
      "## Persistent Artifacts"
      ""
      "### Task Files"
      ""
      (vibemacs-agent--markdown-list .task-files "No persisted task files found.")
      ""
      "### Task Status"
      ""
      (vibemacs-agent--markdown-list .task-summaries "No task status available.")
      ""
      "### Public Journal Entries"
      ""
      (vibemacs-agent--markdown-list .journal-files "No journal entries found.")
      ""
      "### Local Notes"
      ""
      (vibemacs-agent--markdown-list .note-files "No local notes found.")
      ""
      "## Recent Verification"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "## Resume Prompts"
      ""
      "- Which task file should be reopened first?"
      "- Which changed file needs source context or review?"
      "- Which verification result is missing or stale?"
      "")
     "\n")))

(defun vibemacs-agent-render-journal-entry (title slug snapshot)
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
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Recent Task Status"
      ""
      (vibemacs-agent--markdown-list .task-summaries "No task status available.")
      ""
      "## Verification"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "## Public Summary"
      ""
      "- "
     "")
     "\n")))

(defun vibemacs-agent-task-journal-snapshot (title)
  "Return project and task evidence for a task-derived journal TITLE."
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (task-file (file-relative-name buffer-file-name root))
         (progress (vibemacs-agent-task-checkbox-progress))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (closeout (vibemacs-agent-task-section-content "Closeout"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open)))
    (append
     (vibemacs-agent-project-snapshot title)
     `((task-file . ,task-file)
       (task-title . ,(vibemacs-agent-current-task-title))
       (task-goal . ,(if (and goal (not (string-empty-p goal)))
                         goal
                       "No task goal recorded yet."))
       (task-closeout . ,(if (and closeout (not (string-empty-p closeout)))
                             closeout
                           "No task closeout recorded yet."))
       (task-checks-complete . ,(plist-get progress :complete))
       (task-checks-total . ,(plist-get progress :total))
       (task-open-checks . ,open-checks)))))

(defun vibemacs-agent-render-task-journal-entry (title slug snapshot)
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
      (vibemacs-agent--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Verification"
      ""
      (vibemacs-agent-render-verification-history .verification-history)
      ""
      "## Public Summary"
      ""
      "- "
      "")
     "\n")))

(defun vibemacs-agent-cockpit-actions ()
  "Return cockpit action descriptors.
Each descriptor is (KEY LABEL COMMAND DESCRIPTION)."
  '(("p" "Prompt packet" vibemacs-agent-open-prompt-packet
     "Draft an agent-ready task prompt.")
    ("A" "Next actions" vibemacs-agent-open-current-task-next-actions
     "Open a next-action packet for the current task file.")
    ("L" "Write next" vibemacs-agent-insert-current-task-next-actions
     "Append a next-actions packet to the current task file.")
    ("P" "Task prompt" vibemacs-agent-open-current-task-prompt
     "Open an agent prompt packet seeded from the current task file.")
    ("X" "Write prompt" vibemacs-agent-insert-current-task-prompt
     "Append an agent prompt packet to the current task file.")
    ("T" "Task review" vibemacs-agent-open-current-task-review
     "Open a review packet for the current task, readiness, closeout, and diff.")
    ("a" "Task buffer" vibemacs-agent-open-task
     "Create or reopen a persisted task file from project evidence.")
    ("b" "Task board" vibemacs-agent-open-task-board
     "Open a tabulated board of persisted task files.")
    ("r" "Recent task" vibemacs-agent-open-recent-task
     "Open an existing persisted task file.")
    ("x" "Context packet" vibemacs-agent-open-context-packet
     "Collect project evidence for a handoff.")
    ("i" "Artifact index" vibemacs-agent-open-artifact-index
     "Open a resume map of tasks, journals, notes, buffers, and verification.")
    ("f" "Source packet" vibemacs-agent-open-source-context
     "Open a line-numbered packet for the selected code or current definition.")
    ("F" "Final response" vibemacs-agent-open-current-task-final-response
     "Open a final-response draft from the current task file.")
    ("I" "Write final" vibemacs-agent-insert-current-task-final-response
     "Append a final-response draft to the current task file.")
    ("S" "Scope audit" vibemacs-agent-open-current-task-scope-audit
     "Open a scope audit packet for the current task and Git changes.")
    ("O" "Write scope" vibemacs-agent-insert-current-task-scope-audit
     "Append a scope audit to the current task file.")
    ("K" "Risk register" vibemacs-agent-open-current-task-risk-register
     "Open a risk register packet for the current task and remaining checks.")
    ("U" "Write risks" vibemacs-agent-insert-current-task-risk-register
     "Append a risk register to the current task file.")
    ("M" "Dependency map" vibemacs-agent-open-current-task-dependency-map
     "Open a dependency map for changed files in the current task.")
    ("B" "Write deps" vibemacs-agent-insert-current-task-dependency-map
     "Append a dependency map to the current task file.")
    ("Q" "Review checklist" vibemacs-agent-insert-task-review-checklist
     "Append a durable review checklist to the current task file.")
    ("d" "Change review" vibemacs-agent-open-change-review
     "Open a packet summarizing Git status, diff stat, diff excerpt, and verification.")
    ("G" "Verify guide" vibemacs-agent-open-current-task-verification-plan
     "Open a verification plan packet for the current task file.")
    ("N" "Write verify" vibemacs-agent-insert-current-task-verification-plan
     "Append a verification plan to the current task file.")
    ("t" "Transcript" vibemacs-agent-open-transcript
     "Open the working command transcript.")
    ("v" "Verify" vibemacs-agent-run-verification
     "Run and record a verification command.")
    ("V" "Verify suite" vibemacs-agent-run-verification-suite
     "Run every configured verification command in sequence.")
    ("e" "Insert evidence" vibemacs-agent-insert-latest-verification-evidence
     "Append the latest verification result to the current task file.")
    ("E" "Evidence snapshot" vibemacs-agent-insert-verification-history-snapshot
     "Append the current verification history to the current task file.")
    ("k" "Checkpoint task" vibemacs-agent-insert-task-checkpoint
     "Append changed files, open buffers, and verification to the current task file.")
    ("h" "Task handoff" vibemacs-agent-copy-current-task-handoff
     "Copy the current task file plus fresh project evidence for another agent.")
    ("H" "Write handoff" vibemacs-agent-insert-current-task-handoff
     "Append a fresh task handoff bundle to the current task file.")
    ("D" "Record decision" vibemacs-agent-insert-task-decision
     "Append a timestamped decision and rationale to the current task file.")
    ("n" "Next check" vibemacs-agent-next-task-checkbox
     "Move to the next unchecked Markdown task checkbox.")
    ("m" "Toggle check" vibemacs-agent-toggle-task-checkbox
     "Toggle the Markdown task checkbox on the current line.")
    ("R" "Task readiness" vibemacs-agent-open-task-readiness
     "Open a readiness report for the current task file.")
    ("W" "Write readiness" vibemacs-agent-insert-task-readiness
     "Append a readiness snapshot to the current task file.")
    ("o" "Closeout task" vibemacs-agent-insert-task-closeout
     "Append a concise closeout summary to the current task file.")
    ("c" "Cycle note" vibemacs-agent-start-cycle
     "Start a local development cycle note.")
    ("j" "Journal" vibemacs-agent-open-journal-entry
     "Open today's public development journal entry.")
    ("J" "Task journal" vibemacs-agent-open-task-journal-entry
     "Open a public journal draft seeded from the current task file.")
    ("s" "Ship checklist" vibemacs-agent-insert-shipping-checklist
     "Insert the end-of-cycle checklist.")
    ("w" "Save session" vibemacs-agent-save-session
     "Persist recent session evidence to the project.")
    ("l" "Load session" vibemacs-agent-load-session
     "Reload persisted session evidence.")
    ("y" "Copy handoff" vibemacs-agent-copy-handoff-bundle
     "Copy a full agent handoff bundle to the kill ring.")))

(defconst vibemacs-agent-task-action-commands
  '(vibemacs-agent-open-current-task-next-actions
    vibemacs-agent-insert-current-task-next-actions
    vibemacs-agent-open-current-task-prompt
    vibemacs-agent-insert-current-task-prompt
    vibemacs-agent-open-current-task-review
    vibemacs-agent-open-current-task-final-response
    vibemacs-agent-insert-current-task-final-response
    vibemacs-agent-open-current-task-scope-audit
    vibemacs-agent-insert-current-task-scope-audit
    vibemacs-agent-open-current-task-risk-register
    vibemacs-agent-insert-current-task-risk-register
    vibemacs-agent-open-current-task-dependency-map
    vibemacs-agent-insert-current-task-dependency-map
    vibemacs-agent-insert-task-review-checklist
    vibemacs-agent-open-current-task-verification-plan
    vibemacs-agent-insert-current-task-verification-plan
    vibemacs-agent-run-verification
    vibemacs-agent-run-verification-suite
    vibemacs-agent-insert-latest-verification-evidence
    vibemacs-agent-insert-verification-history-snapshot
    vibemacs-agent-insert-task-checkpoint
    vibemacs-agent-copy-current-task-handoff
    vibemacs-agent-insert-current-task-handoff
    vibemacs-agent-insert-task-decision
    vibemacs-agent-next-task-checkbox
    vibemacs-agent-toggle-task-checkbox
    vibemacs-agent-open-task-readiness
    vibemacs-agent-insert-task-readiness
    vibemacs-agent-insert-task-closeout
    vibemacs-agent-open-task-journal-entry)
  "Commands shown in the persisted task action menu.")

(defun vibemacs-agent-task-actions ()
  "Return cockpit descriptors that are meaningful in persisted task files."
  (seq-filter
   (lambda (action)
     (memq (nth 2 action) vibemacs-agent-task-action-commands))
   (vibemacs-agent-cockpit-actions)))

(defun vibemacs-agent-task-action-candidates (&optional actions)
  "Return completion candidates for task ACTIONS.
Each candidate is a cons cell whose car is display text and whose cdr is
the original action descriptor."
  (mapcar (lambda (action)
            (pcase-let ((`(,key ,label ,_command ,description) action))
              (cons (format "[%s] %s - %s" key label description)
                    action)))
          (or actions (vibemacs-agent-task-actions))))

(defun vibemacs-agent-task-action-command (choice &optional actions)
  "Return the command selected by CHOICE from task ACTIONS."
  (let ((action (cdr (assoc choice (vibemacs-agent-task-action-candidates actions)))))
    (unless action
      (user-error "Unknown Vibemacs task action: %s" choice))
    (nth 2 action)))

(defun vibemacs-agent-dispatch-task-action ()
  "Prompt for and run an action against the current persisted task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((candidates (vibemacs-agent-task-action-candidates))
         (choice (completing-read "Task action: "
                                  (mapcar #'car candidates)
                                  nil
                                  t))
         (command (vibemacs-agent-task-action-command
                   choice
                   (mapcar #'cdr candidates))))
    (call-interactively command)
    command))

(defun vibemacs-agent-render-cockpit (snapshot)
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
                (vibemacs-agent--plural changed-count "changed file" "changed files")
                (vibemacs-agent--plural open-count "open project buffer" "open project buffers")
                (vibemacs-agent--plural verify-count "verification command" "verification commands"))
        ""
        "Actions"
        "-------"
        (string-join
         (mapcar (lambda (action)
                   (pcase-let ((`(,key ,label ,_command ,description) action))
                     (format "[%s] %-15s %s" key label description)))
                 (vibemacs-agent-cockpit-actions))
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
        (vibemacs-agent-render-verification-history .verification-history)
        "")
       "\n"))))

(defun vibemacs-agent--insert-cockpit-button (key label command description)
  "Insert one cockpit action button for KEY LABEL COMMAND and DESCRIPTION."
  (insert (format "[%s] " key))
  (insert-text-button label
                      'follow-link t
                      'help-echo description
                      'action (lambda (_button)
                                (call-interactively command)))
  (insert (format "\n    %s\n" description)))

(defun vibemacs-agent-refresh-task-board ()
  "Refresh the current Vibemacs task board."
  (interactive)
  (unless (derived-mode-p 'vibemacs-agent-task-board-mode)
    (user-error "Current buffer is not a Vibemacs task board"))
  (setq tabulated-list-entries
        (vibemacs-agent-task-board-entries vibemacs-agent-task-board-root))
  (tabulated-list-print t)
  tabulated-list-entries)

(defun vibemacs-agent-task-board-open-task ()
  "Open the task on the current task board row."
  (interactive)
  (let ((file (tabulated-list-get-id)))
    (unless file
      (user-error "No Vibemacs task on this row"))
    (find-file (expand-file-name
                file
                (file-name-as-directory
                 (or vibemacs-agent-task-board-root
                     (vibemacs-project-root)))))))

(defun vibemacs-agent-open-task-board ()
  "Open a tabulated board of persisted Vibemacs task files."
  (interactive)
  (let ((root (file-name-as-directory (vibemacs-project-root)))
        (buffer (get-buffer-create vibemacs-agent-task-board-buffer-name)))
    (with-current-buffer buffer
      (vibemacs-agent-task-board-mode)
      (setq vibemacs-agent-task-board-root root)
      (vibemacs-agent-refresh-task-board))
    (pop-to-buffer buffer)
    buffer))

(defun vibemacs-agent-open-cockpit ()
  "Open the Vibemacs agentic programming cockpit."
  (interactive)
  (let ((buffer (get-buffer-create vibemacs-agent-cockpit-buffer-name))
        (snapshot (vibemacs-agent-project-snapshot "Cockpit")))
    (with-current-buffer buffer
      (vibemacs-agent-cockpit-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (let-alist snapshot
          (insert "Vibemacs\n========\n\n")
          (insert "Project\n-------\n")
          (insert (format "Root: %s\n" .root))
          (insert (format "Branch: %s\n" .branch))
          (insert (format "Session: %s\n" .session-file))
          (insert (format "Status: %s, %s, %s\n\n"
                          (vibemacs-agent--plural (length .changed-files)
                                                  "changed file" "changed files")
                          (vibemacs-agent--plural (length .open-files)
                                                  "open project buffer"
                                                  "open project buffers")
                          (vibemacs-agent--plural (length .verification)
                                                  "verification command"
                                                  "verification commands")))
          (insert "Actions\n-------\n")
          (dolist (action (vibemacs-agent-cockpit-actions))
            (pcase-let ((`(,key ,label ,command ,description) action))
              (vibemacs-agent--insert-cockpit-button key label command description)))
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
          (insert (vibemacs-agent-render-verification-history .verification-history))
          (insert "\n\nKeys: g refresh, q quit\n")))
      (goto-char (point-min)))
    (pop-to-buffer buffer)))

(defun vibemacs-agent-copy-handoff-bundle (&optional title)
  "Copy a full agent handoff bundle for TITLE to the kill ring."
  (interactive "sHandoff title: ")
  (let* ((heading (if (and title (not (string-empty-p (string-trim title))))
                      title
                    "Agent Handoff"))
         (bundle (vibemacs-agent-render-handoff-bundle
                  (vibemacs-agent-project-snapshot heading))))
    (kill-new bundle)
    (message "Copied Vibemacs handoff bundle (%d characters)" (length bundle))
    bundle))

(defun vibemacs-agent-copy-current-task-handoff ()
  "Copy the current persisted task plus fresh project evidence to the kill ring."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (task-file (file-relative-name buffer-file-name root))
         (task-text (vibemacs-agent-current-task-text))
         (bundle (vibemacs-agent-render-current-task-handoff
                  task-file
                  task-text
                  (vibemacs-agent-project-snapshot "Current Task"))))
    (kill-new bundle)
    (message "Copied Vibemacs task handoff (%d characters)" (length bundle))
    bundle))

(defun vibemacs-agent-insert-current-task-handoff ()
  "Append a fresh handoff bundle to the current persisted task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (task-file (file-relative-name buffer-file-name root))
         (task-text (vibemacs-agent-current-task-text))
         (entry (vibemacs-agent-render-current-task-handoff-entry
                 task-file
                 task-text
                 (vibemacs-agent-project-snapshot
                  (vibemacs-agent-current-task-title)))))
    (vibemacs-agent-append-task-section-entry "Agent Handoff Bundle" entry)
    (vibemacs-agent-refresh-task-status)
    (message "Inserted Vibemacs task handoff bundle")
    entry))

(defun vibemacs-agent-open-current-task-prompt ()
  "Open an agent prompt packet seeded from the current persisted task."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (task-file (file-relative-name buffer-file-name root))
         (task-text (vibemacs-agent-current-task-text))
         (prompt (vibemacs-agent-render-current-task-prompt
                  task-file
                  task-text
                  (vibemacs-agent-project-snapshot
                   (vibemacs-agent-current-task-title)))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-prompt*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert prompt)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-insert-current-task-prompt ()
  "Append an agent prompt packet to the current persisted task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (task-file (file-relative-name buffer-file-name root))
         (task-text (vibemacs-agent-current-task-text))
         (entry (vibemacs-agent-render-current-task-prompt-entry
                 task-file
                 task-text
                 (vibemacs-agent-project-snapshot
                  (vibemacs-agent-current-task-title)))))
    (vibemacs-agent-append-task-section-entry "Task Prompt Packets" entry)
    (vibemacs-agent-refresh-task-status)
    (message "Inserted Vibemacs task prompt packet")
    entry))

(defun vibemacs-agent-open-current-task-review ()
  "Open a review packet for the current persisted task."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (task-text (vibemacs-agent-current-task-text))
         (readiness (vibemacs-agent-render-task-readiness task-file))
         (closeout (or (vibemacs-agent-task-section-content "Closeout")
                       "No task closeout recorded yet."))
         (change-review
          (vibemacs-agent-render-change-review
           (vibemacs-agent-change-review-snapshot
            (format "Current Task: %s" title))))
         (review (vibemacs-agent-render-current-task-review
                  task-file
                  task-text
                  readiness
                  closeout
                  change-review
                  (vibemacs-agent-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-review*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert review)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-open-current-task-next-actions ()
  "Open a next-action packet for the current persisted task."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (progress (vibemacs-agent-task-checkbox-progress))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open))
         (packet (vibemacs-agent-render-current-task-next-actions
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  open-checks
                  (plist-get progress :complete)
                  (plist-get progress :total)
                  (vibemacs-agent-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-next-actions*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-insert-current-task-next-actions ()
  "Append a next-actions packet to the current persisted task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (progress (vibemacs-agent-task-checkbox-progress))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open))
         (entry (vibemacs-agent-render-current-task-next-actions-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 open-checks
                 (plist-get progress :complete)
                 (plist-get progress :total)
                 (vibemacs-agent-project-snapshot title))))
    (vibemacs-agent-append-task-section-entry "Next Actions" entry)
    (vibemacs-agent-refresh-task-status)
    (message "Inserted Vibemacs task next actions")
    entry))

(defun vibemacs-agent-open-current-task-verification-plan ()
  "Open a verification plan packet for the current persisted task."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open))
         (packet (vibemacs-agent-render-current-task-verification-plan
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  open-checks
                  (vibemacs-agent-verification-suite-plan)
                  (vibemacs-agent-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-verification-plan*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-insert-current-task-verification-plan ()
  "Append a verification plan to the current persisted task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open))
         (entry (vibemacs-agent-render-current-task-verification-plan-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 open-checks
                 (vibemacs-agent-verification-suite-plan)
                 (vibemacs-agent-project-snapshot title))))
    (vibemacs-agent-append-task-section-entry "Verification Plans" entry)
    (vibemacs-agent-refresh-task-status)
    (message "Inserted Vibemacs task verification plan")
    entry))

(defun vibemacs-agent-open-current-task-final-response ()
  "Open a final-response draft for the current persisted task."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open))
         (closeout (vibemacs-agent-task-section-content "Closeout"))
         (packet (vibemacs-agent-render-current-task-final-response
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  open-checks
                  (if (and closeout (not (string-empty-p closeout)))
                      closeout
                    "No task closeout recorded yet.")
                  (vibemacs-agent-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-final-response*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-insert-current-task-final-response ()
  "Append a final-response draft to the current persisted task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open))
         (closeout (vibemacs-agent-task-section-content "Closeout"))
         (entry (vibemacs-agent-render-current-task-final-response-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 open-checks
                 (if (and closeout (not (string-empty-p closeout)))
                     closeout
                   "No task closeout recorded yet.")
                 (vibemacs-agent-project-snapshot title))))
    (vibemacs-agent-append-task-section-entry "Final Response Drafts" entry)
    (vibemacs-agent-refresh-task-status)
    (message "Inserted Vibemacs final response draft")
    entry))

(defun vibemacs-agent-open-current-task-scope-audit ()
  "Open a scope audit packet for the current persisted task."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open))
         (packet (vibemacs-agent-render-current-task-scope-audit
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  open-checks
                  (or (vibemacs-agent-git-changed-files root) '())
                  (or (vibemacs-agent-git-diff-stat root) '())
                  (vibemacs-agent-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-scope-audit*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-insert-current-task-scope-audit ()
  "Append a scope audit to the current persisted task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open))
         (entry (vibemacs-agent-render-current-task-scope-audit-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 open-checks
                 (or (vibemacs-agent-git-changed-files root) '())
                 (or (vibemacs-agent-git-diff-stat root) '())
                 (vibemacs-agent-project-snapshot title))))
    (vibemacs-agent-append-task-section-entry "Scope Audits" entry)
    (vibemacs-agent-refresh-task-status)
    (message "Inserted Vibemacs task scope audit")
    entry))

(defun vibemacs-agent-open-current-task-risk-register ()
  "Open a risk register packet for the current persisted task."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open))
         (packet (vibemacs-agent-render-current-task-risk-register
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  open-checks
                  (or (vibemacs-agent-git-changed-files root) '())
                  (vibemacs-agent-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-risk-register*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-insert-current-task-risk-register ()
  "Append a risk register to the current persisted task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (open-checks (vibemacs-agent-task-checkbox-items 'open))
         (entry (vibemacs-agent-render-current-task-risk-register-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 open-checks
                 (or (vibemacs-agent-git-changed-files root) '())
                 (vibemacs-agent-project-snapshot title))))
    (vibemacs-agent-append-task-section-entry "Risk Registers" entry)
    (vibemacs-agent-refresh-task-status)
    (message "Inserted Vibemacs task risk register")
    entry))

(defun vibemacs-agent-open-current-task-dependency-map ()
  "Open a dependency map packet for the current persisted task."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (changed-files (or (vibemacs-agent-git-changed-files root) '()))
         (packet (vibemacs-agent-render-current-task-dependency-map
                  task-file
                  (if (and goal (not (string-empty-p goal)))
                      goal
                    "No task goal recorded yet.")
                  changed-files
                  (vibemacs-agent-changed-file-dependency-map
                   root
                   changed-files)
                  (vibemacs-agent-project-snapshot title))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-dependency-map*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-insert-current-task-dependency-map ()
  "Append a dependency map to the current persisted task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((root (vibemacs-project-root))
         (title (vibemacs-agent-current-task-title))
         (task-file (file-relative-name buffer-file-name root))
         (goal (vibemacs-agent-task-section-content "Goal"))
         (changed-files (or (vibemacs-agent-git-changed-files root) '()))
         (entry (vibemacs-agent-render-current-task-dependency-map-entry
                 task-file
                 (if (and goal (not (string-empty-p goal)))
                     goal
                   "No task goal recorded yet.")
                 changed-files
                 (vibemacs-agent-changed-file-dependency-map
                  root
                  changed-files)
                 (vibemacs-agent-project-snapshot title))))
    (vibemacs-agent-append-task-section-entry "Dependency Maps" entry)
    (vibemacs-agent-refresh-task-status)
    (message "Inserted Vibemacs task dependency map")
    entry))

(defun vibemacs-agent-open-task (title)
  "Open a persisted structured Vibemacs task file for TITLE."
  (interactive "sTask title: ")
  (let* ((heading (if (string-empty-p (string-trim title)) "Agent Task" title))
         (file (vibemacs-agent-task-path heading)))
    (vibemacs-ensure-directory (file-name-directory file))
    (find-file file)
    (vibemacs-agent-maybe-enable-task-mode)
    (when (= (buffer-size) 0)
      (insert (vibemacs-agent-render-task
               (vibemacs-agent-project-snapshot heading)))
      (goto-char (point-min)))
    (current-buffer)))

(defun vibemacs-agent-open-recent-task (task)
  "Open existing persisted TASK selected from project task files."
  (interactive
   (let ((tasks (vibemacs-agent-task-files)))
     (list (completing-read "Task file: " tasks nil t nil nil (car tasks)))))
  (let ((file (expand-file-name task (vibemacs-project-root))))
    (find-file file)
    (vibemacs-agent-maybe-enable-task-mode)))

(defun vibemacs-agent-open-prompt-packet ()
  "Open a prompt packet buffer for the current context."
  (interactive)
  (let ((buffer (vibemacs-new-scratch-buffer "*vibemacs-prompt*" #'vibemacs-markdown-mode)))
    (when (= (buffer-size buffer) 0)
      (insert (vibemacs-agent-prompt-template)))
    buffer))

(defun vibemacs-agent-open-transcript ()
  "Open an agent transcript buffer."
  (interactive)
  (let ((buffer (vibemacs-new-scratch-buffer vibemacs-agent-transcript-buffer-name
                                             #'vibemacs-markdown-mode)))
    (when (= (buffer-size buffer) 0)
      (insert (vibemacs-agent-transcript-template)))
    buffer))

(defun vibemacs-agent-read-verification-command ()
  "Read a verification command from `vibemacs-agent-verification-commands'."
  (completing-read "Verify command: "
                   vibemacs-agent-verification-commands
                   nil nil nil nil
                   (car vibemacs-agent-verification-commands)))

(defun vibemacs-agent-run-verification (command)
  "Run verification COMMAND from the project root and record it."
  (interactive (list (vibemacs-agent-read-verification-command)))
  (vibemacs-agent--start-verification-command command))

(defun vibemacs-agent-run-verification-suite (&optional commands)
  "Run COMMANDS as a sequential verification suite.
When COMMANDS is nil, use `vibemacs-agent-verification-commands'."
  (interactive)
  (let ((plan (vibemacs-agent-verification-suite-plan commands)))
    (unless plan
      (user-error "No verification commands configured"))
    (message "Running Vibemacs verification suite: %d commands" (length plan))
    (vibemacs-agent--start-verification-command
     (car plan)
     (cdr plan)
     (vibemacs-project-root))))

(defun vibemacs-agent-insert-latest-verification-evidence ()
  "Append the latest verification result to the current task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((entry (vibemacs-agent-latest-verification-result)))
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
      (insert (vibemacs-agent-render-verification-entry entry) "\n")
      (when (looking-at-p "^## ")
        (insert "\n")))
    (message "Inserted latest Vibemacs verification evidence")
    entry))

(defun vibemacs-agent-insert-verification-history-snapshot ()
  "Append the current verification history to the current task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (unless vibemacs-agent-verification-history
    (user-error "No verification results recorded"))
  (let ((snapshot (vibemacs-agent-render-verification-history-snapshot)))
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

(defun vibemacs-agent-insert-task-checkpoint ()
  "Append a project checkpoint to the current task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((checkpoint (vibemacs-agent-render-task-checkpoint
                     (vibemacs-agent-project-snapshot "Task Checkpoint"))))
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

(defun vibemacs-agent-insert-task-decision (decision rationale)
  "Append DECISION and RATIONALE to the current task file."
  (interactive "sDecision: \nsRationale: ")
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (when (string-empty-p (string-trim decision))
    (user-error "Decision cannot be empty"))
  (let ((entry (vibemacs-agent-render-task-decision
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

(defun vibemacs-agent-next-task-checkbox ()
  "Move point to the next unchecked checkbox in the current task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((origin (point))
        found)
    (while (and (not found)
                (re-search-forward vibemacs-agent-task-checkbox-regexp nil t))
      (when (string= (match-string 1) " ")
        (setq found (match-beginning 1))))
    (unless found
      (goto-char (point-min))
      (while (and (not found)
                  (< (point) origin)
                  (re-search-forward vibemacs-agent-task-checkbox-regexp origin t))
        (when (string= (match-string 1) " ")
          (setq found (match-beginning 1)))))
    (unless found
      (goto-char origin)
      (user-error "No unchecked task checkboxes found"))
    (goto-char found)
    (message "Moved to unchecked Vibemacs task checkbox")
    found))

(defun vibemacs-agent-toggle-task-checkbox ()
  "Toggle the Markdown task checkbox on the current line."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((line-end (line-end-position))
        replacement)
    (save-excursion
      (beginning-of-line)
      (unless (re-search-forward vibemacs-agent-task-checkbox-regexp line-end t)
        (user-error "Current line is not a task checkbox"))
      (setq replacement (if (string= (match-string 1) " ") "x" " "))
      (replace-match replacement t t nil 1))
    (let* ((progress (vibemacs-agent-task-checkbox-progress))
           (message-text (format "%d/%d checks complete"
                                 (plist-get progress :complete)
                                 (plist-get progress :total))))
      (message "Vibemacs task checkbox toggled: %s" message-text)
      message-text)))

(defun vibemacs-agent-open-task-readiness ()
  "Open a readiness report for the current task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((report (vibemacs-agent-render-task-readiness)))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-task-readiness*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert report)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-insert-task-readiness ()
  "Append a readiness snapshot to the current task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((snapshot (vibemacs-agent-render-task-readiness-snapshot)))
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

(defun vibemacs-agent-insert-task-closeout ()
  "Append a closeout summary to the current task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((closeout (vibemacs-agent-render-task-closeout)))
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

(defun vibemacs-agent-insert-task-review-checklist ()
  "Append a review checklist to the current task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let ((checklist (vibemacs-agent-render-task-review-checklist)))
    (vibemacs-agent-append-task-section-entry "Review Checklist" checklist)
    (vibemacs-agent-refresh-task-status)
    (message "Inserted Vibemacs task review checklist")
    checklist))

(defun vibemacs-agent-open-context-packet (title)
  "Open a project context packet buffer named by TITLE."
  (interactive "sContext title: ")
  (let ((buffer (vibemacs-new-scratch-buffer "*vibemacs-context*" #'vibemacs-markdown-mode)))
    (erase-buffer)
    (insert (vibemacs-agent-render-context-packet
             (vibemacs-agent-project-snapshot
              (if (string-empty-p (string-trim title)) "Agent Context" title))))
    (goto-char (point-min))
    buffer))

(defun vibemacs-agent-open-artifact-index ()
  "Open a Markdown index of Vibemacs project artifacts."
  (interactive)
  (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-artifacts*"
                                                    #'vibemacs-markdown-mode)
    (erase-buffer)
    (insert (vibemacs-agent-render-artifact-index
             (vibemacs-agent-artifact-snapshot "Project Artifacts")))
    (goto-char (point-min))
    (current-buffer)))

(defun vibemacs-agent-open-source-context ()
  "Open a line-numbered source context packet for the current source range."
  (interactive)
  (let ((packet (vibemacs-agent-render-source-context
                 (vibemacs-agent-code-context-snapshot))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-source-context*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-open-change-review (&optional title)
  "Open a Markdown change review packet for TITLE."
  (interactive "sReview title: ")
  (let* ((heading (if (and title (not (string-empty-p (string-trim title))))
                      title
                    "Change Review"))
         (packet (vibemacs-agent-render-change-review
                  (vibemacs-agent-change-review-snapshot heading))))
    (with-current-buffer (vibemacs-new-scratch-buffer "*vibemacs-change-review*"
                                                      #'vibemacs-markdown-mode)
      (erase-buffer)
      (insert packet)
      (goto-char (point-min))
      (current-buffer))))

(defun vibemacs-agent-start-cycle (title)
  "Create a local development cycle note named from TITLE."
  (interactive "sCycle title: ")
  (let* ((directory (vibemacs-ensure-directory
                     (vibemacs-expand-project-file vibemacs-notes-directory)))
         (file (expand-file-name
                (format "%s-%s.md" (vibemacs-today) (vibemacs-slugify title))
                directory)))
    (find-file file)
    (when (= (buffer-size) 0)
      (insert (vibemacs-agent-cycle-template title)))))

(defun vibemacs-agent-open-journal-entry (title)
  "Open today's public journal entry for TITLE."
  (interactive "sJournal title: ")
  (let* ((directory (vibemacs-ensure-directory
                     (vibemacs-expand-project-file vibemacs-cycle-directory)))
         (slug (vibemacs-slugify title))
         (file (expand-file-name (format "%s-%s.md" (vibemacs-today) slug) directory)))
    (find-file file)
    (when (= (buffer-size) 0)
      (insert
       (vibemacs-agent-render-journal-entry
       title
       slug
       (vibemacs-agent-project-snapshot title))))))

(defun vibemacs-agent-open-task-journal-entry ()
  "Open today's public journal entry seeded from the current task file."
  (interactive)
  (unless (vibemacs-agent-task-file-p)
    (user-error "Current buffer is not a Vibemacs task file"))
  (let* ((title (vibemacs-agent-current-task-title))
         (slug (vibemacs-slugify title))
         (snapshot (vibemacs-agent-task-journal-snapshot title))
         (directory (vibemacs-ensure-directory
                     (vibemacs-expand-project-file vibemacs-cycle-directory)))
         (file (expand-file-name (format "%s-%s.md" (vibemacs-today) slug)
                                 directory)))
    (find-file file)
    (when (= (buffer-size) 0)
      (insert
       (vibemacs-agent-render-task-journal-entry title slug snapshot)))
    (current-buffer)))

(defun vibemacs-agent-insert-shipping-checklist ()
  "Insert the Vibemacs shipping checklist at point."
  (interactive)
  (insert (vibemacs-agent-shipping-checklist)))

(defun vibemacs-agent-apply-defaults ()
  "Install default Vibemacs agentic workflow bindings."
  (add-hook 'compilation-finish-functions #'vibemacs-agent--compilation-finished)
  (add-hook 'find-file-hook #'vibemacs-agent-maybe-enable-task-mode)
  (vibemacs-agent-load-session)
  (define-key vibemacs-prefix-map (kbd "RET") #'vibemacs-agent-open-cockpit)
  (define-key vibemacs-prefix-map (kbd "C") #'vibemacs-agent-dispatch-task-action)
  (define-key vibemacs-prefix-map (kbd "A") #'vibemacs-agent-open-current-task-next-actions)
  (define-key vibemacs-prefix-map (kbd "L") #'vibemacs-agent-insert-current-task-next-actions)
  (define-key vibemacs-prefix-map (kbd "a") #'vibemacs-agent-open-task)
  (define-key vibemacs-prefix-map (kbd "b") #'vibemacs-agent-open-task-board)
  (define-key vibemacs-prefix-map (kbd "r") #'vibemacs-agent-open-recent-task)
  (define-key vibemacs-prefix-map (kbd "p") #'vibemacs-agent-open-prompt-packet)
  (define-key vibemacs-prefix-map (kbd "P") #'vibemacs-agent-open-current-task-prompt)
  (define-key vibemacs-prefix-map (kbd "X") #'vibemacs-agent-insert-current-task-prompt)
  (define-key vibemacs-prefix-map (kbd "t") #'vibemacs-agent-open-transcript)
  (define-key vibemacs-prefix-map (kbd "T") #'vibemacs-agent-open-current-task-review)
  (define-key vibemacs-prefix-map (kbd "x") #'vibemacs-agent-open-context-packet)
  (define-key vibemacs-prefix-map (kbd "i") #'vibemacs-agent-open-artifact-index)
  (define-key vibemacs-prefix-map (kbd "f") #'vibemacs-agent-open-source-context)
  (define-key vibemacs-prefix-map (kbd "F") #'vibemacs-agent-open-current-task-final-response)
  (define-key vibemacs-prefix-map (kbd "I") #'vibemacs-agent-insert-current-task-final-response)
  (define-key vibemacs-prefix-map (kbd "S") #'vibemacs-agent-open-current-task-scope-audit)
  (define-key vibemacs-prefix-map (kbd "O") #'vibemacs-agent-insert-current-task-scope-audit)
  (define-key vibemacs-prefix-map (kbd "K") #'vibemacs-agent-open-current-task-risk-register)
  (define-key vibemacs-prefix-map (kbd "U") #'vibemacs-agent-insert-current-task-risk-register)
  (define-key vibemacs-prefix-map (kbd "M") #'vibemacs-agent-open-current-task-dependency-map)
  (define-key vibemacs-prefix-map (kbd "B") #'vibemacs-agent-insert-current-task-dependency-map)
  (define-key vibemacs-prefix-map (kbd "Q") #'vibemacs-agent-insert-task-review-checklist)
  (define-key vibemacs-prefix-map (kbd "d") #'vibemacs-agent-open-change-review)
  (define-key vibemacs-prefix-map (kbd "G") #'vibemacs-agent-open-current-task-verification-plan)
  (define-key vibemacs-prefix-map (kbd "N") #'vibemacs-agent-insert-current-task-verification-plan)
  (define-key vibemacs-prefix-map (kbd "v") #'vibemacs-agent-run-verification)
  (define-key vibemacs-prefix-map (kbd "V") #'vibemacs-agent-run-verification-suite)
  (define-key vibemacs-prefix-map (kbd "c") #'vibemacs-agent-start-cycle)
  (define-key vibemacs-prefix-map (kbd "j") #'vibemacs-agent-open-journal-entry)
  (define-key vibemacs-prefix-map (kbd "J") #'vibemacs-agent-open-task-journal-entry)
  (define-key vibemacs-prefix-map (kbd "s") #'vibemacs-agent-insert-shipping-checklist)
  (define-key vibemacs-prefix-map (kbd "w") #'vibemacs-agent-save-session)
  (define-key vibemacs-prefix-map (kbd "l") #'vibemacs-agent-load-session)
  (define-key vibemacs-prefix-map (kbd "y") #'vibemacs-agent-copy-handoff-bundle)
  (define-key vibemacs-prefix-map (kbd "e") #'vibemacs-agent-insert-latest-verification-evidence)
  (define-key vibemacs-prefix-map (kbd "E") #'vibemacs-agent-insert-verification-history-snapshot)
  (define-key vibemacs-prefix-map (kbd "k") #'vibemacs-agent-insert-task-checkpoint)
  (define-key vibemacs-prefix-map (kbd "h") #'vibemacs-agent-copy-current-task-handoff)
  (define-key vibemacs-prefix-map (kbd "H") #'vibemacs-agent-insert-current-task-handoff)
  (define-key vibemacs-prefix-map (kbd "D") #'vibemacs-agent-insert-task-decision)
  (define-key vibemacs-prefix-map (kbd "n") #'vibemacs-agent-next-task-checkbox)
  (define-key vibemacs-prefix-map (kbd "m") #'vibemacs-agent-toggle-task-checkbox)
  (define-key vibemacs-prefix-map (kbd "R") #'vibemacs-agent-open-task-readiness)
  (define-key vibemacs-prefix-map (kbd "W") #'vibemacs-agent-insert-task-readiness)
  (define-key vibemacs-prefix-map (kbd "o") #'vibemacs-agent-insert-task-closeout))

(provide 'vibemacs-agent)

;;; vibemacs-agent.el ends here
