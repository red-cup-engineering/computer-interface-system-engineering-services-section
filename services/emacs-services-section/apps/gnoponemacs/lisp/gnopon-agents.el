;;; gnopon-agents.el --- Explicit agentic programming workflows -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-markdown)
(require 'gnopon-lib)
(require 'gnopon-context)
(require 'ansi-color)
(require 'button)
(require 'term)
(require 'transient)

(defun gnopon/process-lines-safe (&rest args)
  "Run ARGS with `process-lines', returning output or an error string."
  (condition-case err
      (string-join (apply #'process-lines args) "\n")
    (error (format "unavailable: %s" (error-message-string err)))))

(defun gnopon/git-status-short ()
  "Return short Git status for the current project."
  (gnopon/process-lines-safe "git" "-C" (gnopon/project-root) "status" "--short"))

(defun gnopon/git-diff-stat ()
  "Return Git diff stat for the current project."
  (gnopon/process-lines-safe "git" "-C" (gnopon/project-root) "diff" "--stat"))

(defun gnopon/git-diff ()
  "Return unstaged Git diff for the current project."
  (gnopon/process-lines-safe "git" "-C" (gnopon/project-root) "diff"))

(defun gnopon/agent-context ()
  "Copy a Markdown agent context bundle to the kill ring."
  (interactive)
  (gnopon/copy-context-bundle))

(defun gnopon/agent-shell ()
  "Open a project-scoped comint buffer running `gnopon-agent-command'."
  (interactive)
  (let* ((default-directory (gnopon/project-root))
         (parts (split-string-shell-command gnopon-agent-command))
         (program (car parts))
         (args (cdr parts))
         (buffer (get-buffer-create (format "*agent:%s*" (file-name-nondirectory (directory-file-name default-directory))))))
    (unless program
      (user-error "No agent command configured"))
    (apply #'make-comint-in-buffer "agent" buffer program nil args)
    (pop-to-buffer buffer)))

(defcustom gnopon-codex-command "codex"
  "Project-scoped Codex command used by the Codex cockpit."
  :type 'string
  :group 'gnopon)

(defcustom gnopon-codex-resume-command "codex resume --last"
  "Project-scoped Codex command used to resume the latest session."
  :type 'string
  :group 'gnopon)

(defcustom gnopon-codex-resume-picker-command "codex resume"
  "Project-scoped Codex command used to open the resume picker."
  :type 'string
  :group 'gnopon)

(defcustom gnopon-codex-pass-project-root t
  "When non-nil, pass the current project root to Codex with `-C'."
  :type 'boolean
  :group 'gnopon)

(defcustom gnopon-codex-preserve-terminal-scrollback t
  "When non-nil, pass `--no-alt-screen' so Emacs can monitor Codex output."
  :type 'boolean
  :group 'gnopon)

(defcustom gnopon-codex-transcript-max-chars 120000
  "Maximum Codex terminal transcript characters captured into Markdown."
  :type 'integer
  :group 'gnopon)

(defcustom gnopon-codex-prompt-max-chars 60000
  "Maximum selected prompt characters sent to Codex from GnoponEmacs."
  :type 'integer
  :group 'gnopon)

(defcustom gnopon-codex-monitor-tail-chars 6000
  "Maximum Codex terminal tail characters shown in the chat monitor."
  :type 'integer
  :group 'gnopon)

(defcustom gnopon-codex-monitor-refresh-seconds 2
  "Seconds between Codex monitor refreshes when auto-refresh is enabled."
  :type 'number
  :group 'gnopon)

(defcustom gnopon-codex-cockpit-line-spacing 0.15
  "Buffer-local line spacing used by Codex cockpit Markdown surfaces."
  :type 'number
  :group 'gnopon)

(defvar-local gnopon-codex-dashboard-root nil
  "Project root represented by the current Codex dashboard buffer.")

(defvar-local gnopon-codex-monitor-root nil
  "Project root represented by the current Codex monitor buffer.")

(defvar-local gnopon-codex-monitor-timer nil
  "Buffer-local timer used for Codex monitor auto-refresh.")

(defvar-local gnopon-codex-composer-root nil
  "Project root represented by the current Codex prompt composer buffer.")

(defvar gnopon-codex-dashboard-actions
  '(("Open Codex terminal" . gnopon/codex-shell)
    ("Resume latest Codex session" . gnopon/codex-resume-last)
    ("Open Codex resume picker" . gnopon/codex-resume-picker)
    ("Resume Codex workspace" . gnopon/codex-resume-workspace)
    ("Resume picker workspace" . gnopon/codex-resume-picker-workspace)
    ("Open Codex monitor" . gnopon/codex-monitor)
    ("Open auto-refresh Codex monitor" . gnopon/codex-monitor-auto)
    ("Compose Codex prompt" . gnopon/codex-compose-prompt)
    ("Compose region prompt" . gnopon/codex-compose-region)
    ("Refresh dashboard" . gnopon/codex-dashboard-refresh)
    ("Send region to Codex" . gnopon/codex-send-region)
    ("Send buffer to Codex" . gnopon/codex-send-buffer)
    ("Send context bundle to Codex" . gnopon/codex-send-context-bundle)
    ("Copy context bundle" . gnopon/copy-context-bundle)
    ("Write context bundle" . gnopon/write-context-bundle)
    ("Open handoff" . gnopon/open-agent-handoff)
    ("Write handoff" . gnopon/write-agent-handoff)
    ("New session" . gnopon/start-agent-session)
    ("New Codex session" . gnopon/start-codex-session)
    ("Session index" . gnopon/agent-session-index)
    ("Open latest Codex evidence" . gnopon/open-latest-codex-evidence)
    ("Open latest Codex session" . gnopon/open-latest-codex-session)
    ("Open latest Codex prompt" . gnopon/open-latest-codex-prompt)
    ("Open latest Codex transcript" . gnopon/open-latest-codex-transcript)
    ("Capture Codex transcript" . gnopon/write-codex-transcript)
    ("Open Codex cockpit brief" . gnopon/codex-brief)
    ("Write Codex cockpit brief" . gnopon/write-codex-brief)
    ("Memory graph" . gnopon/markdown-link-graph-report)
    ("Formal validation" . gnopon/formal-cockpit)
    ("Project command matrix" . gnopon/project-command-matrix)
    ("Check project" . gnopon/check-project)
    ("Test project" . gnopon/test-project)
    ("Review diff" . gnopon/review-agent-diff)
    ("Capture command log" . gnopon/capture-command-log))
  "Interactive actions rendered in the Codex dashboard.")

(defvar gnopon-codex-monitor-actions
  '(("Refresh monitor" . gnopon/codex-monitor-refresh)
    ("Toggle auto-refresh" . gnopon/codex-monitor-toggle-auto-refresh)
    ("Open dashboard" . gnopon/codex-dashboard)
    ("Open Codex terminal" . gnopon/codex-shell)
    ("Resume latest Codex session" . gnopon/codex-resume-last)
    ("Open Codex resume picker" . gnopon/codex-resume-picker)
    ("Resume Codex workspace" . gnopon/codex-resume-workspace)
    ("Compose Codex prompt" . gnopon/codex-compose-prompt)
    ("Send context bundle to Codex" . gnopon/codex-send-context-bundle)
    ("Open latest Codex evidence" . gnopon/open-latest-codex-evidence)
    ("Open latest Codex brief" . gnopon/open-latest-codex-brief)
    ("Open latest Codex prompt" . gnopon/open-latest-codex-prompt)
    ("Open latest Codex transcript" . gnopon/open-latest-codex-transcript)
    ("Capture Codex transcript" . gnopon/write-codex-transcript)
    ("Write Codex cockpit brief" . gnopon/write-codex-brief)
    ("Memory graph" . gnopon/markdown-link-graph-report)
    ("Formal validation" . gnopon/formal-cockpit)
    ("Check project" . gnopon/check-project)
    ("Test project" . gnopon/test-project)
    ("Review diff" . gnopon/review-agent-diff))
  "Interactive actions rendered in the Codex monitor.")

(defvar gnopon-codex-dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'gnopon/codex-dashboard-refresh)
    (define-key map (kbd "z") #'gnopon/codex-workspace)
    (define-key map (kbd "Z") #'gnopon/codex-resume-workspace)
    (define-key map (kbd "j") #'gnopon/codex-resume-picker-workspace)
    (define-key map (kbd "J") #'gnopon/codex-resume-picker)
    (define-key map (kbd "s") #'gnopon/codex-shell)
    (define-key map (kbd "S") #'gnopon/codex-resume-last)
    (define-key map (kbd "A") #'gnopon/codex-monitor)
    (define-key map (kbd "R") #'gnopon/codex-monitor-auto)
    (define-key map (kbd "C") #'gnopon/codex-compose-prompt)
    (define-key map (kbd "p") #'gnopon/codex-send-region)
    (define-key map (kbd "P") #'gnopon/codex-send-buffer)
    (define-key map (kbd "b") #'gnopon/codex-send-context-bundle)
    (define-key map (kbd "c") #'gnopon/copy-context-bundle)
    (define-key map (kbd "w") #'gnopon/write-context-bundle)
    (define-key map (kbd "h") #'gnopon/open-agent-handoff)
    (define-key map (kbd "H") #'gnopon/write-agent-handoff)
    (define-key map (kbd "n") #'gnopon/start-agent-session)
    (define-key map (kbd "N") #'gnopon/start-codex-session)
    (define-key map (kbd "i") #'gnopon/agent-session-index)
    (define-key map (kbd "o e") #'gnopon/open-latest-codex-evidence)
    (define-key map (kbd "o s") #'gnopon/open-latest-codex-session)
    (define-key map (kbd "o b") #'gnopon/open-latest-codex-brief)
    (define-key map (kbd "o p") #'gnopon/open-latest-codex-prompt)
    (define-key map (kbd "o t") #'gnopon/open-latest-codex-transcript)
    (define-key map (kbd "T") #'gnopon/write-codex-transcript)
    (define-key map (kbd "O") #'gnopon/write-codex-brief)
    (define-key map (kbd "M") #'gnopon/markdown-link-graph-report)
    (define-key map (kbd "F") #'gnopon/formal-cockpit)
    (define-key map (kbd "X") #'gnopon/project-command-matrix)
    (define-key map (kbd "K") #'gnopon/check-project)
    (define-key map (kbd "V") #'gnopon/test-project)
    (define-key map (kbd "r") #'gnopon/review-agent-diff)
    (define-key map (kbd "l") #'gnopon/capture-command-log)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `gnopon-codex-dashboard-mode'.")

(define-minor-mode gnopon-codex-dashboard-mode
  "Minor mode for interactive Codex dashboard buffers."
  :lighter " CodexDash"
  :keymap gnopon-codex-dashboard-mode-map)

(defvar gnopon-codex-monitor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'gnopon/codex-monitor-refresh)
    (define-key map (kbd "R") #'gnopon/codex-monitor-toggle-auto-refresh)
    (define-key map (kbd "z") #'gnopon/codex-workspace)
    (define-key map (kbd "Z") #'gnopon/codex-resume-workspace)
    (define-key map (kbd "j") #'gnopon/codex-resume-picker-workspace)
    (define-key map (kbd "J") #'gnopon/codex-resume-picker)
    (define-key map (kbd "s") #'gnopon/codex-shell)
    (define-key map (kbd "S") #'gnopon/codex-resume-last)
    (define-key map (kbd "d") #'gnopon/codex-dashboard)
    (define-key map (kbd "e") #'gnopon/open-latest-codex-evidence)
    (define-key map (kbd "B") #'gnopon/open-latest-codex-brief)
    (define-key map (kbd "p") #'gnopon/open-latest-codex-prompt)
    (define-key map (kbd "t") #'gnopon/open-latest-codex-transcript)
    (define-key map (kbd "T") #'gnopon/write-codex-transcript)
    (define-key map (kbd "O") #'gnopon/write-codex-brief)
    (define-key map (kbd "b") #'gnopon/codex-send-context-bundle)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `gnopon-codex-monitor-mode'.")

(define-minor-mode gnopon-codex-monitor-mode
  "Minor mode for live Codex monitor buffers."
  :lighter " CodexMon"
  :keymap gnopon-codex-monitor-mode-map)

(defvar gnopon-codex-composer-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'gnopon/codex-send-composer)
    (define-key map (kbd "C-c C-k") #'gnopon/codex-kill-composer)
    (define-key map (kbd "C-c C-b") #'gnopon/codex-composer-insert-context-bundle)
    (define-key map (kbd "C-c C-r") #'gnopon/codex-composer-insert-region)
    (define-key map (kbd "C-c C-s") #'gnopon/codex-shell)
    (define-key map (kbd "C-c C-l") #'gnopon/codex-resume-last)
    (define-key map (kbd "C-c C-j") #'gnopon/codex-resume-picker)
    (define-key map (kbd "C-c C-a") #'gnopon/codex-monitor)
    map)
  "Keymap for `gnopon-codex-composer-mode'.")

(define-minor-mode gnopon-codex-composer-mode
  "Minor mode for editable Codex prompt composer buffers."
  :lighter " CodexCompose"
  :keymap gnopon-codex-composer-mode-map)

(defun gnopon/codex-polish-cockpit-buffer ()
  "Apply readable local presentation defaults to Codex cockpit buffers."
  (setq-local truncate-lines nil
              word-wrap t
              line-spacing gnopon-codex-cockpit-line-spacing
              show-trailing-whitespace nil)
  (visual-line-mode 1))

(defun gnopon/codex-term-name ()
  "Return the terminal process name for the current project's Codex buffer."
  (format "codex:%s"
          (file-name-nondirectory
           (directory-file-name (file-truename (gnopon/project-root))))))

(defun gnopon/codex-buffer-name ()
  "Return the current project's Codex terminal buffer name."
  (format "*%s*" (gnopon/codex-term-name)))

(defun gnopon/codex-command-has-project-root-p (parts)
  "Return non-nil when Codex command PARTS already include a project root."
  (or (member "-C" parts)
      (member "--cd" parts)))

(defun gnopon/codex-command-has-no-alt-screen-p (parts)
  "Return non-nil when Codex command PARTS already preserve terminal scrollback."
  (member "--no-alt-screen" parts))

(defun gnopon/codex-command-parts-for (command)
  "Return COMMAND split into program and args.
When `gnopon-codex-pass-project-root' is non-nil, append `-C' and the current
project root unless COMMAND already supplies `-C' or `--cd'.  When
`gnopon-codex-preserve-terminal-scrollback' is non-nil, append
`--no-alt-screen' unless COMMAND already supplies it."
  (let ((parts (split-string-shell-command command)))
    (unless (car parts)
      (user-error "No Codex command configured"))
    (when (and gnopon-codex-preserve-terminal-scrollback
               (not (gnopon/codex-command-has-no-alt-screen-p parts)))
      (setq parts (append parts (list "--no-alt-screen"))))
    (when (and gnopon-codex-pass-project-root
               (not (gnopon/codex-command-has-project-root-p parts)))
      (setq parts (append parts (list "-C" (file-truename (gnopon/project-root))))))
    parts))

(defun gnopon/codex-command-parts ()
  "Return `gnopon-codex-command' split into program and args."
  (gnopon/codex-command-parts-for gnopon-codex-command))

(defun gnopon/codex-process ()
  "Return the current project's Codex process, or nil."
  (when-let ((buffer (get-buffer (gnopon/codex-buffer-name))))
    (get-buffer-process buffer)))

(defun gnopon/codex-status ()
  "Return a symbolic status for the current project's Codex terminal."
  (let ((process (gnopon/codex-process)))
    (cond
     ((and process (process-live-p process)) 'running)
     (process 'stopped)
     (t 'not-started))))

(defun gnopon/codex-open-terminal (command)
  "Open or start the project-scoped Codex terminal with COMMAND."
  (let* ((default-directory (gnopon/project-root))
         (parts (gnopon/codex-command-parts-for command))
         (program (car parts))
         (args (cdr parts))
         (buffer-name (gnopon/codex-buffer-name))
         (buffer (get-buffer buffer-name))
         (process (and buffer (get-buffer-process buffer))))
    (unless (executable-find program)
      (user-error "Codex command is not executable: %s" program))
    (if (and buffer (process-live-p process))
        (pop-to-buffer buffer)
      (when buffer
        (kill-buffer buffer))
      (setq buffer (apply #'make-term (gnopon/codex-term-name) program nil args))
      (with-current-buffer buffer
        (rename-buffer buffer-name t)
        (term-mode)
        (term-char-mode))
      (pop-to-buffer buffer))))

(defun gnopon/codex-shell ()
  "Open or start a fresh project-scoped Codex terminal."
  (interactive)
  (gnopon/codex-open-terminal gnopon-codex-command))

(defun gnopon/codex-resume-last ()
  "Resume the latest Codex session in the project-scoped terminal."
  (interactive)
  (gnopon/codex-open-terminal gnopon-codex-resume-command))

(defun gnopon/codex-resume-picker ()
  "Open Codex's interactive session picker in the project-scoped terminal."
  (interactive)
  (gnopon/codex-open-terminal gnopon-codex-resume-picker-command))

(defun gnopon/codex-source-label ()
  "Return a compact source label for the current buffer."
  (cond
   ((and buffer-file-name (file-in-directory-p buffer-file-name (gnopon/project-root)))
    (file-relative-name buffer-file-name (gnopon/project-root)))
   (buffer-file-name
    (file-truename buffer-file-name))
   (t
    (buffer-name))))

(defun gnopon/codex-line-range-label (start end)
  "Return a line range label for START and END."
  (format "%s-%s"
          (line-number-at-pos start t)
          (line-number-at-pos end t)))

(defun gnopon/codex-prompt-text (text source scope)
  "Return a redacted prompt packet for Codex.
TEXT is the selected context, SOURCE names its origin, and SCOPE describes the
selection kind."
  (let* ((redacted (gnopon/redact-secrets text))
         (truncated (gnopon/truncate-text redacted gnopon-codex-prompt-max-chars)))
    (concat "GnoponEmacs focused prompt\n\n"
            "- project: `" (file-truename (gnopon/project-root)) "`\n"
            "- source: `" source "`\n"
            "- scope: `" scope "`\n"
            "- redaction: `gnopon/redact-secrets`\n"
            "- chars: `" (number-to-string (length truncated)) "`\n\n"
            "```text\n"
            truncated
            "\n```\n")))

(defun gnopon/codex-prompt-path ()
  "Return a project-local path for a Codex prompt evidence record."
  (let ((dir (gnopon/project-file "logs/agent/")))
    (make-directory dir t)
    (expand-file-name
     (format "%s-codex-prompt.md" (format-time-string "%Y%m%d-%H%M%S"))
     dir)))

(defun gnopon/codex-prompt-record-text (prompt)
  "Return a Markdown evidence record for a sent Codex PROMPT."
  (concat "# Codex Prompt\n\n"
          "- project: `" (file-truename (gnopon/project-root)) "`\n"
          "- created: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
          "- codex-command: `" gnopon-codex-command "`\n"
          "- chat-buffer: `" (gnopon/codex-buffer-name) "`\n"
          "- chat-status: `" (format "%s" (gnopon/codex-status)) "`\n"
          "- chars: `" (number-to-string (length prompt)) "`\n"
          "- redaction: `gnopon/redact-secrets`\n\n"
          "## Prompt\n\n"
          prompt))

(defun gnopon/write-codex-prompt-record (prompt)
  "Write PROMPT as a Codex prompt evidence record under `logs/agent/'."
  (let ((path (gnopon/codex-prompt-path)))
    (with-temp-file path
      (insert (gnopon/codex-prompt-record-text prompt)))
    path))

(defun gnopon/codex-send-prompt (prompt)
  "Send PROMPT to the project Codex terminal after explicit confirmation."
  (unless (yes-or-no-p
           (format "Send %d redacted characters to %s? "
                   (length prompt)
                   (gnopon/codex-buffer-name)))
    (user-error "Canceled"))
  (let ((process (gnopon/codex-process)))
    (unless (and process (process-live-p process))
      (gnopon/codex-shell)))
  (let ((process (gnopon/codex-process)))
    (unless (process-live-p process)
      (user-error "Codex process is not live"))
    (let ((path (gnopon/write-codex-prompt-record prompt)))
      (message "Recorded Codex prompt in %s" path))
    (process-send-string process (concat prompt "\n"))
    (pop-to-buffer (process-buffer process))))

(defun gnopon/codex-send-region (start end)
  "Send the active region to the project Codex terminal as a redacted prompt."
  (interactive "r")
  (unless (use-region-p)
    (user-error "No active region"))
  (gnopon/codex-send-prompt
   (gnopon/codex-prompt-text
    (buffer-substring-no-properties start end)
    (gnopon/codex-source-label)
    (format "region:%s" (gnopon/codex-line-range-label start end)))))

(defun gnopon/codex-send-buffer ()
  "Send the current buffer to the project Codex terminal as a redacted prompt."
  (interactive)
  (gnopon/codex-send-prompt
   (gnopon/codex-prompt-text
    (buffer-substring-no-properties (point-min) (point-max))
    (gnopon/codex-source-label)
    "buffer")))

(defun gnopon/codex-send-context-bundle ()
  "Send the generated project context bundle to the project Codex terminal."
  (interactive)
  (gnopon/codex-send-prompt
   (gnopon/codex-prompt-text
    (gnopon/context-bundle "Codex Context Bundle")
    "gnopon/context-bundle"
    "project-context-bundle")))

(defun gnopon/codex-composer-buffer-name ()
  "Return the current project's Codex prompt composer buffer name."
  (format "*codex-compose:%s*"
          (file-name-nondirectory
           (directory-file-name (file-truename (gnopon/project-root))))))

(defun gnopon/codex-composer-template (&optional seed source scope)
  "Return a Markdown Codex prompt composer template.
Optional SEED is inserted under the prompt section.  SOURCE and SCOPE describe
the initial material."
  (concat "# Codex Prompt Composer\n\n"
          "- project: `" (file-truename (gnopon/project-root)) "`\n"
          "- created: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
          "- codex-buffer: `" (gnopon/codex-buffer-name) "`\n"
          "- source: `" (or source "manual") "`\n"
          "- scope: `" (or scope "composer") "`\n\n"
          "## Preflight\n\n"
          "- [ ] Prompt is scoped to the current project state.\n"
          "- [ ] Secrets and local-only data were removed or are safe after redaction.\n"
          "- [ ] Expected evidence/check/test output is named when relevant.\n\n"
          "## Prompt\n\n"
          (or seed "")
          "\n\n"
          "## Reference\n\n"
          "- Send with `C-c C-c`.\n"
          "- Insert project context with `C-c C-b`.\n"
          "- Insert active region with `C-c C-r`.\n"
          "- Open Codex with `C-c C-s`; open monitor with `C-c C-a`.\n"
          "- Resume latest Codex with `C-c C-l`.\n"))

(defun gnopon/codex-composer-prompt-region ()
  "Return the bounds of the prompt section in the current composer buffer."
  (save-excursion
    (goto-char (point-min))
    (unless (re-search-forward "^## Prompt\\b" nil t)
      (user-error "Composer has no ## Prompt section"))
    (forward-line 1)
    (let ((start (progn
                   (while (and (not (eobp)) (looking-at-p "\\s-*$"))
                     (forward-line 1))
                   (point)))
          (end (or (and (re-search-forward "^## " nil t)
                        (match-beginning 0))
                   (point-max))))
      (cons start end))))

(defun gnopon/codex-composer-prompt ()
  "Return the non-empty prompt section from the current composer buffer."
  (let* ((bounds (gnopon/codex-composer-prompt-region))
         (prompt (string-trim
                  (buffer-substring-no-properties (car bounds) (cdr bounds)))))
    (when (string-empty-p prompt)
      (user-error "Composer prompt section is empty"))
    prompt))

(defun gnopon/codex-compose-prompt (&optional seed source scope)
  "Open an editable Markdown prompt composer for Codex.
Optional SEED, SOURCE, and SCOPE prefill the prompt section."
  (interactive)
  (let* ((root (file-name-as-directory (file-truename (gnopon/project-root))))
         (buffer (get-buffer-create (gnopon/codex-composer-buffer-name))))
    (with-current-buffer buffer
      (let ((default-directory root))
        (erase-buffer)
        (insert (gnopon/codex-composer-template seed source scope))
        (gnopon/markdown-buffer-mode)
        (gnopon/codex-polish-cockpit-buffer)
        (gnopon-codex-composer-mode 1)
        (setq-local gnopon-codex-composer-root root)
        (goto-char (point-min))
        (re-search-forward "^## Prompt\\b" nil t)
        (forward-line 2)))
    (pop-to-buffer buffer)))

(defun gnopon/codex-compose-region (start end)
  "Open a Codex prompt composer seeded with the active region."
  (interactive "r")
  (unless (use-region-p)
    (user-error "No active region"))
  (gnopon/codex-compose-prompt
   (buffer-substring-no-properties start end)
   (gnopon/codex-source-label)
   (format "region:%s" (gnopon/codex-line-range-label start end))))

(defun gnopon/codex-composer-insert-context-bundle ()
  "Insert a redacted project context bundle at point in the composer."
  (interactive)
  (unless gnopon-codex-composer-root
    (user-error "Current buffer is not a Codex prompt composer"))
  (insert "\n\n"
          (gnopon/context-bundle "Codex Composer Context Bundle")
          "\n"))

(defun gnopon/codex-composer-insert-region (start end)
  "Insert the active region at point in the composer."
  (interactive "r")
  (unless gnopon-codex-composer-root
    (user-error "Current buffer is not a Codex prompt composer"))
  (unless (use-region-p)
    (user-error "No active region"))
  (insert "\n\n```text\n"
          (gnopon/redact-secrets
           (buffer-substring-no-properties start end))
          "\n```\n"))

(defun gnopon/codex-send-composer ()
  "Send the current composer prompt to Codex as a redacted evidence packet."
  (interactive)
  (unless gnopon-codex-composer-root
    (user-error "Current buffer is not a Codex prompt composer"))
  (let ((default-directory gnopon-codex-composer-root)
        (prompt (gnopon/codex-composer-prompt)))
    (gnopon/codex-send-prompt
     (gnopon/codex-prompt-text prompt "codex-composer" "composer"))))

(defun gnopon/codex-kill-composer ()
  "Kill the current Codex prompt composer buffer after confirmation."
  (interactive)
  (unless gnopon-codex-composer-root
    (user-error "Current buffer is not a Codex prompt composer"))
  (when (yes-or-no-p "Discard Codex prompt composer? ")
    (kill-buffer (current-buffer))))

(defun gnopon/codex-transcript-raw-text ()
  "Return the raw text of the project Codex terminal buffer."
  (let ((buffer (get-buffer (gnopon/codex-buffer-name))))
    (unless buffer
      (user-error "No Codex buffer for this project"))
    (with-current-buffer buffer
      (buffer-substring-no-properties (point-min) (point-max)))))

(defun gnopon/codex-normalize-terminal-text (text)
  "Return terminal TEXT normalized for Markdown evidence buffers.
ANSI color/control sequences, carriage returns, and non-printing control
characters are removed so Codex monitor and transcript buffers stay readable."
  (let ((normalized (ansi-color-filter-apply text)))
    (setq normalized
          (replace-regexp-in-string "\r\n?" "\n" normalized))
    (setq normalized
          (replace-regexp-in-string "\x1b\\][^\x07\x1b]*\\(\x07\\|\x1b\\\\\\)" "" normalized))
    (setq normalized
          (replace-regexp-in-string "\x1b\\[[0-?]*[ -/]*[@-~]" "" normalized))
    (setq normalized
          (replace-regexp-in-string "\x1b." "" normalized))
    (replace-regexp-in-string "[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]" "" normalized)))

(defun gnopon/codex-transcript-path ()
  "Return a project-local path for a captured Codex transcript."
  (let ((dir (gnopon/project-file "logs/agent/")))
    (make-directory dir t)
    (expand-file-name
     (format "%s-codex-transcript.md" (format-time-string "%Y%m%d-%H%M%S"))
     dir)))

(defun gnopon/codex-transcript-text (&optional transcript)
  "Return a redacted Markdown Codex transcript packet.
Optional TRANSCRIPT is raw terminal text; when omitted, use the project Codex
terminal buffer."
  (let* ((raw (or transcript (gnopon/codex-transcript-raw-text)))
         (normalized (gnopon/codex-normalize-terminal-text raw))
         (redacted (gnopon/redact-secrets normalized))
         (truncated (gnopon/truncate-text redacted gnopon-codex-transcript-max-chars)))
    (concat "# Codex Transcript\n\n"
            "- project: `" (file-truename (gnopon/project-root)) "`\n"
            "- created: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
            "- codex-command: `" gnopon-codex-command "`\n"
            "- chat-buffer: `" (gnopon/codex-buffer-name) "`\n"
            "- chat-status: `" (format "%s" (gnopon/codex-status)) "`\n"
            "- raw-chars: `" (number-to-string (length raw)) "`\n"
            "- normalized-chars: `" (number-to-string (length normalized)) "`\n"
            "- captured-chars: `" (number-to-string (length truncated)) "`\n"
            "- terminal-normalization: `ansi/control stripped`\n"
            "- redaction: `gnopon/redact-secrets`\n\n"
            "## Transcript\n\n```text\n"
            truncated
            "\n```\n")))

(defun gnopon/write-codex-transcript ()
  "Write the current project Codex terminal transcript under `logs/agent/'."
  (interactive)
  (let ((path (gnopon/codex-transcript-path)))
    (with-temp-file path
      (insert (gnopon/codex-transcript-text)))
    (find-file path)
    path))

(defun gnopon/codex-session-count ()
  "Return the number of project-local Codex session records."
  (length (gnopon/codex-session-files)))

(defun gnopon/codex-session-files ()
  "Return project-local Codex session filenames, newest first."
  (sort
   (seq-filter (lambda (file)
                 (and (string-match-p "-codex-" file)
                      (not (string-match-p "-codex-\\(prompt\\|transcript\\|brief\\)\\.md\\'" file))))
               (directory-files (gnopon/agent-session-dir) nil "\\.md\\'"))
   #'string>))

(defun gnopon/open-latest-codex-session ()
  "Open the newest project-local Codex session record."
  (interactive)
  (find-file (expand-file-name
              (or (car (gnopon/codex-session-files))
              (user-error "No Codex session records in %s" (gnopon/agent-session-dir)))
              (gnopon/agent-session-dir))))

(defun gnopon/codex-evidence-files ()
  "Return project-local Codex evidence filenames, newest first."
  (sort (append (gnopon/codex-session-files)
                (gnopon/codex-log-files "-codex-prompt\\.md\\'")
                (gnopon/codex-log-files "-codex-transcript\\.md\\'")
                (gnopon/codex-log-files "-codex-brief\\.md\\'"))
        #'string>))

(defun gnopon/codex-latest-evidence-path (&optional no-error)
  "Return the newest Codex evidence path for the project.
When NO-ERROR is non-nil, return nil instead of signaling when no evidence
exists."
  (if-let ((file (car (gnopon/codex-evidence-files))))
      (expand-file-name file (gnopon/agent-session-dir))
    (unless no-error
      (user-error "No Codex evidence records in %s" (gnopon/agent-session-dir)))))

(defun gnopon/open-latest-codex-evidence ()
  "Open the newest project-local Codex session, prompt, transcript, or brief."
  (interactive)
  (find-file (gnopon/codex-latest-evidence-path)))

(defun gnopon/codex-log-count (regexp)
  "Return the number of project-local agent log files matching REGEXP."
  (length (directory-files (gnopon/agent-session-dir) nil regexp)))

(defun gnopon/codex-log-files (regexp)
  "Return project-local agent log filenames matching REGEXP, newest first."
  (sort (directory-files (gnopon/agent-session-dir) nil regexp) #'string>))

(defun gnopon/codex-latest-log-file (regexp kind)
  "Return the latest project-local Codex log matching REGEXP.
KIND is used in the user-facing error message."
  (or (car (gnopon/codex-log-files regexp))
      (user-error "No Codex %s records in %s" kind (gnopon/agent-session-dir))))

(defun gnopon/open-latest-codex-prompt ()
  "Open the newest project-local Codex prompt record."
  (interactive)
  (find-file (expand-file-name
              (gnopon/codex-latest-log-file "-codex-prompt\\.md\\'" "prompt")
              (gnopon/agent-session-dir))))

(defun gnopon/open-latest-codex-transcript ()
  "Open the newest project-local Codex transcript record."
  (interactive)
  (find-file (expand-file-name
              (gnopon/codex-latest-log-file "-codex-transcript\\.md\\'" "transcript")
              (gnopon/agent-session-dir))))

(defun gnopon/open-latest-codex-brief ()
  "Open the newest project-local Codex cockpit brief."
  (interactive)
  (find-file (expand-file-name
              (gnopon/codex-latest-log-file "-codex-brief\\.md\\'" "brief")
              (gnopon/agent-session-dir))))

(defun gnopon/codex-file-or-none (file)
  "Return FILE as a Markdown code span, or a `none' marker."
  (format "`%s`" (or file "none")))

(defun gnopon/codex-latest-evidence-file ()
  "Return the newest Codex evidence filename, or nil."
  (car (gnopon/codex-evidence-files)))

(defun gnopon/codex-command-executable-path (command)
  "Return the executable path for Codex COMMAND, or nil."
  (when-let ((program (car (condition-case nil
                              (gnopon/codex-command-parts-for command)
                            (error nil)))))
    (executable-find program)))

(defun gnopon/codex-executable-path ()
  "Return the configured Codex executable path, or nil."
  (gnopon/codex-command-executable-path gnopon-codex-command))

(defun gnopon/codex-context-file-count ()
  "Return the number of readable standard context files in the project."
  (let ((root (gnopon/project-root)))
    (length
     (seq-filter (lambda (file)
                   (file-readable-p (expand-file-name file root)))
                 gnopon-context-files))))

(defun gnopon/codex-readiness-checks ()
  "Return structured readiness checks for the project Codex cockpit."
  (let* ((executable (gnopon/codex-executable-path))
         (resume-executable (gnopon/codex-command-executable-path gnopon-codex-resume-command))
         (picker-executable (gnopon/codex-command-executable-path gnopon-codex-resume-picker-command))
         (status (gnopon/codex-status))
         (context-ready (gnopon/codex-context-file-count))
         (context-total (length gnopon-context-files))
         (prompt-count (gnopon/codex-log-count "-codex-prompt\\.md\\'"))
         (transcript-count (gnopon/codex-log-count "-codex-transcript\\.md\\'"))
         (brief-count (gnopon/codex-log-count "-codex-brief\\.md\\'"))
         (session-count (gnopon/codex-session-count))
         (chat-chars (or (gnopon/codex-transcript-buffer-chars) 0)))
    `(((label . "Codex executable")
       (ready . ,(and executable t))
       (detail . ,(or executable "install codex or set gnopon-codex-command")))
      ((label . "Chat terminal")
       (ready . ,(eq status 'running))
       (detail . ,(if (eq status 'running)
                      (format "running in %s" (gnopon/codex-buffer-name))
                    (format "%s; open C-c g a S" status))))
      ((label . "Codex resume")
       (ready . ,(and resume-executable t))
       (detail . ,(if resume-executable
                      (format "%s via C-c g a L" gnopon-codex-resume-command)
                    "install codex or set gnopon-codex-resume-command")))
      ((label . "Codex resume picker")
       (ready . ,(and picker-executable t))
       (detail . ,(if picker-executable
                      (format "%s via C-c g a J" gnopon-codex-resume-picker-command)
                    "install codex or set gnopon-codex-resume-picker-command")))
      ((label . "Monitor scrollback")
       (ready . ,gnopon-codex-preserve-terminal-scrollback)
       (detail . ,(if gnopon-codex-preserve-terminal-scrollback
                      "--no-alt-screen enabled for monitorable chat output"
                    "enable gnopon-codex-preserve-terminal-scrollback")))
      ((label . "Terminal normalization")
       (ready . t)
       (detail . "ANSI and control sequences stripped before Markdown capture"))
      ((label . "Context memory")
       (ready . ,(> context-ready 0))
       (detail . ,(format "%s/%s standard Markdown files readable"
                          context-ready context-total)))
      ((label . "Prompt evidence")
       (ready . ,(> prompt-count 0))
       (detail . ,(if (> prompt-count 0)
                      (format "%s prompt record(s)" prompt-count)
                    "send a prompt or composer packet")))
      ((label . "Transcript evidence")
       (ready . ,(> transcript-count 0))
       (detail . ,(if (> transcript-count 0)
                      (format "%s transcript record(s)" transcript-count)
                    "capture transcript with C-c g a T")))
      ((label . "Cockpit brief")
       (ready . ,(> brief-count 0))
       (detail . ,(if (> brief-count 0)
                      (format "%s brief record(s)" brief-count)
                    "write a cockpit brief with C-c g a k")))
      ((label . "Codex sessions")
       (ready . ,(> session-count 0))
       (detail . ,(if (> session-count 0)
                      (format "%s Codex session record(s)" session-count)
                    "create one with C-c g a N")))
      ((label . "Chat transcript")
       (ready . ,(> chat-chars 0))
       (detail . ,(if (> chat-chars 0)
                      (format "%s terminal character(s)" chat-chars)
                    "no terminal text captured yet"))))))

(defun gnopon/codex-readiness-line (check)
  "Return one Markdown task line for readiness CHECK."
  (format "- [%s] %s: %s\n"
          (if (alist-get 'ready check) "x" " ")
          (alist-get 'label check)
          (alist-get 'detail check)))

(defun gnopon/codex-readiness-section ()
  "Return a Markdown readiness section for the Codex cockpit."
  (concat "## Codex Readiness\n\n"
          (mapconcat #'gnopon/codex-readiness-line
                     (gnopon/codex-readiness-checks)
                     "")
          "\n"))

(defun gnopon/codex-state-label (value)
  "Return VALUE formatted as a compact Markdown string."
  (format "`%s`" value))

(defun gnopon/codex-at-a-glance-section ()
  "Return a compact Markdown summary for Codex cockpit orientation."
  (let ((latest-evidence (or (gnopon/codex-latest-evidence-file) "none"))
        (chat-chars (or (gnopon/codex-transcript-buffer-chars) 0))
        (context-ready (gnopon/codex-context-file-count))
        (context-total (length gnopon-context-files)))
    (concat "## At A Glance\n\n"
            "| Signal | State |\n"
            "| --- | --- |\n"
            "| Chat | " (gnopon/codex-state-label (format "%s" (gnopon/codex-status))) " |\n"
            "| Scrollback | " (gnopon/codex-state-label (if gnopon-codex-preserve-terminal-scrollback "monitorable" "alternate-screen")) " |\n"
            "| Context memory | " (gnopon/codex-state-label (format "%s/%s files" context-ready context-total)) " |\n"
            "| Latest evidence | `" latest-evidence "` |\n"
            "| Chat text | " (gnopon/codex-state-label (format "%s chars" chat-chars)) " |\n\n"
            "## Next Moves\n\n"
            "- Resume latest session: `C-c g a L` or local `S`.\n"
            "- Open picker workspace: `C-c g a j` or local `j`.\n"
            "- Compose a scoped prompt: `C-c g a q` or local `C`.\n"
            "- Write the shared cockpit brief: `C-c g a k` or local `O`.\n"
            "- Capture a transcript when the exchange matters: `C-c g a T` or local `T`.\n\n")))

(defun gnopon/codex-transcript-tail-text ()
  "Return a redacted tail of the project Codex terminal buffer."
  (if-let ((buffer (get-buffer (gnopon/codex-buffer-name))))
      (with-current-buffer buffer
        (let* ((end (point-max))
               (start (max (point-min) (- end gnopon-codex-monitor-tail-chars))))
          (gnopon/redact-secrets
           (gnopon/codex-normalize-terminal-text
            (buffer-substring-no-properties start end)))))
    "No Codex terminal buffer for this project."))

(defun gnopon/codex-monitor-buffer-name ()
  "Return the current project's Codex monitor buffer name."
  (format "*codex-monitor:%s*"
          (file-name-nondirectory
           (directory-file-name (file-truename (gnopon/project-root))))))

(defun gnopon/codex-monitor-auto-refresh-active-p ()
  "Return non-nil when the current Codex monitor auto-refreshes."
  (and gnopon-codex-monitor-timer
       (timerp gnopon-codex-monitor-timer)))

(defun gnopon/codex-monitor-auto-refresh-status ()
  "Return a Markdown status string for Codex monitor auto-refresh."
  (if (gnopon/codex-monitor-auto-refresh-active-p)
      (format "enabled every %ss" gnopon-codex-monitor-refresh-seconds)
    "disabled"))

(defun gnopon/codex-monitor-text ()
  "Return a Markdown live monitor for the project Codex chat window."
  (let* ((root (file-truename (gnopon/project-root)))
         (tail (gnopon/codex-transcript-tail-text)))
    (concat "# Codex Chat Monitor\n\n"
            "- project: `" root "`\n"
            "- refreshed: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
            "- chat-buffer: `" (gnopon/codex-buffer-name) "`\n"
            "- chat-status: `" (format "%s" (gnopon/codex-status)) "`\n"
            "- chat-buffer-chars: `" (number-to-string (or (gnopon/codex-transcript-buffer-chars) 0)) "`\n"
            "- tail-chars: `" (number-to-string (length tail)) "`\n\n"
            "- terminal-normalization: `ansi/control stripped`\n"
            "- auto-refresh: `" (gnopon/codex-monitor-auto-refresh-status) "`\n"
            "- auto-refresh-toggle: `R`\n\n"
            (gnopon/codex-at-a-glance-section)
            "## Live Chat Tail\n\n```text\n"
            tail
            "\n```\n\n"
            (gnopon/codex-evidence-cursor-section)
            (gnopon/codex-readiness-section)
            "## Left Hand: Lawfulness\n\n"
            "- memory graph: `C-c g m g`\n"
            "- formal validation: `C-c g m F`\n"
            "- context bundle: `C-c g a C`\n\n"
            "## Right Hand: Conformance\n\n"
            "- command matrix: `C-c g p m`\n"
            "- check project: `C-c g p c`\n"
            "- test project: `C-c g p t`\n"
            "- review diff: `C-c g a r`\n\n"
            "## Monitor Keys\n\n"
            "- `g`: refresh monitor\n"
            "- `R`: toggle auto-refresh\n"
            "- `z`: restore cockpit workspace\n"
            "- `Z`: resume cockpit workspace\n"
            "- `j`: resume picker workspace\n"
            "- `J`: open resume picker\n"
            "- `s`: open Codex terminal\n"
            "- `S`: resume latest Codex session\n"
            "- `d`: show dashboard\n"
            "- `b`: send context bundle to Codex\n"
            "- `B`: open latest brief\n"
            "- `e`: open latest evidence\n"
            "- `p`: open latest prompt\n"
            "- `t`: open latest transcript\n"
            "- `T`: capture transcript\n"
            "- `O`: write cockpit brief\n")))

(defun gnopon/codex-monitor-clear-auto-refresh ()
  "Cancel the current buffer's Codex monitor timer without repainting."
  (when (gnopon/codex-monitor-auto-refresh-active-p)
    (cancel-timer gnopon-codex-monitor-timer))
  (setq-local gnopon-codex-monitor-timer nil))

(defun gnopon/codex-monitor-render (&optional root)
  "Render the Codex monitor for ROOT into the current buffer."
  (let ((default-directory (file-name-as-directory (or root (gnopon/project-root))))
        (timer gnopon-codex-monitor-timer))
    (read-only-mode -1)
    (erase-buffer)
    (setq-local gnopon-codex-monitor-root default-directory)
    (insert (gnopon/codex-monitor-text))
    (gnopon/markdown-buffer-mode)
    (gnopon/codex-polish-cockpit-buffer)
    (add-hook 'kill-buffer-hook #'gnopon/codex-monitor-clear-auto-refresh nil t)
    (goto-char (point-max))
    (gnopon/codex-monitor-insert-actions)
    (gnopon-codex-monitor-mode 1)
    (setq-local gnopon-codex-monitor-root default-directory)
    (setq-local gnopon-codex-monitor-timer timer)
    (goto-char (point-min))
    (read-only-mode 1)))

(defun gnopon/codex-monitor-buffer (&optional root)
  "Return a rendered Codex monitor buffer for ROOT."
  (let* ((default-directory (file-name-as-directory (or root (gnopon/project-root))))
         (buffer (get-buffer-create (gnopon/codex-monitor-buffer-name))))
    (with-current-buffer buffer
      (gnopon/codex-monitor-render default-directory))
    buffer))

(defun gnopon/codex-monitor-refresh ()
  "Refresh the current Codex monitor buffer."
  (interactive)
  (unless gnopon-codex-monitor-root
    (user-error "Current buffer is not a Codex monitor"))
  (gnopon/codex-monitor-render gnopon-codex-monitor-root))

(defun gnopon/codex-monitor-start-auto-refresh ()
  "Start auto-refresh for the current Codex monitor buffer."
  (interactive)
  (unless gnopon-codex-monitor-root
    (user-error "Current buffer is not a Codex monitor"))
  (gnopon/codex-monitor-clear-auto-refresh)
  (let ((buffer (current-buffer))
        (root gnopon-codex-monitor-root)
        timer)
    (setq timer
          (run-at-time
           gnopon-codex-monitor-refresh-seconds
           gnopon-codex-monitor-refresh-seconds
           (lambda ()
             (if (buffer-live-p buffer)
                 (with-current-buffer buffer
                   (when gnopon-codex-monitor-root
                     (gnopon/codex-monitor-render root)))
               (cancel-timer timer)))))
    (setq-local gnopon-codex-monitor-timer timer)
    (gnopon/codex-monitor-render root)
    (message "Codex monitor auto-refresh enabled every %ss"
             gnopon-codex-monitor-refresh-seconds)))

(defun gnopon/codex-monitor-stop-auto-refresh ()
  "Stop auto-refresh for the current Codex monitor buffer."
  (interactive)
  (let ((root gnopon-codex-monitor-root))
    (gnopon/codex-monitor-clear-auto-refresh)
    (when root
      (gnopon/codex-monitor-render root)))
  (message "Codex monitor auto-refresh disabled"))

(defun gnopon/codex-monitor-toggle-auto-refresh ()
  "Toggle auto-refresh for the current Codex monitor buffer."
  (interactive)
  (if (gnopon/codex-monitor-auto-refresh-active-p)
      (gnopon/codex-monitor-stop-auto-refresh)
    (gnopon/codex-monitor-start-auto-refresh)))

(defun gnopon/codex-monitor-button (label command)
  "Insert a Codex monitor button with LABEL calling COMMAND."
  (insert-text-button label
                      'follow-link t
                      'action (lambda (_button)
                                (let ((default-directory
                                       (or gnopon-codex-monitor-root default-directory)))
                                  (call-interactively command))))
  (insert "\n"))

(defun gnopon/codex-monitor-insert-actions ()
  "Insert live action buttons for the current Codex monitor buffer."
  (insert "\n## Live Actions\n\n")
  (dolist (action gnopon-codex-monitor-actions)
    (gnopon/codex-monitor-button (car action) (cdr action)))
  (insert "\n"))

(defun gnopon/codex-monitor ()
  "Open a Markdown monitor for the live Codex chat window."
  (interactive)
  (pop-to-buffer (gnopon/codex-monitor-buffer)))

(defun gnopon/codex-monitor-auto ()
  "Open the Codex monitor and enable auto-refresh."
  (interactive)
  (pop-to-buffer (gnopon/codex-monitor-buffer))
  (gnopon/codex-monitor-start-auto-refresh))

(defun gnopon/codex-recent-evidence-lines ()
  "Return Markdown list items for recent Codex evidence files."
  (let ((files (seq-take
                (sort (append (gnopon/codex-log-files "-codex-prompt\\.md\\'")
                              (gnopon/codex-log-files "-codex-transcript\\.md\\'")
                              (gnopon/codex-log-files "-codex-brief\\.md\\'"))
                      #'string>)
                6)))
    (if files
        (mapconcat (lambda (file) (format "- `%s`\n" file)) files "")
      "- none\n")))

(defun gnopon/codex-evidence-cursor-section ()
  "Return a Markdown section for the current Codex evidence cursor."
  (let ((latest-session (car (gnopon/codex-session-files)))
        (latest-prompt (car (gnopon/codex-log-files "-codex-prompt\\.md\\'")))
        (latest-transcript (car (gnopon/codex-log-files "-codex-transcript\\.md\\'")))
        (latest-brief (car (gnopon/codex-log-files "-codex-brief\\.md\\'")))
        (latest-evidence (gnopon/codex-latest-evidence-file)))
    (concat "## Evidence Cursor\n\n"
            "- latest-evidence: " (gnopon/codex-file-or-none latest-evidence) "\n"
            "- latest-session: " (gnopon/codex-file-or-none latest-session) "\n"
            "- latest-prompt: " (gnopon/codex-file-or-none latest-prompt) "\n"
            "- latest-transcript: " (gnopon/codex-file-or-none latest-transcript) "\n"
            "- latest-brief: " (gnopon/codex-file-or-none latest-brief) "\n"
            "- prompt-records: `" (number-to-string (gnopon/codex-log-count "-codex-prompt\\.md\\'")) "`\n"
            "- transcript-records: `" (number-to-string (gnopon/codex-log-count "-codex-transcript\\.md\\'")) "`\n"
            "- brief-records: `" (number-to-string (gnopon/codex-log-count "-codex-brief\\.md\\'")) "`\n\n")))

(defun gnopon/codex-evidence-section ()
  "Return a Markdown section summarizing Codex evidence artifacts."
  (concat "## Codex Evidence\n\n"
          "- prompt-records: `" (number-to-string (gnopon/codex-log-count "-codex-prompt\\.md\\'")) "`\n"
          "- transcript-records: `" (number-to-string (gnopon/codex-log-count "-codex-transcript\\.md\\'")) "`\n"
          "- brief-records: `" (number-to-string (gnopon/codex-log-count "-codex-brief\\.md\\'")) "`\n"
          "- latest-prompt: `C-c g a E p`\n"
          "- latest-transcript: `C-c g a E t`\n"
          "- latest-brief: `C-c g a E b`\n"
          "- latest-evidence: `C-c g a E e`\n"
          "- agent-log-dir: `logs/agent/`\n\n"
          "### Recent Evidence\n\n"
          (gnopon/codex-recent-evidence-lines)
          "\n"))

(defun gnopon/codex-brief-path ()
  "Return a project-local path for a Codex cockpit brief."
  (let ((dir (gnopon/project-file "logs/agent/")))
    (make-directory dir t)
    (expand-file-name
     (format "%s-codex-brief.md" (format-time-string "%Y%m%d-%H%M%S"))
     dir)))

(defun gnopon/codex-brief-buffer-name ()
  "Return the current project's Codex brief preview buffer name."
  (format "*codex-brief:%s*"
          (file-name-nondirectory
           (directory-file-name (file-truename (gnopon/project-root))))))

(defun gnopon/codex-brief-text ()
  "Return a redacted Markdown brief for the current Codex cockpit state."
  (let* ((root (file-truename (gnopon/project-root)))
         (tail (gnopon/codex-transcript-tail-text)))
    (concat "# Codex Cockpit Brief\n\n"
            "- project: `" root "`\n"
            "- created: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
            "- codex-command: `" gnopon-codex-command "`\n"
            "- codex-resume-command: `" gnopon-codex-resume-command "`\n"
            "- codex-resume-picker-command: `" gnopon-codex-resume-picker-command "`\n"
            "- chat-buffer: `" (gnopon/codex-buffer-name) "`\n"
            "- chat-status: `" (format "%s" (gnopon/codex-status)) "`\n"
            "- chat-buffer-chars: `" (number-to-string (or (gnopon/codex-transcript-buffer-chars) 0)) "`\n"
            "- tail-chars: `" (number-to-string (length tail)) "`\n"
            "- terminal-normalization: `ansi/control stripped`\n"
            "- redaction: `gnopon/redact-secrets`\n\n"
            (gnopon/codex-at-a-glance-section)
            (gnopon/codex-readiness-section)
            (gnopon/codex-evidence-cursor-section)
            "## Operating Loop\n\n"
            "- [ ] Orient with dashboard, monitor, and current Git state.\n"
            "- [ ] Stage prompt material in Markdown before sending.\n"
            "- [ ] Preserve prompt, transcript, command, test, and diff evidence.\n"
            "- [ ] Promote durable claims into project memory.\n"
            "- [ ] Review the final diff before accepting changes.\n\n"
            "## Left Hand: Mathematical Lawfulness\n\n"
            "- memory graph: `C-c g m g`\n"
            "- predication index: `C-c g m Q`\n"
            "- formal validation: `C-c g m F`\n\n"
            "## Right Hand: Standards Conformance\n\n"
            "- command matrix: `C-c g p m`\n"
            "- check project: `C-c g p c`\n"
            "- test project: `C-c g p t`\n"
            "- review diff: `C-c g a r`\n\n"
            "## Git State\n\n```text\n"
            (gnopon/redact-secrets (gnopon/git-status-short))
            "\n```\n\n## Diff Stat\n\n```text\n"
            (gnopon/redact-secrets (gnopon/git-diff-stat))
            "\n```\n\n## Live Chat Tail\n\n```text\n"
            tail
            "\n```\n")))

(defun gnopon/codex-brief ()
  "Open a read-only Markdown preview of the current Codex cockpit brief."
  (interactive)
  (let* ((root (file-name-as-directory (file-truename (gnopon/project-root))))
         (buffer (get-buffer-create (gnopon/codex-brief-buffer-name))))
    (with-current-buffer buffer
      (let ((default-directory root))
        (read-only-mode -1)
        (erase-buffer)
        (insert (gnopon/codex-brief-text))
        (gnopon/markdown-buffer-mode)
        (gnopon/codex-polish-cockpit-buffer)
        (goto-char (point-min))
        (read-only-mode 1)))
    (pop-to-buffer buffer)))

(defun gnopon/write-codex-brief ()
  "Write a Codex cockpit brief under `logs/agent/'."
  (interactive)
  (let ((path (gnopon/codex-brief-path)))
    (with-temp-file path
      (insert (gnopon/codex-brief-text)))
    (find-file path)
    path))

(defun gnopon/codex-transcript-buffer-chars ()
  "Return the size of the current project Codex buffer, or nil."
  (when-let ((buffer (get-buffer (gnopon/codex-buffer-name))))
    (with-current-buffer buffer
      (buffer-size))))

(defun gnopon/codex-recent-session-section ()
  "Return a Markdown section listing recent Codex-adjacent agent sessions."
  (let ((sessions (seq-take (gnopon/codex-session-files) 8)))
    (concat "## Codex Sessions\n\n"
            "- session-count: `" (number-to-string (gnopon/codex-session-count)) "`\n"
            "- new Codex session: `C-c g a N`\n"
            "- latest Codex session: `C-c g a E s`\n"
            "- session index: `C-c g a i`\n\n"
            (if sessions
                (mapconcat (lambda (file) (format "- `%s`\n" file))
                           sessions
                           "")
              "- none\n")
            "\n")))

(defun gnopon/codex-dashboard-command-section ()
  "Return Codex cockpit command paths as Markdown."
  (concat
   "## Cockpit Controls\n\n"
   "- Codex cockpit: `C-c g a x`\n"
   "- Codex workspace: `C-c g a Z`\n"
   "- resume Codex workspace: `C-c g a z`\n"
   "- resume picker workspace: `C-c g a j`\n"
   "- Codex terminal: `C-c g a S`\n"
   "- resume latest Codex session: `C-c g a L`\n"
   "- open Codex resume picker: `C-c g a J`\n"
   "- Codex dashboard: `C-c g a D`\n"
   "- Codex monitor: `C-c g a A`\n"
   "- Codex auto monitor: `C-c g a R`\n"
   "- compose prompt: `C-c g a q`\n"
   "- compose region prompt: `C-c g a Q`\n"
   "- send region prompt: `C-c g a y`\n"
   "- send buffer prompt: `C-c g a Y`\n"
   "- send context bundle: `C-c g a B`\n"
   "- copy context bundle: `C-c g a C`\n"
   "- write context bundle: `C-c g a W`\n"
   "- open handoff: `C-c g a h`\n"
   "- write handoff: `C-c g a H`\n"
   "- new Codex session: `C-c g a N`\n"
   "- open latest Codex evidence: `C-c g a E e`\n"
   "- open latest Codex session: `C-c g a E s`\n"
   "- open latest prompt: `C-c g a E p`\n"
   "- open latest transcript: `C-c g a E t`\n"
   "- open latest brief: `C-c g a E b`\n"
   "- capture transcript: `C-c g a T`\n"
   "- Codex cockpit brief: `C-c g a o`\n"
   "- write Codex cockpit brief: `C-c g a k`\n"
   "- review diff: `C-c g a r`\n"
   "- capture command log: `C-c g a l`\n\n"))

(defun gnopon/codex-dashboard-key-section ()
  "Return dashboard-local keybindings as Markdown."
  (concat
   "## Dashboard Keys\n\n"
   "- `g`: refresh dashboard\n"
   "- `z`: open cockpit workspace\n"
   "- `Z`: resume cockpit workspace\n"
   "- `j`: resume picker workspace\n"
   "- `J`: open resume picker\n"
   "- `s`: open Codex terminal\n"
   "- `S`: resume latest Codex session\n"
   "- `A`: open Codex monitor\n"
   "- `R`: open auto-refresh Codex monitor\n"
   "- `C`: compose Codex prompt\n"
   "- `p`: send active region to Codex\n"
   "- `P`: send dashboard buffer to Codex\n"
   "- `b`: send context bundle to Codex\n"
   "- `c`: copy context bundle\n"
   "- `w`: write context bundle\n"
   "- `h`: open handoff\n"
   "- `H`: write handoff\n"
   "- `n`: new session\n"
   "- `N`: new Codex session\n"
   "- `i`: session index\n"
   "- `o e`: open latest Codex evidence\n"
   "- `o s`: open latest Codex session\n"
   "- `o b`: open latest Codex brief\n"
   "- `o p`: open latest prompt record\n"
   "- `o t`: open latest transcript record\n"
   "- `T`: capture Codex transcript\n"
   "- `O`: write Codex cockpit brief\n"
   "- `M`: open memory graph\n"
   "- `F`: open formal validation\n"
   "- `X`: open command matrix\n"
   "- `K`: check project\n"
   "- `V`: test project\n"
   "- `r`: review diff\n"
   "- `l`: capture command log\n\n"))

(defun gnopon/codex-dashboard-text ()
  "Return a Markdown dashboard for the project-scoped Codex cockpit."
  (let* ((root (file-truename (gnopon/project-root)))
         (parts (condition-case nil
                    (gnopon/codex-command-parts)
                  (error nil)))
         (program (car parts))
         (resume-parts (condition-case nil
                           (gnopon/codex-command-parts-for gnopon-codex-resume-command)
                         (error nil)))
         (resume-program (car resume-parts))
         (picker-parts (condition-case nil
                           (gnopon/codex-command-parts-for gnopon-codex-resume-picker-command)
                         (error nil)))
         (picker-program (car picker-parts)))
    (concat "# Codex Agent Cockpit\n\n"
            "- project: `" root "`\n"
            "- generated: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
            "- codex-command: `" gnopon-codex-command "`\n"
            "- codex-command-risk: `" (format "%s" (gnopon/safe-command-risk gnopon-codex-command)) "`\n"
            "- codex-executable: `" (or (and program (executable-find program)) "missing") "`\n"
            "- codex-resume-command: `" gnopon-codex-resume-command "`\n"
            "- codex-resume-command-risk: `" (format "%s" (gnopon/safe-command-risk gnopon-codex-resume-command)) "`\n"
            "- codex-resume-executable: `" (or (and resume-program (executable-find resume-program)) "missing") "`\n"
            "- codex-resume-picker-command: `" gnopon-codex-resume-picker-command "`\n"
            "- codex-resume-picker-command-risk: `" (format "%s" (gnopon/safe-command-risk gnopon-codex-resume-picker-command)) "`\n"
            "- codex-resume-picker-executable: `" (or (and picker-program (executable-find picker-program)) "missing") "`\n"
            "- codex-project-root-option: `" (if gnopon-codex-pass-project-root "-C enabled" "disabled") "`\n"
            "- codex-terminal-scrollback: `" (if gnopon-codex-preserve-terminal-scrollback "--no-alt-screen enabled" "alternate screen allowed") "`\n"
            "- codex-terminal-normalization: `ansi/control stripped`\n"
            "- chat-buffer: `" (gnopon/codex-buffer-name) "`\n"
            "- chat-status: `" (format "%s" (gnopon/codex-status)) "`\n\n"
            "- chat-buffer-chars: `" (number-to-string (or (gnopon/codex-transcript-buffer-chars) 0)) "`\n"
            "- workspace-layout: `dashboard + terminal + live monitor`\n"
            "- transcript-capture: `C-c g a T`\n"
            "- cockpit-brief: `C-c g a k`\n\n"
            (gnopon/codex-at-a-glance-section)
            (gnopon/codex-readiness-section)
            "## Left Hand: Mathematical Lawfulness\n\n"
            "- context bundle: `C-c g a C`\n"
            "- predication index: `C-c g m Q`\n"
            "- formal validation: `C-c g m F`\n"
            "- memory graph: `C-c g m g`\n\n"
            (gnopon/agent-handoff-memory-section root)
            (gnopon/agent-handoff-task-section)
            "## Right Hand: Standards Conformance\n\n"
            "- command matrix: `C-c g p m`\n"
            "- check project: `C-c g p c`\n"
            "- test project: `C-c g p t`\n"
            "- review cockpit: `C-c g r`\n"
            "- GitHub dashboard: `C-c g g h d`\n\n"
            "### Git State\n\n```text\n"
            (gnopon/redact-secrets (gnopon/git-status-short))
            "\n```\n\n### Diff Stat\n\n```text\n"
            (gnopon/redact-secrets (gnopon/git-diff-stat))
            "\n```\n\n"
            (gnopon/codex-recent-session-section)
            (gnopon/codex-evidence-section)
            (gnopon/codex-dashboard-command-section)
            (gnopon/codex-dashboard-key-section)
            "## Operating Boundary\n\n"
            "- The dashboard does not send buffers to Codex.\n"
            "- Launching Codex is explicit and project-scoped.\n"
            "- Context, handoffs, logs, diffs, and tests remain Markdown or Git evidence.\n")))

(defun gnopon/codex-dashboard-button (label command)
  "Insert a Codex dashboard button with LABEL calling COMMAND."
  (insert-text-button label
                      'follow-link t
                      'action (lambda (_button)
                                (let ((default-directory
                                       (or gnopon-codex-dashboard-root default-directory)))
                                  (call-interactively command))))
  (insert "\n"))

(defun gnopon/codex-dashboard-insert-actions ()
  "Insert live action buttons for the current Codex dashboard buffer."
  (insert "\n## Live Actions\n\n")
  (dolist (action gnopon-codex-dashboard-actions)
    (gnopon/codex-dashboard-button (car action) (cdr action)))
  (insert "\n"))

(defun gnopon/codex-dashboard-render (&optional root)
  "Render the Codex dashboard for ROOT into the current buffer."
  (let ((default-directory (file-name-as-directory (or root (gnopon/project-root)))))
    (read-only-mode -1)
    (erase-buffer)
    (setq-local gnopon-codex-dashboard-root default-directory)
    (insert (gnopon/codex-dashboard-text))
    (gnopon/markdown-buffer-mode)
    (gnopon/codex-polish-cockpit-buffer)
    (goto-char (point-max))
    (gnopon/codex-dashboard-insert-actions)
    (gnopon-codex-dashboard-mode 1)
    (setq-local gnopon-codex-dashboard-root default-directory)
    (goto-char (point-min))
    (read-only-mode 1)))

(defun gnopon/codex-dashboard-refresh ()
  "Refresh the current Codex dashboard buffer."
  (interactive)
  (unless gnopon-codex-dashboard-root
    (user-error "Current buffer is not a Codex dashboard"))
  (gnopon/codex-dashboard-render gnopon-codex-dashboard-root))

(defun gnopon/codex-dashboard ()
  "Open a read-only Markdown dashboard for Codex work."
  (interactive)
  (let* ((root (file-name-as-directory (file-truename (gnopon/project-root))))
         (buffer (get-buffer-create (format "*codex-dashboard:%s*"
                                            (file-name-nondirectory
                                             (directory-file-name root))))))
    (with-current-buffer buffer
      (gnopon/codex-dashboard-render root))
    (pop-to-buffer buffer)))

(defun gnopon/codex-workspace-with-terminal (terminal-command)
  "Open a Codex workspace and run TERMINAL-COMMAND in the terminal pane."
  (let ((root (file-name-as-directory (file-truename (gnopon/project-root)))))
    (delete-other-windows)
    (gnopon/codex-dashboard)
    (let ((dashboard-window (selected-window)))
      (split-window-right)
      (other-window 1)
      (call-interactively terminal-command)
      (split-window-below)
      (other-window 1)
      (switch-to-buffer (gnopon/codex-monitor-buffer root))
      (select-window dashboard-window))))

(defun gnopon/codex-workspace ()
  "Open a Codex workspace with dashboard, terminal, and live monitor."
  (interactive)
  (gnopon/codex-workspace-with-terminal #'gnopon/codex-shell))

(defun gnopon/codex-resume-workspace ()
  "Resume the latest Codex session in a dashboard, terminal, and monitor layout."
  (interactive)
  (gnopon/codex-workspace-with-terminal #'gnopon/codex-resume-last))

(defun gnopon/codex-resume-picker-workspace ()
  "Open the Codex resume picker in a dashboard, terminal, and monitor layout."
  (interactive)
  (gnopon/codex-workspace-with-terminal #'gnopon/codex-resume-picker))

(defun gnopon/review-agent-diff ()
  "Review current project changes after an agent run."
  (interactive)
  (if (fboundp 'magit-status)
      (magit-status (gnopon/project-root))
    (let ((buffer (get-buffer-create "*agent-diff*")))
      (with-current-buffer buffer
        (erase-buffer)
        (insert (gnopon/git-diff))
        (diff-mode))
      (pop-to-buffer buffer))))

(defun gnopon/agent-log-path ()
  "Return a timestamped project-local agent log path."
  (let ((dir (gnopon/project-file "logs/agent/")))
    (make-directory dir t)
    (expand-file-name (format "%s.md" (format-time-string "%Y%m%d-%H%M%S")) dir)))

(defun gnopon/agent-session-dir ()
  "Return the project-local agent session directory."
  (let ((dir (gnopon/project-file "logs/agent/")))
    (make-directory dir t)
    dir))

(defun gnopon/agent-session-path (title)
  "Return a project-local agent session path for TITLE."
  (expand-file-name
   (format "%s-%s.md" (format-time-string "%Y%m%d-%H%M%S") (gnopon/markdown-slugify title))
   (gnopon/agent-session-dir)))

(defun gnopon/start-agent-session (title)
  "Create a Markdown session record for an agent task TITLE."
  (interactive "sAgent session title: ")
  (let ((path (gnopon/agent-session-path title)))
    (find-file path)
    (insert (gnopon/markdown-frontmatter-string title "active" nil '("agent" "session")))
    (insert "# " title "\n\n")
    (insert "## Context\n\n")
    (insert "```text\n" (gnopon/git-status-short) "\n```\n\n")
    (insert "## Prompt\n\n\n## Transcript Notes\n\n\n## Commands\n\n\n## Diff Review\n\n\n## Tests\n\n\n## Completion\n\n- [ ] Diff reviewed\n- [ ] Tests captured\n- [ ] Human accepted changes\n")))

(defun gnopon/start-codex-session (title)
  "Create a Codex-specific Markdown session record for TITLE."
  (interactive "sCodex session title: ")
  (let ((path (gnopon/agent-session-path (concat "codex-" title))))
    (find-file path)
    (insert (gnopon/markdown-frontmatter-string title "active" nil '("agent" "session" "codex")))
    (insert "# " title "\n\n")
    (insert "## Codex Cockpit\n\n")
    (insert "- dashboard: `C-c g a D`\n")
    (insert "- workspace: `C-c g a Z`\n")
    (insert "- terminal: `" (gnopon/codex-buffer-name) "`\n")
    (insert "- prompt evidence: `C-c g a E p`\n")
    (insert "- transcript evidence: `C-c g a E t`\n\n")
    (insert "## Starting State\n\n```text\n" (gnopon/git-status-short) "\n```\n\n")
    (insert "## Prompt Evidence\n\n- [ ] Context bundle sent or intentionally skipped\n- [ ] Focused region/buffer prompt recorded\n\n")
    (insert "## Transcript Evidence\n\n- [ ] Transcript captured after material exchange\n- [ ] Important claims copied into project memory when durable\n\n")
    (insert "## Left Hand: Mathematical Lawfulness\n\n- [ ] Memory graph inspected\n- [ ] Formal validation/predication gaps reviewed\n- [ ] Conflicts preserved as evidence\n\n")
    (insert "## Right Hand: Standards Conformance\n\n- [ ] Command matrix reviewed\n- [ ] Checks captured\n- [ ] Tests captured\n- [ ] Diff reviewed\n\n")
    (insert "## Completion\n\n- [ ] Prompt records reviewed\n- [ ] Transcript records reviewed\n- [ ] Human accepted changes\n")
    (save-buffer)))

(defun gnopon/agent-session-index ()
  "Open an index of project-local agent session records."
  (interactive)
  (let ((buffer (get-buffer-create "*agent-sessions*"))
        (dir (gnopon/agent-session-dir)))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# Agent Sessions\n\n")
      (dolist (file (directory-files dir nil "\\.md\\'"))
        (insert "- `" file "`\n"))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/agent-recent-session-list ()
  "Return recent project-local agent session filenames."
  (let ((dir (gnopon/agent-session-dir)))
    (when (file-directory-p dir)
      (last (sort (directory-files dir nil "\\.md\\'") #'string<) 8))))

(defun gnopon/agent-handoff-memory-section (root)
  "Return a project memory readiness section for ROOT."
  (concat
   "## Project Memory\n\n"
   (mapconcat (lambda (file)
                (let ((path (expand-file-name file root)))
                  (format "- %s `%s`\n"
                          (if (file-readable-p path) "[x]" "[ ]")
                          file)))
              gnopon-context-files
              "")
   "\n"))

(defun gnopon/agent-handoff-task-section ()
  "Return task counts for an agent handoff packet."
  (if (and (fboundp 'gnopon/task-items)
           (fboundp 'gnopon/task-counts))
      (let* ((tasks (gnopon/task-items))
             (counts (gnopon/task-counts tasks)))
        (format (concat "## Tasks\n\n"
                        "- todo: `%s`\n"
                        "- done: `%s`\n"
                        "- canceled: `%s`\n"
                        "- task cockpit: `C-c g m t`\n\n")
                (alist-get 'todo counts)
                (alist-get 'done counts)
                (alist-get 'canceled counts)))
    "## Tasks\n\n- task cockpit unavailable until task module loads\n\n"))

(defun gnopon/agent-handoff-session-section ()
  "Return recent agent sessions for a handoff packet."
  (let ((sessions (gnopon/agent-recent-session-list)))
    (concat "## Recent Agent Sessions\n\n"
            (if sessions
                (mapconcat (lambda (file) (format "- `%s`\n" file))
                           sessions
                           "")
              "- none\n")
            "\n")))

(defun gnopon/agent-handoff-text (&optional title)
  "Return a local, redacted Markdown handoff packet for agent work.
Optional TITLE names the handoff objective."
  (let ((root (file-truename (gnopon/project-root))))
    (concat "# Agent Handoff\n\n"
            "- title: `" (or title "Agent work") "`\n"
            "- project: `" root "`\n"
            "- created: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
            "- agent-command: `" gnopon-agent-command "`\n"
            "- agent-command-risk: `" (format "%s" (gnopon/safe-command-risk gnopon-agent-command)) "`\n\n"
            "## Safety Invariants\n\n"
            "- Copy or write redacted context before invoking an agent.\n"
            "- Do not send secrets or unreviewed local-only files.\n"
            "- Do not run shell commands, commit, push, or open PRs without explicit human confirmation.\n"
            "- Treat conflicts, gaps, and failing tests as evidence to preserve.\n\n"
            "## Git State\n\n```text\n"
            (gnopon/redact-secrets (gnopon/git-status-short))
            "\n```\n\n## Diff Stat\n\n```text\n"
            (gnopon/redact-secrets (gnopon/git-diff-stat))
            "\n```\n\n"
            (gnopon/agent-handoff-memory-section root)
            (gnopon/agent-handoff-task-section)
            (gnopon/agent-handoff-session-section)
            "## Recommended Flow\n\n"
            "1. Open project dashboard: `C-c g w d`.\n"
            "2. Inspect memory graph: `C-c g m g`.\n"
            "3. Copy redacted context: `C-c g a C`.\n"
            "4. Start a session record: `C-c g a n`.\n"
            "5. Launch agent shell only when ready: `C-c g a s`.\n"
            "6. Review diff: `C-c g a r`.\n"
            "7. Capture tests/logs: `C-c g a l`.\n"
            "8. Prepare PR handoff: `C-c g r`.\n\n")))

(defun gnopon/open-agent-handoff (title)
  "Open a read-only agent handoff packet for TITLE."
  (interactive "sHandoff title: ")
  (let ((buffer (get-buffer-create "*agent-handoff*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/agent-handoff-text title))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/agent-handoff-path (title)
  "Return a project-local handoff packet path for TITLE."
  (let ((dir (gnopon/project-file "logs/agent/")))
    (make-directory dir t)
    (expand-file-name
     (format "%s-handoff-%s.md"
             (format-time-string "%Y%m%d-%H%M%S")
             (gnopon/markdown-slugify title))
     dir)))

(defun gnopon/write-agent-handoff (title)
  "Write an agent handoff packet for TITLE under `logs/agent/'."
  (interactive "sHandoff title: ")
  (let ((path (gnopon/agent-handoff-path title)))
    (with-temp-file path
      (insert (gnopon/agent-handoff-text title)))
    (find-file path)
    path))

(defun gnopon/copy-agent-handoff (title)
  "Copy an agent handoff packet for TITLE to the kill ring."
  (interactive "sHandoff title: ")
  (kill-new (gnopon/agent-handoff-text title))
  (message "Copied agent handoff for %s" (gnopon/project-root)))

(defun gnopon/search-agent-sessions ()
  "Search project-local agent session records."
  (interactive)
  (gnopon/search-project "TODO\\|Prompt\\|Completion\\|status: active\\|evidence"
                         (gnopon/agent-session-dir)))

(defun gnopon/close-agent-session ()
  "Mark the current agent session Markdown file as done."
  (interactive)
  (unless (and buffer-file-name
               (string-match-p "/logs/agent/.*\\.md\\'" buffer-file-name))
    (user-error "Current buffer is not an agent session file"))
  (let ((text (buffer-substring-no-properties (point-min) (point-max))))
    (erase-buffer)
    (insert (gnopon/markdown-frontmatter-set-field text 'status "done"))
    (save-buffer)))

(defun gnopon/capture-command-log (command)
  "Run COMMAND after confirmation and capture output in a Markdown log."
  (interactive "sCommand to run and log: ")
  (let ((risk (gnopon/safe-command-risk command)))
    (when (eq risk 'dangerous)
      (user-error "Refusing dangerous shell command: %s" command))
    (unless (yes-or-no-p (format "Run and log `%s` (%s risk) in %s? "
                                 command risk (gnopon/project-root)))
      (user-error "Canceled")))
  (let* ((default-directory (gnopon/project-root))
         (path (gnopon/agent-log-path))
         (buffer (get-buffer-create "*agent-command-log*"))
         (exit-code nil))
    (with-current-buffer buffer
      (erase-buffer)
      (insert "# Command Log\n\n")
      (insert "- command: `" command "`\n")
      (insert "- project: `" default-directory "`\n")
      (insert "- created: " (format-time-string "%Y-%m-%d %H:%M:%S") "\n\n")
      (insert "## Output\n\n```text\n")
      (setq exit-code (call-process shell-file-name nil buffer t shell-command-switch command))
      (insert "\n```\n\n")
      (insert (format "exit-code: `%s`\n" exit-code))
      (write-region (point-min) (point-max) path))
    (find-file path)))

(transient-define-prefix gnopon/codex-cockpit ()
  "Project-scoped Codex agent cockpit."
  [["Codex"
    ("z" "workspace" gnopon/codex-workspace)
    ("Z" "resume workspace" gnopon/codex-resume-workspace)
    ("j" "picker workspace" gnopon/codex-resume-picker-workspace)
    ("s" "terminal" gnopon/codex-shell)
    ("L" "resume latest" gnopon/codex-resume-last)
    ("J" "resume picker" gnopon/codex-resume-picker)
    ("d" "dashboard" gnopon/codex-dashboard)
    ("a" "activity monitor" gnopon/codex-monitor)
    ("R" "auto monitor" gnopon/codex-monitor-auto)]
   ["Prompt"
    ("q" "compose prompt" gnopon/codex-compose-prompt)
    ("Q" "compose region" gnopon/codex-compose-region)
    ("p" "send region" gnopon/codex-send-region)
    ("P" "send buffer" gnopon/codex-send-buffer)
    ("B" "send context" gnopon/codex-send-context-bundle)]
   ["Context"
    ("c" "copy context" gnopon/copy-context-bundle)
    ("w" "write context" gnopon/write-context-bundle)
    ("h" "handoff" gnopon/open-agent-handoff)
    ("H" "write handoff" gnopon/write-agent-handoff)]
   ["Evidence"
    ("n" "new session" gnopon/start-agent-session)
    ("N" "new Codex session" gnopon/start-codex-session)
    ("i" "session index" gnopon/agent-session-index)
    ("e" "latest Codex evidence" gnopon/open-latest-codex-evidence)
    ("s" "latest Codex session" gnopon/open-latest-codex-session)
    ("b" "latest brief" gnopon/open-latest-codex-brief)
    ("p" "latest prompt" gnopon/open-latest-codex-prompt)
    ("t" "latest transcript" gnopon/open-latest-codex-transcript)
    ("T" "capture transcript" gnopon/write-codex-transcript)
    ("o" "cockpit brief" gnopon/codex-brief)
    ("O" "write brief" gnopon/write-codex-brief)
    ("l" "log command" gnopon/capture-command-log)
    ("r" "review diff" gnopon/review-agent-diff)]])

(defun gnopon/insert-agent-task ()
  "Insert a Markdown scaffold for auditable agent work."
  (interactive)
  (insert (format "## Agent Task - %s\n\n- [ ] Objective: \n- [ ] Context copied\n- [ ] Agent run reviewed\n- [ ] Tests captured\n- [ ] Diff reviewed\n\n### Evidence\n\n"
                  (format-time-string "%Y-%m-%d %H:%M"))))

(defun gnopon/draft-commit-message ()
  "Create a local commit-message draft from Git status."
  (interactive)
  (let ((buffer (get-buffer-create "*commit-draft*")))
    (with-current-buffer buffer
      (erase-buffer)
      (insert "# Commit Message Draft\n\n")
      (insert "Summary: \n\nDetails:\n\n")
      (insert "```text\n" (gnopon/git-status-short) "\n```\n"))
    (pop-to-buffer buffer)))

(defun gnopon/draft-pr-description ()
  "Create a local PR-description draft from Git status and diff stat."
  (interactive)
  (let ((buffer (get-buffer-create "*pr-draft*")))
    (with-current-buffer buffer
      (erase-buffer)
      (gnopon/markdown-buffer-mode)
      (insert "## Summary\n\n\n## Tests\n\n- [ ] \n\n## Review Notes\n\n```text\n")
      (insert (gnopon/git-status-short))
      (insert "\n```\n\n```text\n")
      (insert (gnopon/git-diff-stat))
      (insert "\n```\n"))
    (pop-to-buffer buffer)))

(define-key gnopon-map (kbd "a c") #'gnopon/agent-context)
(define-key gnopon-map (kbd "a s") #'gnopon/agent-shell)
(define-key gnopon-map (kbd "a t") #'gnopon/insert-agent-task)
(define-key gnopon-map (kbd "a m") #'gnopon/draft-commit-message)
(define-key gnopon-map (kbd "a p") #'gnopon/draft-pr-description)
(define-key gnopon-map (kbd "a r") #'gnopon/review-agent-diff)
(define-key gnopon-map (kbd "a l") #'gnopon/capture-command-log)
(define-key gnopon-map (kbd "a n") #'gnopon/start-agent-session)
(define-key gnopon-map (kbd "a N") #'gnopon/start-codex-session)
(define-key gnopon-map (kbd "a i") #'gnopon/agent-session-index)
(define-key gnopon-map (kbd "a h") #'gnopon/open-agent-handoff)
(define-key gnopon-map (kbd "a H") #'gnopon/write-agent-handoff)
(define-key gnopon-map (kbd "a /") #'gnopon/search-agent-sessions)
(define-key gnopon-map (kbd "a d") #'gnopon/close-agent-session)
(define-key gnopon-map (kbd "a x") #'gnopon/codex-cockpit)
(define-key gnopon-map (kbd "a A") #'gnopon/codex-monitor)
(define-key gnopon-map (kbd "a R") #'gnopon/codex-monitor-auto)
(define-key gnopon-map (kbd "a S") #'gnopon/codex-shell)
(define-key gnopon-map (kbd "a L") #'gnopon/codex-resume-last)
(define-key gnopon-map (kbd "a J") #'gnopon/codex-resume-picker)
(define-key gnopon-map (kbd "a D") #'gnopon/codex-dashboard)
(define-key gnopon-map (kbd "a Z") #'gnopon/codex-workspace)
(define-key gnopon-map (kbd "a z") #'gnopon/codex-resume-workspace)
(define-key gnopon-map (kbd "a j") #'gnopon/codex-resume-picker-workspace)
(define-key gnopon-map (kbd "a T") #'gnopon/write-codex-transcript)
(define-key gnopon-map (kbd "a o") #'gnopon/codex-brief)
(define-key gnopon-map (kbd "a k") #'gnopon/write-codex-brief)
(define-key gnopon-map (kbd "a q") #'gnopon/codex-compose-prompt)
(define-key gnopon-map (kbd "a Q") #'gnopon/codex-compose-region)
(define-key gnopon-map (kbd "a y") #'gnopon/codex-send-region)
(define-key gnopon-map (kbd "a Y") #'gnopon/codex-send-buffer)
(define-key gnopon-map (kbd "a B") #'gnopon/codex-send-context-bundle)
(define-key gnopon-map (kbd "a E e") #'gnopon/open-latest-codex-evidence)
(define-key gnopon-map (kbd "a E b") #'gnopon/open-latest-codex-brief)
(define-key gnopon-map (kbd "a E p") #'gnopon/open-latest-codex-prompt)
(define-key gnopon-map (kbd "a E s") #'gnopon/open-latest-codex-session)
(define-key gnopon-map (kbd "a E t") #'gnopon/open-latest-codex-transcript)

(gnopon/use-optional-package gptel
  :commands (gptel gptel-send)
  :custom
  (gptel-default-mode 'gfm-mode)
  :config
  (when (fboundp 'gptel-make-ollama)
    (setq gptel-model "llama3.1"
          gptel-backend (gptel-make-ollama "Ollama"
                          :host "localhost:11434"
                          :stream t
                          :models '("llama3.1" "qwen2.5-coder" "mistral")))))

(provide 'gnopon-agents)
;;; gnopon-agents.el ends here
