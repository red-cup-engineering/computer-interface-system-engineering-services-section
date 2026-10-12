;;; gnopon-control.el --- First-run and control-center cockpit -*- lexical-binding: t; -*-

;;; Code:

(require 'button)
(require 'gnopon-core)

(defcustom gnopon-open-control-center-on-startup nil
  "When non-nil, open `gnopon/control-center' after startup."
  :type 'boolean
  :group 'gnopon)

(defun gnopon/control-center-button (label command)
  "Insert an interactive LABEL button that calls COMMAND."
  (insert-text-button label
                      'follow-link t
                      'action (lambda (_button)
                                (call-interactively command)))
  (insert "\n"))

(defun gnopon/control-center-section (title &rest actions)
  "Insert a control center TITLE and ACTIONS.
Each action is a cons cell of button label and command."
  (insert "## " title "\n\n")
  (dolist (action actions)
    (gnopon/control-center-button (car action) (cdr action)))
  (insert "\n"))

(defun gnopon/control-center-status-line ()
  "Return a compact status line for the active project."
  (format "- project: `%s`\n- workspace: `%s`\n- startup: `%.3fs`\n"
          (file-truename (gnopon/project-root))
          (if (fboundp 'gnopon/workspace-name)
              (gnopon/workspace-name)
            "unknown")
          (float-time (time-subtract (current-time) gnopon-start-time))))

(defun gnopon/control-center ()
  "Open the main GnoponEmacs control center."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-control*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# GnoponEmacs Control\n\n")
      (insert (gnopon/control-center-status-line))
      (insert "\n")
      (insert "## Orientation\n\n")
      (insert "- Gnoponics means knowledge cultivating: goals, plans, tasks, notes, evidence, and agent sessions stay in GitHub Markdown.\n")
      (insert "- Start with the knowledge vault when you are unsure where to go next.\n")
      (insert "- Use Codex through the cockpit so prompts, transcripts, and context stay inspectable.\n")
      (insert "\n")
      (gnopon/control-center-section
       "Start"
       '("Knowledge vault" . gnopon/knowledge-vault)
       '("Open cockpit" . gnopon/cockpit)
       '("Project dashboard" . gnopon/project-dashboard)
       '("Codex cockpit" . gnopon/codex-cockpit)
       '("Workspace snapshot" . gnopon/workspace-snapshot)
       '("Doctor" . gnopon/doctor)
       '("Performance report" . gnopon/performance-report)
       '("Capability audit" . gnopon/capability-audit)
       '("Safety audit" . gnopon/safety-audit)
       '("Find file" . project-find-file)
       '("Search project" . gnopon/search-project))
      (gnopon/control-center-section
       "Build"
       '("Symbol actions" . gnopon/symbol-actions)
       '("Test project" . gnopon/test-project)
       '("Check project" . gnopon/check-project)
       '("Run package script" . gnopon/run-package-script)
       '("Debug" . gnopon/debug-project)
       '("API cockpit" . gnopon/api-cockpit))
      (gnopon/control-center-section
       "Memory"
       '("Knowledge vault" . gnopon/knowledge-vault)
       '("Open goals" . gnopon/open-goals-file)
       '("Capture knowledge note" . gnopon/capture-knowledge-note)
       '("Open context file" . gnopon/open-context-file)
       '("Memory index" . gnopon/project-memory-index)
       '("Structure report" . gnopon/markdown-structure-report)
       '("Task cockpit" . gnopon/task-cockpit)
       '("Bootstrap memory" . gnopon/bootstrap-project-memory)
       '("Create predication cell" . gnopon/create-predication-cell)
       '("Formal validation" . gnopon/formal-cockpit)
       '("Validate predications" . gnopon/validate-predications))
      (gnopon/control-center-section
       "Agent"
       '("Codex cockpit" . gnopon/codex-cockpit)
       '("Codex workspace" . gnopon/codex-workspace)
       '("Codex prompt composer" . gnopon/codex-compose-prompt)
       '("Copy context bundle" . gnopon/copy-context-bundle)
       '("Open context bundle" . gnopon/open-context-bundle)
       '("MCP exports" . gnopon/mcp-cockpit)
       '("Agent shell" . gnopon/agent-shell)
       '("New agent session" . gnopon/start-agent-session)
       '("Review cockpit" . gnopon/review-cockpit))
      (gnopon/control-center-section
       "Review"
       '("Git status" . gnopon/git-status)
       '("Open review packet" . gnopon/open-review-packet)
       '("Write review packet" . gnopon/write-review-packet)
       '("Write PR body" . gnopon/write-pr-body-file)
       '("Copy PR body" . gnopon/copy-pr-body)
       '("GitHub PR status" . gnopon/gh-pr-status)
       '("GitHub PRs" . gnopon/gh-pr-list))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/welcome ()
  "Open a first-run welcome buffer focused on operational next steps."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-welcome*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# Welcome To GnoponEmacs\n\n")
      (insert "Gnoponics means knowledge cultivating. This config treats GitHub Markdown as the shared context where you and agents keep goals, plans, tasks, notes, claims, sessions, prompts, transcripts, and review evidence.\n\n")
      (insert "- cockpit: `M-SPC`\n")
      (insert "- control center: `C-c g o`\n")
      (insert "- knowledge vault: `C-c g m k`\n")
      (insert "- Codex cockpit: `C-c g a x`\n")
      (insert "- current work actions: `C-c g .`\n")
      (insert "- symbol actions: `C-c g i`\n")
      (insert "- review handoff: `C-c g r`\n\n")
      (gnopon/control-center-section
       "First Moves"
       '("Open knowledge vault" . gnopon/knowledge-vault)
       '("Open control center" . gnopon/control-center)
       '("Run doctor" . gnopon/doctor)
       '("Bootstrap project memory" . gnopon/bootstrap-project-memory)
       '("Open Codex cockpit" . gnopon/codex-cockpit)
       '("Open cockpit" . gnopon/cockpit))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(define-key gnopon-map (kbd "o") #'gnopon/control-center)
(define-key gnopon-map (kbd "?") #'gnopon/welcome)

(add-hook 'emacs-startup-hook
          (lambda ()
            (when gnopon-open-control-center-on-startup
              (gnopon/control-center))))

(provide 'gnopon-control)
;;; gnopon-control.el ends here
