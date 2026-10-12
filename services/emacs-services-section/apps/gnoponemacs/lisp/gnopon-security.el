;;; gnopon-security.el --- Secrets and safety -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)

(use-package auth-source
  :ensure nil
  :custom
  (auth-sources '("~/.authinfo.gpg" "~/.netrc")))

(use-package epa
  :ensure nil
  :custom
  (epa-pinentry-mode 'loopback))

(use-package epg
  :ensure nil
  :custom
  (epg-pinentry-mode 'loopback))

(use-package password-store
  :if (and (executable-find "pass")
           (gnopon/optional-package-available-p 'password-store))
  :commands (password-store-copy password-store-insert))

(defcustom gnopon-safety-scan-max-chars 80000
  "Maximum characters retained from safety scan output."
  :type 'integer
  :group 'gnopon)

(defconst gnopon-safety-rg-pattern
  "api[_-]?key|token|secret|password|passwd|private[_-]?key|authorization"
  "Ripgrep pattern for likely secret-bearing lines.")

(defun gnopon/safety-process-output (&rest args)
  "Run ARGS with `call-process', returning combined output."
  (with-temp-buffer
    (let ((exit (apply #'call-process (car args) nil t nil (cdr args))))
      (concat (buffer-string)
              (unless (zerop exit)
                (format "\n[command exited with %s]" exit))))))

(defun gnopon/safety-rg-output ()
  "Return redacted project secret-pattern scan output."
  (if (executable-find "rg")
      (gnopon/redact-secrets
       (gnopon/truncate-text
        (gnopon/safety-process-output
         "rg" "-n" "-i" gnopon-safety-rg-pattern
         "--glob" "!.git"
         "--glob" "!node_modules"
         "--glob" "!dist"
         "--glob" "!build"
         "--glob" "!target"
         (gnopon/project-root))
        gnopon-safety-scan-max-chars))
    "rg unavailable"))

(defun gnopon/safety-git-diff-output (&rest args)
  "Return redacted git diff output for read-only ARGS."
  (gnopon/redact-secrets
   (gnopon/truncate-text
    (apply #'gnopon/safety-process-output "git" "-C" (gnopon/project-root) args)
    gnopon-safety-scan-max-chars)))

(defun gnopon/safety-boundary-report ()
  "Return a Markdown report of AI, shell, and secret safety boundaries."
  (concat
   "# GnoponEmacs Safety Audit\n\n"
   "- project: `" (file-truename (gnopon/project-root)) "`\n"
   "- created: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
   "- agent-command: `" gnopon-agent-command "`\n"
   "- agent-command-risk: `" (format "%s" (gnopon/safe-command-risk gnopon-agent-command)) "`\n"
   "- context-redaction: `enabled`\n"
   "- gptel-default: `local Ollama when configured; manual send only`\n\n"
   "## Invariants\n\n"
   "- Context bundles redact likely secret lines before copy/write.\n"
   "- Logged shell commands require confirmation and refuse dangerous commands.\n"
   "- Review and PR helpers draft local text; they do not commit, push, or create PRs.\n"
   "- AI buffers are human-triggered and do not silently send project buffers.\n\n"
   "## Likely Secret Lines\n\n```text\n"
   (gnopon/safety-rg-output)
   "\n```\n\n"
   "## Unstaged Diff Redaction Preview\n\n```diff\n"
   (gnopon/safety-git-diff-output "diff")
   "\n```\n\n"
   "## Staged Diff Redaction Preview\n\n```diff\n"
   (gnopon/safety-git-diff-output "diff" "--cached")
   "\n```\n"))

(defun gnopon/safety-audit ()
  "Open a read-only Markdown safety audit for the current project."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-safety-audit*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/safety-boundary-report))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/write-safety-audit ()
  "Write a project-local Markdown safety audit under `logs/security/'."
  (interactive)
  (let* ((dir (gnopon/project-file "logs/security/"))
         (path (expand-file-name
                (format "%s-safety-audit.md" (format-time-string "%Y%m%d-%H%M%S"))
                dir)))
    (make-directory dir t)
    (with-temp-file path
      (insert (gnopon/safety-boundary-report)))
    (find-file path)
    (message "Wrote safety audit to %s" path)))

(define-key gnopon-map (kbd "d a") #'gnopon/safety-audit)
(define-key gnopon-map (kbd "d A") #'gnopon/write-safety-audit)

(provide 'gnopon-security)
;;; gnopon-security.el ends here
