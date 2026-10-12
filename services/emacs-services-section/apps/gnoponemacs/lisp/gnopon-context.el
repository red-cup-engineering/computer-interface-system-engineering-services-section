;;; gnopon-context.el --- Safe project context bundles -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)
(require 'gnopon-markdown)

(defcustom gnopon-context-max-file-chars 60000
  "Maximum characters included from each project memory file."
  :type 'integer
  :group 'gnopon)

(defcustom gnopon-context-max-focus-chars 20000
  "Maximum characters included from the focused buffer or region."
  :type 'integer
  :group 'gnopon)

(defcustom gnopon-context-output-directory "logs/context/"
  "Project-relative directory for generated context bundles."
  :type 'string
  :group 'gnopon)

(defun gnopon/context-process-lines (&rest args)
  "Run process ARGS and return output or a failure string."
  (condition-case err
      (string-join (apply #'process-lines args) "\n")
    (error (format "unavailable: %s" (error-message-string err)))))

(defun gnopon/context-file-section (root file)
  "Return a Markdown context section for project FILE under ROOT."
  (let ((path (expand-file-name file root)))
    (when (file-readable-p path)
      (let ((text (with-temp-buffer
                    (insert-file-contents path)
                    (buffer-string))))
        (format "## `%s`\n\n```markdown\n%s\n```\n\n"
                file
                (gnopon/redact-secrets
                 (gnopon/truncate-text text gnopon-context-max-file-chars)))))))

(defun gnopon/context-git-section (root)
  "Return a Markdown Git context section for ROOT."
  (format "## Git Status\n\n```text\n%s\n```\n\n## Diff Stat\n\n```text\n%s\n```\n\n"
          (gnopon/context-process-lines "git" "-C" root "status" "--short")
          (gnopon/context-process-lines "git" "-C" root "diff" "--stat")))

(defun gnopon/context-focus-source (root)
  "Return a project-relative focus source under ROOT."
  (if buffer-file-name
      (file-relative-name (file-truename buffer-file-name) root)
    (buffer-name)))

(defun gnopon/context-focus-bounds ()
  "Return focused context bounds for the current buffer."
  (if (use-region-p)
      (cons (region-beginning) (region-end))
    (cons (point-min) (point-max))))

(defun gnopon/context-focus-section (root)
  "Return a redacted Markdown section for current buffer focus under ROOT."
  (unless (or (minibufferp)
              (string-prefix-p " " (buffer-name)))
    (let* ((bounds (gnopon/context-focus-bounds))
           (start (car bounds))
           (end (cdr bounds))
           (scope (if (use-region-p) "active-region" "buffer"))
           (source (gnopon/context-focus-source root))
           (start-line (line-number-at-pos start))
           (end-line (line-number-at-pos end))
           (text (buffer-substring-no-properties start end)))
      (format (concat "## Focused Work Item\n\n"
                      "- source: `%s`\n"
                      "- scope: `%s`\n"
                      "- lines: `%s-%s`\n\n"
                      "```text\n%s\n```\n\n")
              source
              scope
              start-line
              end-line
              (gnopon/redact-secrets
               (gnopon/truncate-text text gnopon-context-max-focus-chars))))))

(defun gnopon/context-bundle (&optional title)
  "Return a redacted Markdown context bundle for the current project.
Optional TITLE is used as the bundle title."
  (let* ((root (file-truename (gnopon/project-root)))
         (buffer-file (or (buffer-file-name) (buffer-name)))
         (focus-section (gnopon/context-focus-section root))
         (sections (delq nil
                         (mapcar (lambda (file)
                                   (gnopon/context-file-section root file))
                                 gnopon-context-files))))
    (concat "# " (or title "Agent Context Bundle") "\n\n"
            "- project: `" root "`\n"
            "- buffer: `" buffer-file "`\n"
            "- created: " (format-time-string "%Y-%m-%d %H:%M:%S") "\n\n"
            "## Safety Rules\n\n"
            "- Do not send secrets.\n"
            "- Do not run shell commands without explicit human confirmation.\n"
            "- Do not commit, push, or open PRs without human review.\n"
            "- Treat conflicts as evidence; do not erase them silently.\n\n"
            (gnopon/context-git-section root)
            (or focus-section "")
            "# Project Memory\n\n"
            (if sections
                (string-join sections "\n")
              "_No standard project memory files found._\n"))))

(defun gnopon/context-output-path ()
  "Return a timestamped project-local context bundle path."
  (let ((dir (gnopon/project-file gnopon-context-output-directory)))
    (make-directory dir t)
    (expand-file-name (format "%s-context.md" (format-time-string "%Y%m%d-%H%M%S")) dir)))

(defun gnopon/copy-context-bundle ()
  "Copy a redacted project context bundle to the kill ring."
  (interactive)
  (let ((bundle (gnopon/context-bundle)))
    (kill-new bundle)
    (message "Copied redacted context bundle for %s" (gnopon/project-root))))

(defun gnopon/write-context-bundle ()
  "Write a redacted project context bundle under `logs/context/'."
  (interactive)
  (let ((path (gnopon/context-output-path)))
    (with-temp-file path
      (insert (gnopon/context-bundle)))
    (find-file path)))

(defun gnopon/open-context-bundle ()
  "Open a read-only redacted context bundle buffer."
  (interactive)
  (let ((buffer (get-buffer-create "*context-bundle*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/context-bundle))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(define-key gnopon-map (kbd "a C") #'gnopon/copy-context-bundle)
(define-key gnopon-map (kbd "a W") #'gnopon/write-context-bundle)
(define-key gnopon-map (kbd "a O") #'gnopon/open-context-bundle)

(provide 'gnopon-context)
;;; gnopon-context.el ends here
