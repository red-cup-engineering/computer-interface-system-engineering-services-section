;;; gnopon-doctor.el --- Environment diagnostics -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)

(defvar gnopon-doctor-tools
  '(("rg" . "fast project search")
    ("git" . "version control")
    ("gh" . "GitHub PR and check inspection")
    ("node" . "Node.js runtime")
    ("npm" . "Node package manager fallback")
    ("pnpm" . "preferred Node package manager")
    ("bun" . "alternate Node runtime/test runner")
    ("cargo" . "Rust build and test")
    ("rust-analyzer" . "Rust language server")
    ("typescript-language-server" . "TypeScript language server")
    ("eslint" . "JavaScript/TypeScript linting")
    ("prettier" . "JavaScript/Markdown formatting")
    ("shellcheck" . "shell linting")
    ("shfmt" . "shell formatting")
    ("jq" . "JSON processing")
    ("direnv" . "project environment loading")
    ("pandoc" . "Markdown rendering/export")
    ("ollama" . "local AI backend"))
  "External tools GnoponEmacs can use.")

(defun gnopon/doctor-tool-row (tool description)
  "Return a Markdown row for TOOL and DESCRIPTION."
  (format "| `%s` | %s | %s |\n"
          tool
          (if (executable-find tool) "ok" "missing")
          description))

(defun gnopon/doctor-package-row (package)
  "Return a Markdown row for Emacs PACKAGE."
  (format "| `%s` | %s |\n"
          package
          (if (package-installed-p package) "installed" "missing")))

(defun gnopon/doctor-text ()
  "Return a Markdown health report for GnoponEmacs and project tooling."
  (concat "# GnoponEmacs Doctor\n\n"
          "- emacs: `" emacs-version "`\n"
          "- user-emacs-directory: `" user-emacs-directory "`\n"
          "- project: `" (file-truename (gnopon/project-root)) "`\n"
          "- package-dir: `" package-user-dir "`\n\n"
          "## External Tools\n\n"
          "| Tool | Status | Purpose |\n|---|---|---|\n"
          (mapconcat (lambda (tool)
                       (gnopon/doctor-tool-row (car tool) (cdr tool)))
                     gnopon-doctor-tools
                     "")
          "\n## Emacs Package Closure\n\n"
          "| Package | Status |\n|---|---|\n"
          (mapconcat #'gnopon/doctor-package-row gnopon-package-manifest "")
          "\n## Safety\n\n"
          "- AI calls are manual.\n"
          "- Shell commands are manual or confirmation-gated.\n"
          "- Git commit and push are not automated.\n"
          "- Markdown project memory is GitHub-renderable.\n\n"
          "## Follow-Up\n\n"
          "- command matrix: `C-c g p m`\n"
          "- capability audit: `C-c g d c`\n"
          "- safety audit: `C-c g d a`\n"))

(defun gnopon/doctor ()
  "Show a read-only health report for GnoponEmacs and project tooling."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-doctor*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/doctor-text))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/doctor-report-path ()
  "Return a project-local doctor report path."
  (let ((dir (gnopon/project-file "logs/doctor/")))
    (make-directory dir t)
    (expand-file-name
     (format "%s-doctor.md" (format-time-string "%Y%m%d-%H%M%S"))
     dir)))

(defun gnopon/write-doctor-report ()
  "Write a GnoponEmacs doctor report under `logs/doctor/'."
  (interactive)
  (let ((path (gnopon/doctor-report-path)))
    (with-temp-file path
      (insert (gnopon/doctor-text)))
    (find-file path)
    path))

(define-key gnopon-map (kbd "d d") #'gnopon/doctor)
(define-key gnopon-map (kbd "d D") #'gnopon/write-doctor-report)

(provide 'gnopon-doctor)
;;; gnopon-doctor.el ends here
