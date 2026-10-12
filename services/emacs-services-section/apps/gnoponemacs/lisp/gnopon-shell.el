;;; gnopon-shell.el --- Project terminals -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)
(require 'transient)

(defvar gnopon-command-history nil
  "History for GnoponEmacs project shell commands.")

(use-package eshell
  :ensure nil
  :commands eshell
  :custom
  (eshell-history-size 10000)
  (eshell-scroll-to-bottom-on-input t)
  :config
  (setq eshell-directory-name (gnopon/path "eshell/")))

(gnopon/use-optional-package eat
  :commands (eat eat-project))

(defun gnopon/project-eshell ()
  "Open Eshell in the current project."
  (interactive)
  (let ((default-directory (gnopon/project-root)))
    (eshell t)))

(defun gnopon/project-terminal ()
  "Open an Eat terminal in the current project."
  (interactive)
  (let ((default-directory (gnopon/project-root)))
    (if (fboundp 'eat)
        (eat)
      (ansi-term (or (getenv "SHELL") shell-file-name)
                 (format "terminal:%s" (file-name-nondirectory
                                         (directory-file-name default-directory)))))))

(defun gnopon/read-project-command ()
  "Read a shell command intended to run at the project root."
  (read-shell-command "Project command: " nil 'gnopon-command-history))

(defun gnopon/confirm-command-risk (command)
  "Confirm COMMAND based on its risk, returning the risk label."
  (let ((risk (gnopon/safe-command-risk command)))
    (when (eq risk 'dangerous)
      (user-error "Refusing dangerous shell command: %s" command))
    (unless (yes-or-no-p
             (format "Run `%s` (%s risk) in %s? "
                     command risk (gnopon/project-root)))
      (user-error "Canceled"))
    risk))

(defun gnopon/command-preview-text (command)
  "Return a Markdown preview for COMMAND."
  (let ((risk (gnopon/safe-command-risk command)))
    (concat "# Command Preview\n\n"
            "- project: `" (file-truename (gnopon/project-root)) "`\n"
            "- command: `" command "`\n"
            "- risk: `" (format "%s" risk) "`\n\n"
            "## Policy\n\n"
            (cond
             ((eq risk 'dangerous)
              "- Dangerous commands are refused by GnoponEmacs helpers.\n")
             ((eq risk 'network)
              "- Network commands require explicit confirmation and should be logged when they affect project evidence.\n")
             ((eq risk 'write)
              "- Write commands require explicit confirmation and should be reviewed with Git afterwards.\n")
             (t
              "- Low-risk commands still run through visible buffers, not hidden automation.\n"))
            "\n## Suggested Follow-Up\n\n"
            "- [ ] Review output.\n"
            "- [ ] Capture evidence if the command affects a decision.\n"
            "- [ ] Inspect Git diff before staging generated changes.\n")))

(defun gnopon/preview-project-command (command)
  "Preview COMMAND risk and follow-up policy."
  (interactive (list (gnopon/read-project-command)))
  (let ((buffer (get-buffer-create "*gnopon-command-preview*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/command-preview-text command))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/run-project-command (command)
  "Run COMMAND through `compile' at the project root after risk confirmation."
  (interactive (list (gnopon/read-project-command)))
  (gnopon/confirm-command-risk command)
  (let ((default-directory (gnopon/project-root)))
    (compile command)))

(defun gnopon/shell-log-path ()
  "Return a timestamped project-local shell log path."
  (let ((dir (gnopon/project-file "logs/shell/")))
    (make-directory dir t)
    (expand-file-name (format "%s-command.md" (format-time-string "%Y%m%d-%H%M%S")) dir)))

(defun gnopon/run-project-command-log (command)
  "Run COMMAND after confirmation and write output to a Markdown shell log."
  (interactive (list (gnopon/read-project-command)))
  (let ((risk (gnopon/confirm-command-risk command))
        (path (gnopon/shell-log-path))
        (default-directory (gnopon/project-root))
        (buffer (get-buffer-create "*gnopon-shell-command-log*"))
        (exit-code nil))
    (with-current-buffer buffer
      (erase-buffer)
      (insert "# Shell Command Log\n\n")
      (insert "- command: `" command "`\n")
      (insert "- risk: `" (format "%s" risk) "`\n")
      (insert "- project: `" default-directory "`\n")
      (insert "- created: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n\n")
      (insert "## Output\n\n```text\n")
      (setq exit-code (call-process shell-file-name nil buffer t shell-command-switch command))
      (insert "\n```\n\n")
      (insert (format "exit-code: `%s`\n" exit-code))
      (write-region (point-min) (point-max) path))
    (find-file path)))

(transient-define-prefix gnopon/command-cockpit ()
  "Safe project command runner."
  [["Run"
    ("p" "preview command" gnopon/preview-project-command)
    ("c" "compile command" gnopon/run-project-command)
    ("l" "run and log" gnopon/run-project-command-log)]
   ["Shell"
    ("e" "project eshell" gnopon/project-eshell)
    ("t" "project terminal" gnopon/project-terminal)]])

(define-key gnopon-map (kbd "s e") #'gnopon/project-eshell)
(define-key gnopon-map (kbd "s t") #'gnopon/project-terminal)
(define-key gnopon-map (kbd "s c") #'gnopon/command-cockpit)

(provide 'gnopon-shell)
;;; gnopon-shell.el ends here
