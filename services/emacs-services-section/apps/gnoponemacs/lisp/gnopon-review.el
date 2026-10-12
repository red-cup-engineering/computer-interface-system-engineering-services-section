;;; gnopon-review.el --- Review packets and GitHub handoff drafts -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)
(require 'gnopon-markdown)
(require 'gnopon-agents)
(require 'transient)

(defvar gnopon-review-directory "logs/review/"
  "Project-relative directory for generated review packets.")

(defun gnopon/review-directory ()
  "Return the project-local review packet directory."
  (let ((dir (gnopon/project-file gnopon-review-directory)))
    (make-directory dir t)
    dir))

(defun gnopon/review-packet-path ()
  "Return a timestamped project-local review packet path."
  (expand-file-name
   (format "%s-review-packet.md" (format-time-string "%Y%m%d-%H%M%S"))
   (gnopon/review-directory)))

(defun gnopon/review-process-lines (&rest args)
  "Run ARGS with `process-lines', returning output or an error string."
  (condition-case err
      (string-join (apply #'process-lines args) "\n")
    (error (format "unavailable: %s" (error-message-string err)))))

(defun gnopon/review-git (&rest args)
  "Run read-only git ARGS in the current project."
  (apply #'gnopon/review-process-lines "git" "-C" (gnopon/project-root) args))

(defun gnopon/review-recent-agent-sessions ()
  "Return recent agent session filenames as Markdown list items."
  (let* ((dir (gnopon/agent-session-dir))
         (files (when (file-directory-p dir)
                  (last (sort (directory-files dir nil "\\.md\\'") #'string<) 5))))
    (if files
        (mapconcat (lambda (file) (format "- `%s`" file)) files "\n")
      "- none")))

(defun gnopon/review-packet ()
  "Return a Markdown review packet for the current project."
  (let ((root (file-truename (gnopon/project-root))))
    (concat
     "# Review Packet\n\n"
     "- project: `" root "`\n"
     "- created: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
     "- branch: `" (gnopon/review-git "branch" "--show-current") "`\n\n"
     "## Review Checklist\n\n"
     "- [ ] Inspect unstaged and staged diffs.\n"
     "- [ ] Run relevant tests/checks.\n"
     "- [ ] Confirm generated changes are intentional.\n"
     "- [ ] Confirm no secrets or local-only paths are included.\n"
     "- [ ] Draft GitHub PR body from the evidence below.\n\n"
     "## Git Status\n\n```text\n"
     (gnopon/review-git "status" "--short")
     "\n```\n\n"
     "## Diff Stat\n\n```text\n"
     (gnopon/review-git "diff" "--stat")
     "\n```\n\n"
     "## Staged Diff Stat\n\n```text\n"
     (gnopon/review-git "diff" "--cached" "--stat")
     "\n```\n\n"
     "## Recent Commits\n\n```text\n"
     (gnopon/review-git "log" "--oneline" "-5")
     "\n```\n\n"
     "## Recent Agent Sessions\n\n"
     (gnopon/review-recent-agent-sessions)
     "\n\n"
     "## Tests\n\n- [ ] \n\n"
     "## PR Summary Draft\n\n"
     "### Summary\n\n- \n\n"
     "### Tests\n\n- [ ] \n\n"
     "### Review Notes\n\n- \n")))

(defun gnopon/open-review-packet ()
  "Open a read-only generated review packet buffer."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-review-packet*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/review-packet))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/write-review-packet ()
  "Write a Markdown review packet under `logs/review/'."
  (interactive)
  (let ((path (gnopon/review-packet-path)))
    (with-temp-file path
      (insert (gnopon/review-packet)))
    (find-file path)
    (message "Wrote review packet to %s" path)))

(defun gnopon/pr-body-draft ()
  "Return a GitHub PR body draft based on local review evidence."
  (concat
   "## Summary\n\n- \n\n"
   "## Tests\n\n- [ ] \n\n"
   "## Review Notes\n\n```text\n"
   (gnopon/review-git "status" "--short")
   "\n```\n\n```text\n"
   (gnopon/review-git "diff" "--stat")
   "\n```\n"))

(defun gnopon/pr-body-path ()
  "Return a timestamped project-local PR body path."
  (expand-file-name
   (format "%s-pr-body.md" (format-time-string "%Y%m%d-%H%M%S"))
   (gnopon/review-directory)))

(defun gnopon/write-pr-body-file (&optional open)
  "Write a GitHub PR body file under `logs/review/'.
When OPEN is non-nil, visit the generated file."
  (interactive (list t))
  (let ((path (gnopon/pr-body-path)))
    (with-temp-file path
      (insert (gnopon/pr-body-draft)))
    (when open
      (find-file path))
    (message "Wrote PR body draft to %s" path)
    path))

(defun gnopon/copy-pr-body ()
  "Copy a GitHub PR body draft based on local review evidence."
  (interactive)
  (let ((body (gnopon/pr-body-draft)))
    (kill-new body)
    (message "Copied PR body draft to kill ring")))

(defun gnopon/gh-pr-create-draft-command ()
  "Copy a conservative draft PR creation command to the kill ring."
  (interactive)
  (let ((body-file (gnopon/write-pr-body-file nil)))
    (let ((command (format "gh pr create --draft --title \"\" --body-file %s"
                           (shell-quote-argument body-file))))
      (kill-new command)
      (message "Copied: %s" command))))

(defun gnopon/gh-pr-create-draft (title)
  "Create a GitHub draft PR with TITLE after explicit confirmation."
  (interactive "sDraft PR title: ")
  (when (string-empty-p (string-trim title))
    (user-error "Draft PR title is required"))
  (unless (yes-or-no-p (format "Create GitHub draft PR for `%s` from %s? "
                               title
                               (gnopon/project-root)))
    (user-error "Canceled"))
  (let ((body-file (gnopon/write-pr-body-file nil)))
    (gnopon/gh-command-to-buffer
     "pr-create-draft"
     "pr" "create"
     "--draft"
     "--title" title
     "--body-file" body-file)))

(transient-define-prefix gnopon/review-cockpit ()
  "Review and GitHub handoff actions."
  [["Inspect"
    ("s" "git status" gnopon/git-status)
    ("d" "review diff" gnopon/review-agent-diff)
    ("o" "open packet" gnopon/open-review-packet)
    ("w" "write packet" gnopon/write-review-packet)]
   ["Evidence"
    ("t" "test" gnopon/test-project)
    ("c" "check" gnopon/check-project)
    ("l" "log command" gnopon/capture-command-log)
    ("S" "agent sessions" gnopon/agent-session-index)]
   ["GitHub"
    ("d" "dashboard" gnopon/github-dashboard)
    ("p" "PR list" gnopon/gh-pr-list)
    ("S" "PR status" gnopon/gh-pr-status)
    ("v" "view PR" gnopon/gh-pr-view-current)
    ("k" "checks" gnopon/gh-pr-checks)
    ("i" "issues" gnopon/gh-issue-list)
    ("B" "write PR body" gnopon/write-pr-body-file)
    ("b" "copy PR body" gnopon/copy-pr-body)
    ("g" "copy gh draft command" gnopon/gh-pr-create-draft-command)
    ("G" "create draft PR" gnopon/gh-pr-create-draft)]])

(define-key gnopon-map (kbd "r") #'gnopon/review-cockpit)

(provide 'gnopon-review)
;;; gnopon-review.el ends here
