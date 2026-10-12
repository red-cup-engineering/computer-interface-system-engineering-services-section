;;; gnopon-actions.el --- Contextual actions for the current work item -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)
(require 'gnopon-markdown)
(require 'gnopon-predication)
(require 'gnopon-context)
(require 'gnopon-agents)
(require 'transient)

(defvar gnopon-action-note-directory "docs/notes/"
  "Project-relative directory for file-scoped Markdown notes.")

(defun gnopon/current-file-relative-name ()
  "Return the current buffer file relative to the project, or nil."
  (when buffer-file-name
    (file-relative-name (file-truename buffer-file-name)
                        (file-truename (gnopon/project-root)))))

(defun gnopon/current-work-subject ()
  "Return a stable subject string for the current buffer or project."
  (or (gnopon/current-file-relative-name)
      (buffer-name)
      (file-name-nondirectory
       (directory-file-name (file-truename (gnopon/project-root))))))

(defun gnopon/current-file-reference ()
  "Return a GitHub-friendly reference for the current point."
  (let ((subject (gnopon/current-work-subject)))
    (if buffer-file-name
        (format "%s:%d" subject (line-number-at-pos))
      subject)))

(defun gnopon/copy-current-reference ()
  "Copy a project-relative file reference for the current point."
  (interactive)
  (let ((reference (gnopon/current-file-reference)))
    (kill-new reference)
    (message "Copied %s" reference)))

(defun gnopon/action-note-path ()
  "Return a project-local note path for the current work subject."
  (let* ((subject (gnopon/current-work-subject))
         (slug (gnopon/markdown-slugify subject))
         (dir (gnopon/project-file gnopon-action-note-directory)))
    (make-directory dir t)
    (expand-file-name (format "%s-%s.md" (format-time-string "%Y%m%d") slug) dir)))

(defun gnopon/capture-current-note ()
  "Create a Markdown note about the current file or buffer."
  (interactive)
  (let* ((subject (gnopon/current-work-subject))
         (reference (gnopon/current-file-reference))
         (source-file buffer-file-name)
         (source-text (when buffer-file-name
                        (buffer-substring-no-properties (point-min) (point-max))))
         (path (gnopon/action-note-path)))
    (find-file path)
    (when (= (point-min) (point-max))
      (insert (gnopon/markdown-frontmatter-string subject "active" nil '("note" "context")))
      (insert "# " subject "\n\n")
      (insert "## Reference\n\n- `" reference "`\n\n")
      (insert "## Observation\n\n")
      (when source-file
        (insert "```text\n")
        (insert (gnopon/truncate-text
                 (gnopon/redact-secrets
                  source-text)
                 4000))
        (insert "\n```\n\n"))
      (insert "## Next\n\n- [ ] \n"))))

(defun gnopon/create-predication-for-current-work (predicate object value regime side)
  "Create a predication cell for the current file, buffer, or project."
  (interactive
   (list (read-string "Predicate: ")
         (read-string "Object: ")
         (completing-read "Value: " gnopon/predication-values nil t nil nil "potential")
         (completing-read "Regime: " gnopon-evidence-regimes nil t nil nil "strict")
         (completing-read "Side: " gnopon-evidence-sides nil t nil nil "knowledge")))
  (gnopon/create-predication-cell
   (gnopon/current-work-subject)
   predicate
   object
   value
   regime
   side))

(defun gnopon/contextual-status ()
  "Open a Markdown status buffer for the current project and buffer."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-contextual-status*"))
        (root (file-truename (gnopon/project-root)))
        (subject (gnopon/current-work-subject)))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# Contextual Status\n\n")
      (insert "- project: `" root "`\n")
      (insert "- subject: `" subject "`\n")
      (insert "- reference: `" (gnopon/current-file-reference) "`\n\n")
      (insert "## Git\n\n```text\n")
      (insert (if (fboundp 'gnopon/git-status-short)
                  (gnopon/git-status-short)
                "git status unavailable"))
      (insert "\n```\n\n## Actions\n\n")
      (insert "- `C-c g . r`: copy current reference\n")
      (insert "- `C-c g . n`: capture note\n")
      (insert "- `C-c g . p`: create predication cell\n")
      (insert "- `C-c g . C`: copy redacted agent context\n")
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/open-current-context-bundle ()
  "Open a redacted context bundle focused from the current work item."
  (interactive)
  (gnopon/open-context-bundle))

(transient-define-prefix gnopon/context-actions ()
  "Contextual actions for the current file, buffer, or project."
  [["Current"
    ("s" "status" gnopon/contextual-status)
    ("r" "copy reference" gnopon/copy-current-reference)
    ("n" "capture note" gnopon/capture-current-note)
    ("p" "predication" gnopon/create-predication-for-current-work)]
   ["Code"
    ("t" "test project" gnopon/test-project)
    ("c" "check project" gnopon/check-project)
    ("f" "format buffer" gnopon/format-buffer)]
   ["Agent"
    ("C" "copy context" gnopon/copy-context-bundle)
    ("O" "open context" gnopon/open-current-context-bundle)
    ("H" "agent handoff" gnopon/open-agent-handoff)
    ("S" "agent shell" gnopon/agent-shell)
    ("N" "new session" gnopon/start-agent-session)]
   ["Review"
    ("g" "git status" gnopon/git-status)
    ("v" "review diff" gnopon/review-agent-diff)
    ("m" "commit draft" gnopon/draft-commit-message)
    ("P" "PR draft" gnopon/draft-pr-description)]])

(define-key gnopon-map (kbd ".") #'gnopon/context-actions)

(with-eval-after-load 'embark
  (defvar-keymap gnopon-embark-file-map
    :doc "Gnopon actions for file targets."
    "r" #'gnopon/copy-current-reference
    "n" #'gnopon/capture-current-note
    "p" #'gnopon/create-predication-for-current-work
    "c" #'gnopon/copy-context-bundle)
  (add-to-list 'embark-keymap-alist '(file . gnopon-embark-file-map)))

(provide 'gnopon-actions)
;;; gnopon-actions.el ends here
