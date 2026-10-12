;;; gnopon-capability.el --- Requirement-to-capability audit -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)
(require 'seq)
(require 'subr-x)

(defvar gnopon-capability-items
  '(((id . "direct-bootstrap")
     (requirement . "Fast direct bootstrap without Org tangling")
     (evidence . ("early-init.el" "init.el" "scripts/check.mjs"))
     (commands . (gnopon/report-startup gnopon/open-module)))
    ((id . "modern-ux")
     (requirement . "Command palettes, contextual actions, discoverable keybindings, polished UI")
     (evidence . ("gnopon-cockpit.el" "gnopon-control.el" "gnopon-ui.el" "gnopon-actions.el"))
     (commands . (gnopon/cockpit gnopon/control-center gnopon/knowledge-vault gnopon/context-actions gnopon/welcome)))
    ((id . "completion-search-navigation")
     (requirement . "Fast search, rich completion, project navigation, Xref and symbols")
     (evidence . ("gnopon-completion.el" "gnopon-workspace.el" "gnopon-ide.el"))
     (commands . (gnopon/search-project gnopon/switch-buffer project-find-file gnopon/symbol-actions gnopon/code-status)))
    ((id . "rust-node-engineering")
     (requirement . "Rust, Node, TypeScript, lint, check, test, format, debug")
     (evidence . ("gnopon-programming.el" "gnopon-ide.el" "flake.nix" "guix/manifest.scm"))
     (commands . (gnopon/check-project gnopon/test-project gnopon/lint-project gnopon/format-buffer gnopon/debug-project)))
    ((id . "api-cli-engineering")
     (requirement . "API, CLI, HTTP, JSON, jq, and explicit curl workflows")
     (evidence . ("gnopon-api.el" "gnopon-shell.el"))
     (commands . (gnopon/api-cockpit gnopon/open-api-scratch gnopon/api-request-note gnopon/command-cockpit gnopon/command-preview-text)))
    ((id . "markdown-memory")
     (requirement . "GitHub-renderable Markdown/YAML planning, notes, tasks, backlinks, ADRs, RFCs")
     (evidence . ("gnopon-markdown.el" "gnopon-tasks.el" "gnopon-lib-test.el"))
     (commands . (gnopon/knowledge-vault gnopon/open-goals-file gnopon/capture-goal gnopon/capture-knowledge-note gnopon/project-memory-index gnopon/markdown-structure-report gnopon/task-cockpit gnopon/create-adr gnopon/create-rfc)))
    ((id . "predication-formal")
     (requirement . "Predication categories, paraconsistent values, RDF/SHACL/proof artifacts")
     (evidence . ("gnopon-predication.el" "gnopon-formal.el"))
     (commands . (gnopon/create-predication-cell gnopon/validate-predications gnopon/formal-cockpit gnopon/formal-validation-report)))
    ((id . "git-github-review")
     (requirement . "Magit, GitHub PR/issues/checks, review packets, draft PR handoff")
     (evidence . ("gnopon-git.el" "gnopon-review.el"))
     (commands . (gnopon/git-status gnopon/review-cockpit gnopon/write-review-packet gnopon/write-pr-body-file gnopon/gh-pr-status)))
    ((id . "agentic-programming")
     (requirement . "Human-controlled agents, context bundles, sessions, logs, patch review")
     (evidence . ("gnopon-context.el" "gnopon-agents.el" "gnopon-mcp.el"))
     (commands . (gnopon/copy-context-bundle gnopon/write-context-bundle gnopon/start-agent-session gnopon/start-codex-session gnopon/codex-cockpit gnopon/codex-dashboard gnopon/codex-dashboard-refresh gnopon/codex-shell gnopon/codex-resume-last gnopon/codex-resume-picker gnopon/codex-workspace gnopon/codex-resume-workspace gnopon/codex-resume-picker-workspace gnopon/codex-monitor gnopon/codex-monitor-auto gnopon/codex-monitor-toggle-auto-refresh gnopon/codex-monitor-refresh gnopon/codex-brief gnopon/write-codex-brief gnopon/codex-compose-prompt gnopon/codex-compose-region gnopon/codex-send-composer gnopon/codex-send-region gnopon/codex-send-buffer gnopon/codex-send-context-bundle gnopon/write-codex-prompt-record gnopon/open-latest-codex-evidence gnopon/open-latest-codex-session gnopon/open-latest-codex-prompt gnopon/open-latest-codex-transcript gnopon/open-latest-codex-brief gnopon/write-codex-transcript gnopon/capture-command-log gnopon/mcp-cockpit)))
    ((id . "safety")
     (requirement . "Explicit AI boundaries, redaction, safe shell risk model, no hidden automation")
     (evidence . ("gnopon-security.el" "gnopon-shell.el" "gnopon-lib.el"))
     (commands . (gnopon/safety-audit gnopon/write-safety-audit gnopon/command-preview-text gnopon/safe-command-risk)))
    ((id . "reproducibility")
     (requirement . "Package manifest, Nix/Guix entry points, install wrapper, reproducibility checks")
     (evidence . ("gnopon-core.el" "scripts/gnoponemacs.mjs" "flake.nix" "guix/manifest.scm" "scripts/repro-check.mjs"))
     (commands . (gnopon/doctor)))
    ((id . "verification")
     (requirement . "Automated structure, smoke, command, helper, and export tests")
     (evidence . ("scripts/check.mjs" "tests/gnopon-lib-test.el" "tests/gnopon-command-test.el" "tests/gnopon-load-smoke.el"))
     (commands . (gnopon/doctor gnopon/capability-audit))))
  "Capability registry mapping user requirements to concrete GnoponEmacs evidence.")

(defvar gnopon-capability-output-directory "logs/capability/"
  "Project-relative directory for written capability audits.")

(defun gnopon/capability-command-covered-p (command)
  "Return non-nil when COMMAND is callable or intentionally external."
  (or (fboundp command)
      (memq command '(project-find-file))))

(defun gnopon/capability-item-status (item)
  "Return status for capability ITEM."
  (let* ((commands (alist-get 'commands item))
         (missing (seq-remove #'gnopon/capability-command-covered-p commands)))
    (if missing
        `((status . gap) (missing . ,missing))
      '((status . covered) (missing . nil)))))

(defun gnopon/capability-row (item)
  "Return a Markdown table row for capability ITEM."
  (let* ((status (gnopon/capability-item-status item))
         (missing (alist-get 'missing status)))
    (format "| `%s` | %s | %s | %s |\n"
            (alist-get 'id item)
            (alist-get 'status status)
            (alist-get 'requirement item)
            (if missing
                (mapconcat (lambda (symbol) (format "`%s`" symbol)) missing ", ")
              (mapconcat (lambda (file) (format "`%s`" file))
                         (alist-get 'evidence item)
                         ", ")))))

(defun gnopon/capability-audit-text ()
  "Return a Markdown capability audit for GnoponEmacs."
  (let* ((items gnopon-capability-items)
         (statuses (mapcar #'gnopon/capability-item-status items))
         (gaps (seq-filter (lambda (status)
                             (eq (alist-get 'status status) 'gap))
                           statuses)))
    (concat "# GnoponEmacs Capability Audit\n\n"
            "- project: `" (file-truename (gnopon/project-root)) "`\n"
            "- generated: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
            "- capabilities: `" (number-to-string (length items)) "`\n"
            "- gaps: `" (number-to-string (length gaps)) "`\n\n"
            "## Requirements\n\n"
            "| Capability | Status | Requirement | Evidence Or Gap |\n"
            "|---|---|---|---|\n"
            (mapconcat #'gnopon/capability-row items "")
            "\n## Notes\n\n"
            "- This audit proves command and module coverage, not subjective UX quality.\n"
            "- External package commands may be reported covered by package configuration and smoke tests.\n"
            "- Nix/Guix lock generation still requires runners with those tools installed.\n")))

(defun gnopon/capability-audit ()
  "Open a read-only capability audit buffer."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-capability-audit*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/capability-audit-text))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/capability-audit-path ()
  "Return a timestamped project-local capability audit path."
  (let ((dir (gnopon/project-file gnopon-capability-output-directory)))
    (make-directory dir t)
    (expand-file-name (format "%s-capability-audit.md"
                              (format-time-string "%Y%m%d-%H%M%S"))
                      dir)))

(defun gnopon/write-capability-audit ()
  "Write a capability audit under `logs/capability/'."
  (interactive)
  (let ((path (gnopon/capability-audit-path)))
    (with-temp-file path
      (insert (gnopon/capability-audit-text)))
    (find-file path)
    path))

(define-key gnopon-map (kbd "d c") #'gnopon/capability-audit)
(define-key gnopon-map (kbd "d C") #'gnopon/write-capability-audit)

(provide 'gnopon-capability)
;;; gnopon-capability.el ends here
