;;; gnopon-git.el --- Git and review workflow -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)

(gnopon/use-optional-package magit
  :commands (magit-status magit-project-status magit-log-buffer-file)
  :bind
  (("C-x g" . magit-status))
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

(gnopon/use-optional-package forge
  :after magit)

(gnopon/use-optional-package diff-hl
  :hook
  (prog-mode . diff-hl-mode)
  (text-mode . diff-hl-mode)
  (magit-pre-refresh . diff-hl-magit-pre-refresh)
  (magit-post-refresh . diff-hl-magit-post-refresh))

(defun gnopon/git-status ()
  "Open Magit for the current project."
  (interactive)
  (if (fboundp 'magit-status)
      (magit-status (gnopon/project-root))
    (let ((buffer (get-buffer-create "*gnopon-git-status*")))
      (with-current-buffer buffer
        (read-only-mode -1)
        (erase-buffer)
        (insert "# Git Status\n\n```text\n")
        (insert (gnopon/git-output "status" "--short"))
        (insert "\n```\n\n")
        (insert "Magit is not installed; using read-only `git status --short` output.\n")
        (gnopon/markdown-buffer-mode)
        (goto-char (point-min))
        (read-only-mode 1))
      (pop-to-buffer buffer))))

(defun gnopon/git-project-status ()
  "Open Magit project status, falling back to a read-only Git status buffer."
  (interactive)
  (if (fboundp 'magit-project-status)
      (magit-project-status)
    (gnopon/git-status)))

(defun gnopon/git-log-buffer-file ()
  "Open Magit buffer log, falling back to read-only `git log' output."
  (interactive)
  (if (fboundp 'magit-log-buffer-file)
      (magit-log-buffer-file)
    (let ((buffer (get-buffer-create "*gnopon-git-log*")))
      (with-current-buffer buffer
        (read-only-mode -1)
        (erase-buffer)
        (insert "# Git Log\n\n```text\n")
        (insert (gnopon/git-output "log" "--oneline" "--decorate" "--max-count" "40"
                                   "--" (or buffer-file-name ".")))
        (insert "\n```\n\n")
        (insert "Magit is not installed; using read-only `git log` output.\n")
        (gnopon/markdown-buffer-mode)
        (goto-char (point-min))
        (read-only-mode 1))
      (pop-to-buffer buffer))))

(defun gnopon/git-show-hunk ()
  "Show current diff-hl hunk when available."
  (interactive)
  (if (fboundp 'diff-hl-show-hunk)
      (diff-hl-show-hunk)
    (user-error "diff-hl is not installed; use C-c g g s for Git status")))

(defun gnopon/git-output (&rest args)
  "Return read-only git ARGS output for the current project."
  (condition-case err
      (string-trim
       (string-join
        (apply #'process-lines "git" "-C" (gnopon/project-root) args)
        "\n"))
    (error (format "unavailable: %s" (error-message-string err)))))

(defun gnopon/github-dashboard-text ()
  "Return a local, read-only GitHub workflow dashboard."
  (let* ((root (file-truename (gnopon/project-root)))
         (branch (gnopon/git-output "branch" "--show-current"))
         (remote (gnopon/git-output "remote" "get-url" "origin"))
         (gh-status (if (executable-find "gh") "available" "missing")))
    (concat
     "# GitHub Cockpit\n\n"
     "- project: `" root "`\n"
     "- branch: `" branch "`\n"
     "- origin: `" remote "`\n"
     "- gh: `" gh-status "`\n\n"
     "## Local Review\n\n"
     "- Magit status: `C-c g g s` or `C-x g`\n"
     "- project status: `C-c g g p`\n"
     "- buffer log: `C-c g g l`\n"
     "- review cockpit: `C-c g r`\n\n"
     "## GitHub Read Models\n\n"
     "- repository metadata: `C-c g g h r`\n"
     "- pull requests: `C-c g g h p`\n"
     "- current branch PR status: `C-c g g h s`\n"
     "- current branch PR JSON: `C-c g g h v`\n"
     "- PR checks: `C-c g g h c`\n"
     "- issues: `C-c g g h i`\n\n"
     "## Handoff\n\n"
     "- write review packet: `C-c g r w`\n"
     "- write PR body: `C-c g r B`\n"
     "- copy draft PR command: `C-c g r g`\n"
     "- create draft PR with confirmation: `C-c g r G`\n\n")))

(defun gnopon/github-dashboard ()
  "Open a read-only GitHub workflow dashboard."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-github*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/github-dashboard-text))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/gh-command-to-buffer (name &rest args)
  "Run gh ARGS in a project buffer named NAME."
  (unless (executable-find "gh")
    (user-error "gh executable not found"))
  (let ((buffer (get-buffer-create (format "*gh:%s*" name)))
        (default-directory (gnopon/project-root)))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (let ((exit (let ((process-environment (cons "GH_PROMPT_DISABLED=1" process-environment)))
                    (apply #'call-process "gh" nil buffer t args))))
        (goto-char (point-min))
        (gnopon/markdown-buffer-mode)
        (read-only-mode 1)
        (message "gh %s exited with %s" (string-join args " ") exit)))
    (pop-to-buffer buffer)))

(defun gnopon/gh-pr-list ()
  "Show GitHub PRs for the current repository."
  (interactive)
  (gnopon/gh-command-to-buffer "pr-list" "pr" "list" "--limit" "20"))

(defun gnopon/gh-pr-status ()
  "Show GitHub PR status for the current repository."
  (interactive)
  (gnopon/gh-command-to-buffer "pr-status" "pr" "status"))

(defun gnopon/gh-pr-view-current ()
  "Show GitHub metadata for the PR associated with the current branch."
  (interactive)
  (gnopon/gh-command-to-buffer
   "pr-view"
   "pr" "view"
   "--json" "number,title,state,isDraft,headRefName,baseRefName,url,mergeStateStatus,reviewDecision,statusCheckRollup"
   "--jq" "."))

(defun gnopon/gh-pr-checks ()
  "Show GitHub checks for the selected PR."
  (interactive)
  (gnopon/gh-command-to-buffer "pr-checks" "pr" "checks"))

(defun gnopon/gh-issue-list ()
  "Show open GitHub issues for the current repository."
  (interactive)
  (gnopon/gh-command-to-buffer "issue-list" "issue" "list" "--limit" "20"))

(defun gnopon/gh-repo-view ()
  "Show GitHub repository metadata."
  (interactive)
  (gnopon/gh-command-to-buffer "repo-view" "repo" "view"))

(define-key gnopon-map (kbd "g s") #'gnopon/git-status)
(define-key gnopon-map (kbd "g p") #'gnopon/git-project-status)
(define-key gnopon-map (kbd "g l") #'gnopon/git-log-buffer-file)
(define-key gnopon-map (kbd "g h d") #'gnopon/github-dashboard)
(define-key gnopon-map (kbd "g h p") #'gnopon/gh-pr-list)
(define-key gnopon-map (kbd "g h s") #'gnopon/gh-pr-status)
(define-key gnopon-map (kbd "g h v") #'gnopon/gh-pr-view-current)
(define-key gnopon-map (kbd "g h c") #'gnopon/gh-pr-checks)
(define-key gnopon-map (kbd "g h i") #'gnopon/gh-issue-list)
(define-key gnopon-map (kbd "g h r") #'gnopon/gh-repo-view)

(provide 'gnopon-git)
;;; gnopon-git.el ends here
