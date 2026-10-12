;;; vibemacs-evidence.el --- Project and source evidence for Vibemacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Git, source, buffer, and project evidence used by Vibemacs artifacts.

;;; Code:

(require 'subr-x)
(require 'cl-lib)
(require 'vibemacs-foundation)
(require 'vibemacs-workflow)
(defun vibemacs--process-lines (program &rest args)
  "Return trimmed output lines from PROGRAM called with ARGS.
Return nil when PROGRAM is missing or exits unsuccessfully."
  (when (executable-find program)
    (with-temp-buffer
      (when (= 0 (apply #'call-process program nil t nil args))
        (split-string (string-trim (buffer-string)) "\n" t)))))

(defun vibemacs--process-output (program &rest args)
  "Return trimmed output from PROGRAM called with ARGS.
Return nil when PROGRAM is missing or exits unsuccessfully."
  (when (executable-find program)
    (with-temp-buffer
      (when (= 0 (apply #'call-process program nil t nil args))
        (string-trim-right (buffer-string))))))

(defun vibemacs-git-branch (&optional root)
  "Return the Git branch for ROOT, or nil outside Git."
  (let ((default-directory (or root (vibemacs-project-root))))
    (car (vibemacs--process-lines "git" "branch" "--show-current"))))

(defun vibemacs-git-changed-files (&optional root)
  "Return changed Git files for ROOT as status-prefixed strings."
  (let ((default-directory (or root (vibemacs-project-root))))
    (vibemacs--process-lines "git" "status" "--short")))

(defun vibemacs-git-diff-stat (&optional root)
  "Return Git diff stat lines for ROOT."
  (let ((default-directory (or root (vibemacs-project-root))))
    (when-let ((output (vibemacs--process-output
                        "git" "diff" "--stat" "HEAD" "--")))
      (split-string output "\n" t))))

(defun vibemacs-git-diff-lines (&optional root)
  "Return Git diff lines for ROOT."
  (let ((default-directory (or root (vibemacs-project-root))))
    (when-let ((output (vibemacs--process-output
                        "git" "diff" "--no-ext-diff" "--unified=3" "HEAD" "--")))
      (split-string output "\n"))))

(defun vibemacs-git-status-file (status-line)
  "Return the file path from a Git porcelain STATUS-LINE."
  (let* ((trimmed (string-trim-left status-line))
         (path (cond
                ((string-match "\\`.. \\(.+\\)\\'" status-line)
                 (match-string 1 status-line))
                ((string-match "\\`[ A-Z?!][ A-Z?!]?[ \t]+\\(.+\\)\\'"
                               trimmed)
                 (match-string 1 trimmed))
                (t
                 status-line))))
    (if (string-match " -> \\(.+\\)\\'" path)
        (match-string 1 path)
      path)))

(defun vibemacs-changed-file-paths (changed-files &optional root)
  "Return project-relative files parsed from CHANGED-FILES status lines.

Git porcelain can collapse an untracked directory to one status line.  Expand
such a directory under ROOT so a dependency map always receives files, never
a directory to read as though it were source."
  (let ((project-root (file-name-as-directory
                       (or root (vibemacs-project-root))))
        paths)
    (dolist (line changed-files)
      (let* ((path (string-trim (vibemacs-git-status-file line)))
             (file (expand-file-name path project-root)))
        (unless (string-empty-p path)
          (setq paths
                (nconc paths
                       (cond
                        ((file-directory-p file)
                         (mapcar (lambda (child)
                                   (file-relative-name child project-root))
                                 (directory-files-recursively file ".*")))
                        ((file-regular-p file) (list path))
                        ;; Deleted and renamed paths still belong in the map;
                        ;; the renderer describes their unavailable source.
                        (t (list path)))))))
    (seq-take (delete-dups paths) vibemacs-dependency-map-file-limit))))

(defun vibemacs-source-dependencies (file)
  "Return source dependency strings detected in FILE."
  (let ((extension (downcase (or (file-name-extension file) "")))
        (dependencies nil))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (pcase extension
          ("el"
          (goto-char (point-min))
          (while (re-search-forward
                  "(\\s-*require\\s-+'\\([^][() \t\n]+\\)" nil t)
            (push (match-string 1) dependencies))
          (goto-char (point-min))
          (while (re-search-forward
                  "(\\s-*load\\s-+\"\\([^\"]+\\)\"" nil t)
            (push (match-string 1) dependencies)))
         ((or "js" "mjs" "cjs" "ts" "tsx" "jsx")
          (dolist (line (split-string (buffer-string) "\n"))
            (cond
             ((string-match
               "^[ \t]*import[ \t].*from[ \t]+['\"]\\([^'\"]+\\)['\"]"
               line)
              (push (match-string 1 line) dependencies))
             ((string-match
               "^[ \t]*import[ \t]+['\"]\\([^'\"]+\\)['\"]"
               line)
              (push (match-string 1 line) dependencies))
             ((string-match
               "require[ \t]*(?[ \t]*['\"]\\([^'\"]+\\)['\"]"
               line)
              (push (match-string 1 line) dependencies))))))))
    (delete-dups (nreverse dependencies))))

(defun vibemacs-changed-file-dependency-map (root changed-files)
  "Return dependency entries for CHANGED-FILES under ROOT."
  (mapcar
   (lambda (path)
     (let ((file (expand-file-name path root)))
       (list :file path
             :readable (file-readable-p file)
             :dependencies (vibemacs-source-dependencies file))))
   (vibemacs-changed-file-paths changed-files root)))

(defun vibemacs-render-dependency-map (entries)
  "Render dependency map ENTRIES as Markdown bullets."
  (if entries
      (string-join
       (mapcar
        (lambda (entry)
          (let ((file (plist-get entry :file))
                (readable (plist-get entry :readable))
                (dependencies (plist-get entry :dependencies)))
            (cond
             ((not readable)
              (format "- `%s`: file is not readable in the working tree." file))
             (dependencies
              (format "- `%s`: %s"
                      file
                      (string-join
                       (mapcar (lambda (dependency)
                                 (format "`%s`" dependency))
                               dependencies)
                       ", ")))
             (t
              (format "- `%s`: no source dependencies detected." file)))))
        entries)
       "\n")
    "- No changed files available for dependency mapping."))

(defun vibemacs-open-file-buffers (&optional root)
  "Return project-relative open file buffers under ROOT."
  (let ((project-root (file-name-as-directory (or root (vibemacs-project-root)))))
    (sort
     (delq nil
           (mapcar
            (lambda (buffer)
              (with-current-buffer buffer
                (when (and buffer-file-name
                           (file-in-directory-p buffer-file-name project-root))
                  (file-relative-name buffer-file-name project-root))))
            (buffer-list)))
     #'string<)))

(defun vibemacs--files-in-directory (root directory regexp)
  "Return files under ROOT/DIRECTORY matching REGEXP."
  (let ((target (expand-file-name directory root)))
    (if (file-directory-p target)
        (directory-files-recursively target regexp)
      '())))

(defun vibemacs--count-file-matches (files regexp)
  "Return the number of REGEXP matches across FILES."
  (let ((count 0))
    (dolist (file files count)
      (when (file-readable-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (while (re-search-forward regexp nil t)
            (setq count (1+ count))))))))

(defun vibemacs--present-files (root files)
  "Return FILES that exist under ROOT."
  (seq-filter (lambda (file) (file-exists-p (expand-file-name file root))) files))

(defun vibemacs-project-diagnostics (&optional root)
  "Return human-readable project diagnostics for ROOT."
  (let* ((project-root (file-name-as-directory (or root (vibemacs-project-root))))
         (entrypoints (vibemacs--present-files
                       project-root
                       '("early-init.el" "init.el" "README.md" "package.json")))
         (lisp-files (vibemacs--files-in-directory project-root "lisp" "\\.el\\'"))
         (test-files (vibemacs--files-in-directory project-root "test" "\\.el\\'"))
         (journal-files (vibemacs--files-in-directory
                         project-root "dev/docs/journal" "\\.md\\'"))
         (task-files (vibemacs-task-files project-root))
         (ert-count (vibemacs--count-file-matches test-files "^(ert-deftest\\_>")))
    (list
     (format "Entrypoints present: %s"
             (if entrypoints (string-join entrypoints ", ") "none"))
     (format "Emacs Lisp modules: %d under lisp/" (length lisp-files))
     (format "ERT coverage: %d tests across %d files" ert-count (length test-files))
     (format "Public journal entries: %d under dev/docs/journal/" (length journal-files))
     (format "Task files: %d under %s/" (length task-files) vibemacs-task-directory)
     (format "Package metadata: %s"
             (if (file-exists-p (expand-file-name "package.json" project-root))
                 "package.json present"
               "package.json missing")))))

(defun vibemacs-project-snapshot (&optional title)
  "Return an alist describing the current project for an agent packet.
Optional TITLE becomes the packet title."
  (let ((root (vibemacs-project-root)))
    `((title . ,(or title "Agent Context"))
      (root . ,root)
      (branch . ,(or (vibemacs-git-branch root) "(none)"))
      (changed-files . ,(or (vibemacs-git-changed-files root) '()))
      (open-files . ,(or (vibemacs-open-file-buffers root) '()))
      (task-files . ,(vibemacs-recent-task-files root))
      (task-summaries . ,(vibemacs-task-summaries root))
      (journal-files . ,(vibemacs-journal-files root))
      (note-files . ,(vibemacs-note-files root))
      (diagnostics . ,(vibemacs-project-diagnostics root))
      (verification . ,vibemacs-verification-commands)
      (verification-history . ,vibemacs-verification-history)
      (session-file . ,(vibemacs-session-path root)))))

(defun vibemacs-artifact-snapshot (&optional title)
  "Return an alist describing Vibemacs artifacts for TITLE."
  (let ((snapshot (vibemacs-project-snapshot (or title "Artifact Index"))))
    `((title . ,(alist-get 'title snapshot))
      (root . ,(alist-get 'root snapshot))
      (branch . ,(alist-get 'branch snapshot))
      (session-file . ,(alist-get 'session-file snapshot))
      (session-present . ,(file-exists-p (alist-get 'session-file snapshot)))
      (changed-files . ,(alist-get 'changed-files snapshot))
      (open-files . ,(alist-get 'open-files snapshot))
      (task-files . ,(alist-get 'task-files snapshot))
      (task-summaries . ,(alist-get 'task-summaries snapshot))
      (journal-files . ,(alist-get 'journal-files snapshot))
      (note-files . ,(alist-get 'note-files snapshot))
      (verification-history . ,(alist-get 'verification-history snapshot)))))

(defun vibemacs--markdown-list (items &optional empty-label)
  "Render ITEMS as a Markdown list.
Use EMPTY-LABEL when ITEMS is nil."
  (if items
      (string-join (mapcar (lambda (item) (concat "- `" item "`")) items) "\n")
    (concat "- " (or empty-label "(none)"))))

(defun vibemacs--limit-lines (lines limit)
  "Return a plist containing LINES truncated to LIMIT."
  (let* ((items (or lines '()))
         (kept (seq-take items limit)))
    (list :lines kept
          :line-count (length items)
          :included-lines (length kept)
          :omitted-lines (max 0 (- (length items) (length kept))))))

(defun vibemacs-source-language (file)
  "Return a Markdown fence language for FILE."
  (pcase (downcase (or (file-name-extension (or file "")) ""))
    ("el" "elisp")
    ("js" "javascript")
    ("mjs" "javascript")
    ("cjs" "javascript")
    ("ts" "typescript")
    ("tsx" "tsx")
    ("jsx" "jsx")
    ("json" "json")
    ("md" "markdown")
    ("css" "css")
    ("html" "html")
    ("py" "python")
    ("rs" "rust")
    ("sh" "sh")
    ("bash" "bash")
    ("toml" "toml")
    ("yaml" "yaml")
    ("yml" "yaml")
    (_ "")))

(defun vibemacs-source-file-label (&optional file root)
  "Return a project-relative label for FILE under ROOT."
  (let* ((source (or file buffer-file-name))
         (project-root (file-name-as-directory (or root (vibemacs-project-root)))))
    (cond
     ((and source (file-in-directory-p source project-root))
      (file-relative-name source project-root))
     (source (abbreviate-file-name source))
     (t (buffer-name)))))

(defun vibemacs-source-context-range ()
  "Return a plist describing the current source context range."
  (cond
   ((use-region-p)
    (list :start (region-beginning)
          :end (region-end)
          :scope "active region"))
   ((bounds-of-thing-at-point 'defun)
    (let ((bounds (bounds-of-thing-at-point 'defun)))
      (list :start (car bounds)
            :end (cdr bounds)
            :scope "current definition")))
   (t
    (list :start (line-beginning-position)
          :end (line-end-position)
          :scope "current line"))))

(defun vibemacs-line-numbered-source (start end &optional limit)
  "Return source between START and END with line numbers.
LIMIT restricts the number of included lines."
  (let* ((max-lines (or limit vibemacs-source-context-line-limit))
         (start-line (line-number-at-pos start))
         (text (buffer-substring-no-properties start end))
         (lines (split-string text "\n"))
         (line-count (length lines))
         (included-lines (seq-take lines max-lines))
         (omitted (max 0 (- line-count (length included-lines))))
         (rendered
          (string-join
           (cl-loop for line in included-lines
                    for number from start-line
                    collect (format "%4d | %s" number line))
           "\n")))
    (if (> omitted 0)
        (format "%s\n     | [... %d lines omitted ...]" rendered omitted)
      rendered)))

(defun vibemacs-code-context-snapshot (&optional start end scope)
  "Return an alist describing source context between START and END.
SCOPE describes how the range was selected."
  (let* ((range (unless (and start end)
                  (vibemacs-source-context-range)))
         (range-start (or start (plist-get range :start)))
         (range-end (or end (plist-get range :end)))
         (range-scope (or scope (plist-get range :scope)))
         (root (vibemacs-project-root))
         (file-label (vibemacs-source-file-label buffer-file-name root))
         (source-lines (split-string
                        (buffer-substring-no-properties range-start range-end)
                        "\n"))
         (line-count (length source-lines))
         (included-count (min line-count vibemacs-source-context-line-limit)))
    `((title . ,(format "%s:%d-%d"
                        file-label
                        (line-number-at-pos range-start)
                        (line-number-at-pos (max range-start (1- range-end)))))
      (root . ,root)
      (branch . ,(or (vibemacs-git-branch root) "(none)"))
      (file . ,file-label)
      (scope . ,range-scope)
      (start-line . ,(line-number-at-pos range-start))
      (end-line . ,(line-number-at-pos (max range-start (1- range-end))))
      (line-count . ,line-count)
      (included-lines . ,included-count)
      (omitted-lines . ,(max 0 (- line-count included-count)))
      (language . ,(vibemacs-source-language buffer-file-name))
      (source . ,(vibemacs-line-numbered-source range-start range-end)))))

(defun vibemacs-render-source-context (snapshot)
  "Render SNAPSHOT as a Markdown source context packet."
  (let-alist snapshot
    (string-join
     (append
      (list
       (format "# Source Context: %s" .title)
       ""
       "## Project"
       ""
       (format "- Root: `%s`" .root)
       (format "- Branch: `%s`" .branch)
       ""
       "## Source"
       ""
       (format "- File: `%s`" .file)
       (format "- Lines: `%d-%d`" .start-line .end-line)
       (format "- Scope: `%s`" .scope))
      (when (> .omitted-lines 0)
        (list (format "- Excerpt: first `%d` of `%d` lines"
                      .included-lines .line-count)))
      (list
       ""
       "## Line-Numbered Excerpt"
       ""
       (format "```%s" .language)
       .source
       "```"
       ""
      "## Agent Notes"
      ""
      "- Treat this excerpt as context, not as a substitute for reading adjacent code."
      "- Preserve local style and verify changes against the project gates."
      ""))
     "\n")))

(defun vibemacs-change-review-snapshot (&optional title)
  "Return an alist describing the current Git changes for review."
  (let* ((root (vibemacs-project-root))
         (diff (vibemacs--limit-lines
                (vibemacs-git-diff-lines root)
                vibemacs-change-review-line-limit)))
    `((title . ,(or title "Change Review"))
      (root . ,root)
      (branch . ,(or (vibemacs-git-branch root) "(none)"))
      (changed-files . ,(or (vibemacs-git-changed-files root) '()))
      (diff-stat . ,(or (vibemacs-git-diff-stat root) '()))
      (diff-lines . ,(plist-get diff :lines))
      (diff-line-count . ,(plist-get diff :line-count))
      (included-diff-lines . ,(plist-get diff :included-lines))
      (omitted-diff-lines . ,(plist-get diff :omitted-lines))
      (verification-history . ,vibemacs-verification-history))))

(defun vibemacs-render-change-review (snapshot)
  "Render SNAPSHOT as a Markdown change review packet."
  (let-alist snapshot
    (string-join
     (append
      (list
       (format "# Change Review: %s" .title)
       ""
       "## Project"
       ""
       (format "- Root: `%s`" .root)
       (format "- Branch: `%s`" .branch)
       ""
       "## Changed Files"
       ""
       (vibemacs--markdown-list .changed-files "No Git changes detected.")
       ""
       "## Diff Stat"
       ""
       (vibemacs--markdown-list .diff-stat "No diff stat available.")
       ""
       "## Diff Excerpt"
       "")
      (when (> .omitted-diff-lines 0)
        (list (format "- Showing first `%d` of `%d` diff lines."
                      .included-diff-lines .diff-line-count)
              ""))
      (list
       "```diff"
       (if .diff-lines
           (string-join .diff-lines "\n")
         "No diff output available.")
       "```"
       ""
       "## Recent Verification"
       ""
       (vibemacs-render-verification-history .verification-history)
       ""
       "## Review Prompts"
       ""
       "- Does the diff match the stated task?"
       "- Are there unrelated changes that should be split out?"
       "- Which verification result proves the changed behavior?"
       ""))
     "\n")))

(defun vibemacs--plural (count singular plural)
  "Return COUNT with SINGULAR or PLURAL label."
  (format "%d %s" count (if (= count 1) singular plural)))

(defun vibemacs-render-context-packet (snapshot)
  "Render SNAPSHOT as a Markdown project context packet."
  (let-alist snapshot
    (string-join
     (list
      (format "# Agent Context: %s" .title)
      ""
      "## Project"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Session: `%s`" .session-file)
      ""
      "## Project Diagnostics"
      ""
      (vibemacs--markdown-list .diagnostics "No project diagnostics available.")
      ""
      "## Changed Files"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Open Project Buffers"
      ""
      (vibemacs--markdown-list .open-files "No project files are open.")
      ""
      "## Recent Task Files"
      ""
      (vibemacs--markdown-list .task-files "No persisted task files found.")
      ""
      "## Recent Task Status"
      ""
      (vibemacs--markdown-list .task-summaries "No task status available.")
      ""
      "## Suggested Verification"
      ""
      (vibemacs--markdown-list .verification "No verification commands configured.")
      ""
      "## Agent Instructions"
      ""
      (string-join (mapcar (lambda (item) (concat "- " item))
                           vibemacs-default-constraints)
                   "\n")
      ""
      "## Notes"
      "")
     "\n")))

(defun vibemacs-render-handoff-bundle (snapshot)
  "Render SNAPSHOT as a copyable Markdown handoff bundle."
  (let-alist snapshot
    (string-join
     (list
      (format "# Vibemacs Agent Handoff: %s" .title)
      ""
      "## Operating Frame"
      ""
      "You are receiving a Vibemacs handoff bundle. Use it as session evidence, not as a substitute for reading the code."
      ""
      "## Project"
      ""
      (format "- Root: `%s`" .root)
      (format "- Branch: `%s`" .branch)
      (format "- Session evidence: `%s`" .session-file)
      ""
      "## Diagnostics"
      ""
      (vibemacs--markdown-list .diagnostics "No project diagnostics available.")
      ""
      "## Git Changes"
      ""
      (vibemacs--markdown-list .changed-files "No Git changes detected.")
      ""
      "## Open Project Buffers"
      ""
      (vibemacs--markdown-list .open-files "No project files are open.")
      ""
      "## Recent Task Files"
      ""
      (vibemacs--markdown-list .task-files "No persisted task files found.")
      ""
      "## Recent Task Status"
      ""
      (vibemacs--markdown-list .task-summaries "No task status available.")
      ""
      "## Verification Commands"
      ""
      (vibemacs--markdown-list .verification "No verification commands configured.")
      ""
      "## Recent Verification Evidence"
      ""
      (vibemacs-render-verification-history .verification-history)
      ""
      "## Standing Agent Instructions"
      ""
      (string-join (mapcar (lambda (item) (concat "- " item))
                           vibemacs-default-constraints)
                   "\n")
      ""
      "## Requested Outcome"
      ""
      "- Clarify the concrete task before editing."
      "- Make the smallest coherent change that moves the real goal forward."
      "- Report what changed and which checks prove it."
      "")
     "\n")))


(provide 'vibemacs-evidence)

;;; vibemacs-evidence.el ends here
