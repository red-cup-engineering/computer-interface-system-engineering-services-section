;;; gnopon-markdown.el --- Markdown project memory -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)
(require 'button)
(require 'seq)

(defvar gnopon-context-files
  '("README.md" "GOALS.md" "SPEC.md" "PLAN.md" "TODO.md" "CHANGELOG.md"
    "AGENTS.md" "CLAUDE.md" "GEMINI.md" "docs/adr/README.md" "docs/rfc/README.md"
    "docs/notes/README.md" "docs/predications/README.md")
  "Project memory files GnoponEmacs treats as first-class.")

(defvar gnopon-evidence-regimes
  '("strict" "scott-continuous" "transfinite-bounded" "aperiodic")
  "Validation and closure regimes for project memory.")

(defvar gnopon-evidence-sides
  '("truth" "knowledge" "conflict" "gap")
  "Paraconsistent evidence sides.")

(defcustom gnopon-knowledge-note-directory "docs/notes/"
  "Project-relative directory for knowledge-vault notes."
  :type 'string
  :group 'gnopon)

(defvar-local gnopon-knowledge-vault-root nil
  "Project root represented by the current knowledge-vault buffer.")

(defvar gnopon-knowledge-vault-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'gnopon/knowledge-vault-refresh)
    (define-key map (kbd "G") #'gnopon/open-goals-file)
    (define-key map (kbd "p") (lambda () (interactive) (gnopon/open-context-file "PLAN.md")))
    (define-key map (kbd "t") #'gnopon/capture-task)
    (define-key map (kbd "T") #'gnopon/task-dashboard)
    (define-key map (kbd "n") #'gnopon/capture-knowledge-note)
    (define-key map (kbd "b") #'gnopon/bootstrap-project-memory)
    (define-key map (kbd "c") #'gnopon/open-context-bundle)
    (define-key map (kbd "C") #'gnopon/copy-context-bundle)
    (define-key map (kbd "a") #'gnopon/codex-dashboard)
    (define-key map (kbd "A") #'gnopon/codex-workspace)
    (define-key map (kbd "s") #'gnopon/start-codex-session)
    (define-key map (kbd "m") #'gnopon/mcp-cockpit)
    (define-key map (kbd "l") #'gnopon/markdown-link-graph-report)
    (define-key map (kbd "v") #'gnopon/validate-project-memory)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `gnopon-knowledge-vault-mode'.")

(define-minor-mode gnopon-knowledge-vault-mode
  "Minor mode for the Gnoponics knowledge-vault buffer."
  :lighter " Gnoponics"
  :keymap gnopon-knowledge-vault-mode-map)

(gnopon/use-optional-package markdown-mode
  :mode (("\\.md\\'" . gfm-mode)
         ("README\\.md\\'" . gfm-mode))
  :custom
  (markdown-command "pandoc")
  (markdown-fontify-code-blocks-natively t)
  (markdown-enable-wiki-links t))

(gnopon/use-optional-package markdown-toc
  :after markdown-mode)

(gnopon/use-optional-package yaml-mode
  :mode ("\\.ya?ml\\'" . yaml-mode))

(defun gnopon/open-context-file (file)
  "Open project context FILE, creating parent directories if needed."
  (interactive
   (list (completing-read "Context file: " gnopon-context-files nil nil nil nil "PLAN.md")))
  (let ((path (gnopon/project-file file)))
    (make-directory (file-name-directory path) t)
    (find-file path)
    (when (= (point-min) (point-max))
      (gnopon/insert-context-template file))))

(defun gnopon/bootstrap-project-memory ()
  "Create missing standard Markdown project-memory files."
  (interactive)
  (dolist (file gnopon-context-files)
    (let ((path (gnopon/project-file file)))
      (unless (file-exists-p path)
        (make-directory (file-name-directory path) t)
        (with-temp-file path
          (gnopon/insert-context-template file)))))
  (message "Bootstrapped project memory in %s" (gnopon/project-root)))

(defun gnopon/sync-agent-context-files ()
  "Create CLAUDE.md and GEMINI.md from AGENTS.md with tool-specific headers."
  (interactive)
  (let* ((root (gnopon/project-root))
         (agents (expand-file-name "AGENTS.md" root)))
    (unless (file-readable-p agents)
      (user-error "AGENTS.md does not exist"))
    (dolist (file '("CLAUDE.md" "GEMINI.md"))
      (with-temp-file (expand-file-name file root)
        (insert "# " file "\n\n")
        (insert "This file is generated from `AGENTS.md` for tool-specific agent context. Edit `AGENTS.md` first, then resync.\n\n")
        (insert-file-contents agents))))
  (message "Synced CLAUDE.md and GEMINI.md from AGENTS.md"))

(defun gnopon/markdown-title-for-file (file)
  "Return a human title for context FILE."
  (file-name-base (directory-file-name file)))

(defun gnopon/insert-context-template (file)
  "Insert a project-memory template for FILE."
  (let ((title (gnopon/markdown-title-for-file file)))
    (cond
     ((string= file "AGENTS.md")
      (insert "# AGENTS.md\n\n## Project Contract\n\n## Build And Test\n\n## Review Rules\n\n## Agent Safety\n\n- Do not commit without human review.\n- Do not send secrets to external services.\n- Leave command logs and diffs as evidence.\n"))
     ((string= file "GOALS.md")
      (insert "# GOALS\n\n## North Star\n\n## Active Goals\n\n- [ ] \n\n## Deferred Goals\n\n- [ ] \n\n## Accepted Outcomes\n\n- [ ] \n"))
     ((member file '("CLAUDE.md" "GEMINI.md"))
      (insert "# " file "\n\nThis file mirrors durable project context from `AGENTS.md` for tool-specific agents.\n\n## Project Context\n\n## Commands\n\n## Safety\n\n"))
     ((string= file "SPEC.md")
      (insert "# SPEC\n\n## Problem\n\n## Goals\n\n## Non-Goals\n\n## Interfaces\n\n## Acceptance Criteria\n\n"))
     ((string= file "PLAN.md")
      (insert "# PLAN\n\n## Current Objective\n\n## Milestones\n\n- [ ] \n\n## Risks\n\n## Evidence\n\n"))
     ((string= file "TODO.md")
      (insert "# TODO\n\n- [ ] \n"))
     ((string= file "CHANGELOG.md")
      (insert "# Changelog\n\n## Unreleased\n\n- \n"))
     ((string= file "docs/notes/README.md")
      (insert "# Notes\n\nKnowledge notes capture observations, decisions in progress, context, and durable agent/user discoveries. Prefer GitHub Markdown, links, tasks, and evidence blocks.\n"))
     ((string= file "docs/predications/README.md")
      (insert "# Predications\n\nEach file in this directory is a Markdown predication cell with YAML frontmatter, one cell per file.\n\n## Fields\n\n- `subject`\n- `predicate`\n- `object`\n- `value`\n- `evidence-regime`\n- `evidence-side`\n- `depends-on`\n"))
     (t
      (insert "# " title "\n\n")))))

(defun gnopon/insert-frontmatter (title)
  "Insert YAML frontmatter with TITLE."
  (interactive "sTitle: ")
  (insert (gnopon/markdown-frontmatter-string title)))

(defun gnopon/insert-task ()
  "Insert a GitHub-flavored Markdown task item."
  (interactive)
  (insert (format "- [ ] %s " (format-time-string "%Y-%m-%d"))))

(defun gnopon/toggle-task-at-point ()
  "Toggle the Markdown task state on the current line."
  (interactive)
  (let* ((bounds (bounds-of-thing-at-point 'line))
         (start (car bounds))
         (end (cdr bounds))
         (line (buffer-substring-no-properties start end)))
    (delete-region start end)
    (insert (gnopon/markdown-toggle-task-line line))))

(defun gnopon/insert-evidence-block (regime side)
  "Insert a Markdown evidence block labeled by REGIME and SIDE."
  (interactive
   (list (completing-read "Regime: " gnopon-evidence-regimes nil t)
         (completing-read "Side: " gnopon-evidence-sides nil t)))
  (insert (format "> [!NOTE]\n> evidence-regime: `%s`\n> evidence-side: `%s`\n> source: `%s`\n>\n> "
                  regime side (or (buffer-file-name) (buffer-name)))))

(defun gnopon/search-tasks ()
  "Search project Markdown task lists."
  (interactive)
  (gnopon/search-project "^- \\[[ xX-]\\] "))

(defun gnopon/search-backlinks ()
  "Search for Markdown links or wiki-style references to the current stem."
  (interactive)
  (let* ((stem (file-name-base (or (buffer-file-name) (read-string "Reference: "))))
         (pattern (format "\\[%s\\]|\\[\\[%s\\]\\]" (regexp-quote stem) (regexp-quote stem))))
    (gnopon/search-project pattern)))

(defun gnopon/search-project-memory ()
  "Search known Markdown project-memory files."
  (interactive)
  (gnopon/search-project
   "README|SPEC|PLAN|TODO|CHANGELOG|AGENTS|CLAUDE|GEMINI|ADR|RFC"))

(defun gnopon/markdown-file-text (file)
  "Return the contents of Markdown FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(defun gnopon/markdown-project-files ()
  "Return project Markdown files that represent durable memory."
  (let* ((root (file-truename (gnopon/project-root)))
         (root-files (directory-files root t "\\.md\\'"))
         (docs-dir (expand-file-name "docs/" root))
         (docs-files (when (file-directory-p docs-dir)
                       (directory-files-recursively docs-dir "\\.md\\'")))
         (context-files (mapcar (lambda (file) (expand-file-name file root))
                                gnopon-context-files))
         (files (append root-files docs-files context-files)))
    (sort
     (seq-uniq
      (seq-filter (lambda (file)
                    (and (file-readable-p file)
                         (string-prefix-p root (file-truename file))
                         (not (string-match-p "/\\(\\.git\\|node_modules\\|logs\\|var\\)/"
                                              (file-truename file)))))
                  files)
      #'string=)
     #'string<)))

(defun gnopon/markdown-structure-issue (summary)
  "Return a structural issue label for Markdown SUMMARY, or nil."
  (let ((h1-count (alist-get 'h1 summary)))
    (cond
     ((zerop h1-count) "missing H1")
     ((> h1-count 1) "multiple H1")
     (t nil))))

(defun gnopon/markdown-structure-file-section (root file)
  "Return a Markdown structure section for FILE under ROOT."
  (let* ((relative (file-relative-name file root))
         (text (gnopon/markdown-file-text file))
         (summary (gnopon/markdown-structure-summary text))
         (headings (gnopon/markdown-heading-entries text))
         (links (gnopon/markdown-link-entries text))
         (tasks (gnopon/markdown-task-entries text))
         (issue (gnopon/markdown-structure-issue summary)))
    (concat "## `" relative "`\n\n"
            "- headings: `" (number-to-string (alist-get 'headings summary)) "`\n"
            "- h1: `" (number-to-string (alist-get 'h1 summary)) "`"
            (if issue (concat " - " issue) "")
            "\n"
            "- links: `" (number-to-string (alist-get 'links summary)) "`\n"
            "- tasks: `" (number-to-string (alist-get 'tasks summary)) "`\n\n"
            "### Headings\n\n"
            (if headings
                (mapconcat (lambda (entry)
                             (format "- `%s` %s %s\n"
                                     (number-to-string (alist-get 'line entry))
                                     (make-string (alist-get 'level entry) ?#)
                                     (alist-get 'title entry)))
                           headings
                           "")
              "- none\n")
            "\n### Links\n\n"
            (if links
                (mapconcat (lambda (entry)
                             (format "- `%s` %s -> `%s`\n"
                                     (number-to-string (alist-get 'line entry))
                                     (alist-get 'label entry)
                                     (alist-get 'target entry)))
                           links
                           "")
              "- none\n")
            "\n### Task States\n\n"
            (if tasks
                (let ((todo 0)
                      (done 0)
                      (canceled 0))
                  (dolist (task tasks)
                    (pcase (alist-get 'state task)
                      ('todo (setq todo (1+ todo)))
                      ('done (setq done (1+ done)))
                      ('canceled (setq canceled (1+ canceled)))))
                  (format "- todo: `%s`\n- done: `%s`\n- canceled: `%s`\n"
                          todo done canceled))
              "- none\n")
            "\n### Tasks\n\n"
            (if tasks
                (mapconcat (lambda (entry)
                             (format "- `%s` %s\n"
                                     (number-to-string (alist-get 'line entry))
                                     (alist-get 'text entry)))
                           tasks
                           "")
              "- none\n")
            "\n")))

(defun gnopon/markdown-structure-report-text ()
  "Return a Markdown structure report for project memory files."
  (let* ((root (file-truename (gnopon/project-root)))
         (files (gnopon/markdown-project-files)))
    (concat "# Markdown Structure Report\n\n"
            "- project: `" root "`\n"
            "- files: `" (number-to-string (length files)) "`\n\n"
            "## File Summary\n\n"
            (if files
                (mapconcat
                 (lambda (file)
                   (let* ((relative (file-relative-name file root))
                          (summary (gnopon/markdown-structure-summary
                                    (gnopon/markdown-file-text file)))
                          (issue (gnopon/markdown-structure-issue summary)))
                     (format "- %s `%s` - headings `%s`, links `%s`, tasks `%s`%s\n"
                             (if issue "[ ]" "[x]")
                             relative
                             (alist-get 'headings summary)
                             (alist-get 'links summary)
                             (alist-get 'tasks summary)
                             (if issue (concat ", " issue) ""))))
                 files
                 "")
              "- none\n")
            "\n# Files\n\n"
            (mapconcat (lambda (file)
                         (gnopon/markdown-structure-file-section root file))
                       files
                       "\n"))))

(defun gnopon/markdown-structure-report ()
  "Open a generated structure report for project Markdown memory."
  (interactive)
  (let ((buffer (get-buffer-create "*markdown-structure*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/markdown-structure-report-text))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/markdown-link-external-p (target)
  "Return non-nil when TARGET is not a project-local Markdown link."
  (or (string-match-p "\\`[a-zA-Z][a-zA-Z0-9+.-]*:" target)
      (string-prefix-p "//" target)))

(defun gnopon/markdown-strip-link-fragment (target)
  "Return TARGET without URL query or fragment suffix."
  (car (split-string target "[#?]" t)))

(defun gnopon/markdown-normalize-link-target (root source-relative entry known-files)
  "Return a normalized link edge target for ENTRY.
ROOT is the project root, SOURCE-RELATIVE is the source Markdown file, and
KNOWN-FILES is the list of project Markdown files relative to ROOT."
  (let* ((raw-target (string-trim (alist-get 'target entry)))
         (type (alist-get 'type entry))
         (source-dir (file-name-directory source-relative))
         (target (gnopon/markdown-strip-link-fragment raw-target)))
    (cond
     ((string-empty-p raw-target)
      `((status . missing) (target . "") (raw . ,raw-target)))
     ((string-prefix-p "#" raw-target)
      `((status . anchor) (target . ,source-relative) (raw . ,raw-target)))
     ((gnopon/markdown-link-external-p raw-target)
      `((status . external) (target . ,raw-target) (raw . ,raw-target)))
     ((string-empty-p target)
      `((status . anchor) (target . ,source-relative) (raw . ,raw-target)))
     (t
      (let* ((base (cond
                    ((eq type 'wiki) target)
                    ((file-name-absolute-p target)
                     (string-remove-prefix "/" target))
                    (t (concat (or source-dir "") target))))
             (base-relative (file-relative-name (expand-file-name base root) root))
             (candidates (seq-uniq
                          (delq nil
                                (list base-relative
                                      (unless (string-match-p "\\.md\\'" base-relative)
                                        (concat base-relative ".md"))
                                      (concat (file-name-as-directory base-relative) "README.md")
                                      (when (eq type 'wiki)
                                        (concat target ".md"))
                                      (when (eq type 'wiki)
                                        (concat (file-name-as-directory target) "README.md"))))
                          #'string=))
             (match (seq-find (lambda (candidate)
                                (member candidate known-files))
                              candidates)))
        `((status . ,(if match 'present 'missing))
          (target . ,(or match (car candidates)))
          (raw . ,raw-target)))))))

(defun gnopon/markdown-link-graph-edges ()
  "Return normalized Markdown link graph edges for project memory."
  (let* ((root (file-truename (gnopon/project-root)))
         (files (gnopon/markdown-project-files))
         (known (mapcar (lambda (file) (file-relative-name file root)) files))
         edges)
    (dolist (file files)
      (let* ((relative (file-relative-name file root))
             (text (gnopon/markdown-file-text file)))
        (dolist (entry (gnopon/markdown-link-entries text))
          (let ((target (gnopon/markdown-normalize-link-target
                         root relative entry known)))
            (push `((from . ,relative)
                    (line . ,(alist-get 'line entry))
                    (label . ,(alist-get 'label entry))
                    (type . ,(alist-get 'type entry))
                    (to . ,(alist-get 'target target))
                    (raw . ,(alist-get 'raw target))
                    (status . ,(alist-get 'status target)))
                  edges)))))
    (nreverse edges)))

(defun gnopon/markdown-link-graph-counts (files edges)
  "Return incoming/outgoing counts for FILES from graph EDGES."
  (let ((counts (mapcar (lambda (file)
                          `(,file . ((incoming . 0) (outgoing . 0))))
                        files)))
    (dolist (edge edges)
      (when (eq (alist-get 'status edge) 'present)
        (when-let ((from (assoc (alist-get 'from edge) counts)))
          (let ((cell (assoc 'outgoing (cdr from))))
            (setcdr cell (1+ (cdr cell)))))
        (when-let ((to (assoc (alist-get 'to edge) counts)))
          (let ((cell (assoc 'incoming (cdr to))))
            (setcdr cell (1+ (cdr cell)))))))
    counts))

(defun gnopon/markdown-link-graph-report-text ()
  "Return a Markdown report of project-memory Markdown links."
  (let* ((root (file-truename (gnopon/project-root)))
         (files (mapcar (lambda (file)
                          (file-relative-name file root))
                        (gnopon/markdown-project-files)))
         (edges (gnopon/markdown-link-graph-edges))
         (counts (gnopon/markdown-link-graph-counts files edges))
         (present (seq-filter (lambda (edge) (eq (alist-get 'status edge) 'present)) edges))
         (missing (seq-filter (lambda (edge) (eq (alist-get 'status edge) 'missing)) edges))
         (external (seq-filter (lambda (edge) (eq (alist-get 'status edge) 'external)) edges))
         (orphans (seq-filter (lambda (row)
                                (let ((data (cdr row)))
                                  (and (zerop (alist-get 'incoming data))
                                       (not (string= (car row) "README.md")))))
                              counts)))
    (concat "# Markdown Link Graph\n\n"
            "- project: `" root "`\n"
            "- files: `" (number-to-string (length files)) "`\n"
            "- links: `" (number-to-string (length edges)) "`\n"
            "- present: `" (number-to-string (length present)) "`\n"
            "- missing: `" (number-to-string (length missing)) "`\n"
            "- external: `" (number-to-string (length external)) "`\n"
            "- orphans: `" (number-to-string (length orphans)) "`\n\n"
            "## Files\n\n"
            (if counts
                (mapconcat
                 (lambda (row)
                   (let ((data (cdr row)))
                     (format "- `%s` - incoming `%s`, outgoing `%s`\n"
                             (car row)
                             (alist-get 'incoming data)
                             (alist-get 'outgoing data))))
                 counts
                 "")
              "- none\n")
            "\n## Present Links\n\n"
            (if present
                (mapconcat
                 (lambda (edge)
                   (format "- `%s:%s` -> `%s` (%s)\n"
                           (alist-get 'from edge)
                           (alist-get 'line edge)
                           (alist-get 'to edge)
                           (alist-get 'label edge)))
                 present
                 "")
              "- none\n")
            "\n## Missing Links\n\n"
            (if missing
                (mapconcat
                 (lambda (edge)
                   (format "- `%s:%s` -> `%s` from `%s`\n"
                           (alist-get 'from edge)
                           (alist-get 'line edge)
                           (alist-get 'to edge)
                           (alist-get 'raw edge)))
                 missing
                 "")
              "- none\n")
            "\n## External Links\n\n"
            (if external
                (mapconcat
                 (lambda (edge)
                   (format "- `%s:%s` -> `%s`\n"
                           (alist-get 'from edge)
                           (alist-get 'line edge)
                           (alist-get 'raw edge)))
                 external
                 "")
              "- none\n")
            "\n## Orphans\n\n"
            (if orphans
                (mapconcat (lambda (row)
                             (format "- `%s`\n" (car row)))
                           orphans
                           "")
              "- none\n"))))

(defun gnopon/markdown-link-graph-report ()
  "Open a generated link graph report for project Markdown memory."
  (interactive)
  (let ((buffer (get-buffer-create "*markdown-link-graph*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/markdown-link-graph-report-text))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/project-memory-index ()
  "Open a generated index of project memory files."
  (interactive)
  (let* ((root (file-truename (gnopon/project-root)))
         (buffer (get-buffer-create (format "*memory:%s*" (file-name-nondirectory (directory-file-name root))))))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# Project Memory\n\n")
      (dolist (file gnopon-context-files)
        (let ((path (expand-file-name file root)))
          (insert (if (file-exists-p path) "- [x] " "- [ ] ")
                  "`" file "`\n")))
      (insert "\n## Open Tasks\n\n```text\n")
      (insert (condition-case err
                  (string-join (process-lines "rg" "-n" "^- \\[[ xX-]\\]" root) "\n")
                (error (format "task scan unavailable: %s" (error-message-string err)))))
      (insert "\n```\n")
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/validate-project-memory ()
  "Check project memory for known evidence labels and task markers."
  (interactive)
  (let ((buffer (get-buffer-create "*memory-validation*"))
        (root (gnopon/project-root)))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# Project Memory Validation\n\n")
      (insert "## Evidence Labels\n\n")
      (insert "- regimes: `" (string-join gnopon-evidence-regimes "`, `") "`\n")
      (insert "- sides: `" (string-join gnopon-evidence-sides "`, `") "`\n\n")
      (insert "## Evidence Blocks\n\n```text\n")
      (insert (condition-case err
                  (string-join (process-lines "rg" "-n" "evidence-(regime|side):" root) "\n")
                (error (format "evidence scan unavailable: %s" (error-message-string err)))))
      (insert "\n```\n\n## Tasks\n\n```text\n")
      (insert (condition-case err
                  (string-join (process-lines "rg" "-n" "^- \\[[ xX-]\\]" root) "\n")
                (error (format "task scan unavailable: %s" (error-message-string err)))))
      (insert "\n```\n")
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/open-goals-file ()
  "Open the project GOALS.md file, creating it when missing."
  (interactive)
  (gnopon/open-context-file "GOALS.md"))

(defun gnopon/capture-goal (title)
  "Append a GitHub Markdown goal task TITLE to GOALS.md."
  (interactive "sGoal: ")
  (let ((path (gnopon/project-file "GOALS.md")))
    (unless (file-exists-p path)
      (make-directory (file-name-directory path) t)
      (with-temp-file path
        (gnopon/insert-context-template "GOALS.md")))
    (with-current-buffer (find-file-noselect path)
      (goto-char (point-max))
      (unless (bolp)
        (insert "\n"))
      (insert (format "- [ ] %s %s\n" (format-time-string "%Y-%m-%d") title))
      (save-buffer))
    (find-file path)))

(defun gnopon/knowledge-note-path (title)
  "Return a project-local knowledge note path for TITLE."
  (let ((dir (gnopon/project-file gnopon-knowledge-note-directory)))
    (make-directory dir t)
    (expand-file-name
     (format "%s-%s.md"
             (format-time-string "%Y%m%d-%H%M%S")
             (gnopon/markdown-slugify title))
     dir)))

(defun gnopon/knowledge-note-focus-section ()
  "Return a redacted source section for a captured knowledge note."
  (let* ((root (file-truename (gnopon/project-root)))
         (source (cond
                  (buffer-file-name
                   (file-relative-name (file-truename buffer-file-name) root))
                  (t (buffer-name)))))
    (if (use-region-p)
        (format "## Captured Context\n\n- source: `%s`\n- lines: `%s-%s`\n\n```text\n%s\n```\n\n"
                source
                (line-number-at-pos (region-beginning))
                (line-number-at-pos (region-end))
                (gnopon/redact-secrets
                 (buffer-substring-no-properties (region-beginning) (region-end))))
      (format "## Captured Context\n\n- source: `%s`\n- selection: `none`\n\n"
              source))))

(defun gnopon/knowledge-note-template (title focus-section)
  "Return a GitHub Markdown knowledge note for TITLE and FOCUS-SECTION."
  (concat (gnopon/markdown-frontmatter-string
           title "active" nil '("knowledge" "note" "gnoponics"))
          "# " title "\n\n"
          "## Observation\n\n\n"
          focus-section
          "## Links\n\n- \n\n"
          "## Tasks\n\n- [ ] \n\n"
          "## Predications\n\n- [ ] claim: \n\n"
          "## Agent Notes\n\n- \n"))

(defun gnopon/capture-knowledge-note (title)
  "Create a Markdown knowledge note for TITLE."
  (interactive "sKnowledge note: ")
  (let ((path (gnopon/knowledge-note-path title))
        (focus (gnopon/knowledge-note-focus-section)))
    (find-file path)
    (when (= (point-min) (point-max))
      (insert (gnopon/knowledge-note-template title focus))
      (save-buffer))
    path))

(defun gnopon/knowledge-vault-files (directory)
  "Return project Markdown files under DIRECTORY, newest first."
  (let ((absolute (gnopon/project-file directory)))
    (if (file-directory-p absolute)
        (sort (directory-files-recursively absolute "\\.md\\'") #'string>)
      nil)))

(defun gnopon/knowledge-vault-counts ()
  "Return knowledge-vault counts for the active project."
  (let* ((root (file-truename (gnopon/project-root)))
         (context-ready (length
                         (seq-filter (lambda (file)
                                       (file-readable-p (expand-file-name file root)))
                                     gnopon-context-files)))
         (markdown-files (gnopon/markdown-project-files))
         (tasks (if (fboundp 'gnopon/task-items) (gnopon/task-items) nil))
         (task-counts (if (fboundp 'gnopon/task-counts)
                          (gnopon/task-counts tasks)
                        '((todo . 0) (done . 0) (canceled . 0))))
         (predications (if (fboundp 'gnopon/predication-files)
                           (gnopon/predication-files)
                         (gnopon/knowledge-vault-files "docs/predications/")))
         (notes (gnopon/knowledge-vault-files gnopon-knowledge-note-directory))
         (agent-sessions (gnopon/knowledge-vault-files "logs/agent/"))
         (codex-prompts (seq-filter (lambda (file)
                                      (string-match-p "-codex-prompt\\.md\\'" file))
                                    agent-sessions))
         (codex-transcripts (seq-filter (lambda (file)
                                          (string-match-p "-codex-transcript\\.md\\'" file))
                                        agent-sessions)))
    `((context-ready . ,context-ready)
      (context-total . ,(length gnopon-context-files))
      (markdown-files . ,(length markdown-files))
      (todo . ,(alist-get 'todo task-counts))
      (done . ,(alist-get 'done task-counts))
      (canceled . ,(alist-get 'canceled task-counts))
      (notes . ,(length notes))
      (predications . ,(length predications))
      (agent-sessions . ,(length agent-sessions))
      (codex-prompts . ,(length codex-prompts))
      (codex-transcripts . ,(length codex-transcripts)))))

(defun gnopon/knowledge-vault-file-section (root)
  "Return a Markdown status section for shared memory files under ROOT."
  (concat "## Shared Context Files\n\n"
          (mapconcat
           (lambda (file)
             (let ((path (expand-file-name file root)))
               (format "- %s `%s`\n"
                       (if (file-readable-p path) "[x]" "[ ]")
                       file)))
           gnopon-context-files
           "")
          "\n"))

(defun gnopon/knowledge-vault-loop-section ()
  "Return the Gnoponics operating loop as Markdown."
  (concat "## Cultivation Loop\n\n"
          "1. Seed goals in `GOALS.md`, shape scope in `SPEC.md`, and keep the current path in `PLAN.md`.\n"
          "2. Tend work through GitHub Markdown tasks in `TODO.md` and daily notes in `docs/notes/`.\n"
          "3. Converse with Codex through redacted context bundles, prompt records, transcripts, and session notes.\n"
          "4. Validate memory with link graphs, structure reports, predication checks, project checks, and tests.\n"
          "5. Harvest decisions into ADRs, RFCs, `CHANGELOG.md`, review packets, and durable predication cells.\n\n"))

(defun gnopon/knowledge-vault-text ()
  "Return a Markdown dashboard for shared agentic knowledge management."
  (let* ((root (file-truename (gnopon/project-root)))
         (counts (gnopon/knowledge-vault-counts)))
    (concat "# Gnoponics Knowledge Vault\n\n"
            "- project: `" root "`\n"
            "- generated: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
            "- substrate: `GitHub Markdown + YAML frontmatter + Git history`\n"
            "- shared-context: `human operators and agents read/write the same inspectable files`\n\n"
            "## Vault Health\n\n"
            "- context-files: `" (number-to-string (alist-get 'context-ready counts)) "/"
            (number-to-string (alist-get 'context-total counts)) "`\n"
            "- markdown-files: `" (number-to-string (alist-get 'markdown-files counts)) "`\n"
            "- open-tasks: `" (number-to-string (alist-get 'todo counts)) "`\n"
            "- completed-tasks: `" (number-to-string (alist-get 'done counts)) "`\n"
            "- knowledge-notes: `" (number-to-string (alist-get 'notes counts)) "`\n"
            "- predication-cells: `" (number-to-string (alist-get 'predications counts)) "`\n"
            "- agent-evidence: `" (number-to-string (alist-get 'agent-sessions counts)) "`\n"
            "- codex-prompts: `" (number-to-string (alist-get 'codex-prompts counts)) "`\n"
            "- codex-transcripts: `" (number-to-string (alist-get 'codex-transcripts counts)) "`\n\n"
            (gnopon/knowledge-vault-loop-section)
            (gnopon/knowledge-vault-file-section root)
            "## Next Moves\n\n"
            "- `G`: open goals\n"
            "- `p`: open plan\n"
            "- `t`: capture task\n"
            "- `n`: capture knowledge note\n"
            "- `c`: preview shared context bundle\n"
            "- `a`: open Codex dashboard\n"
            "- `A`: open Codex workspace\n"
            "- `m`: export local MCP indexes\n"
            "- `l`: inspect Markdown link graph\n"
            "- `v`: validate project memory\n\n"
            "## Agent Contract\n\n"
            "- Plans, goals, tasks, sessions, and evidence stay in GitHub Markdown.\n"
            "- Agents receive redacted context bundles and return durable changes as Markdown, Git diffs, tests, and logs.\n"
            "- Contradictions are preserved as evidence or predication cells; they are not erased to make the vault look clean.\n")))

(defun gnopon/knowledge-vault-button (label command)
  "Insert a knowledge-vault button with LABEL calling COMMAND."
  (insert-text-button label
                      'follow-link t
                      'action (lambda (_button)
                                (let ((default-directory
                                       (or gnopon-knowledge-vault-root default-directory)))
                                  (call-interactively command))))
  (insert "\n"))

(defun gnopon/knowledge-vault-insert-actions ()
  "Insert live action buttons for the knowledge-vault buffer."
  (insert "\n## Live Actions\n\n")
  (dolist (action '(("Open goals" . gnopon/open-goals-file)
                    ("Capture goal" . gnopon/capture-goal)
                    ("Capture knowledge note" . gnopon/capture-knowledge-note)
                    ("Capture task" . gnopon/capture-task)
                    ("Open Codex dashboard" . gnopon/codex-dashboard)
                    ("Open Codex workspace" . gnopon/codex-workspace)
                    ("Open context bundle" . gnopon/open-context-bundle)
                    ("Write MCP indexes" . gnopon/mcp-write-indexes)
                    ("Link graph" . gnopon/markdown-link-graph-report)
                    ("Validate project memory" . gnopon/validate-project-memory)))
    (gnopon/knowledge-vault-button (car action) (cdr action)))
  (insert "\n"))

(defun gnopon/knowledge-vault-render (&optional root)
  "Render the knowledge vault for ROOT into the current buffer."
  (let ((vault-root (file-name-as-directory (or root (gnopon/project-root)))))
    (read-only-mode -1)
    (erase-buffer)
    (setq-local default-directory vault-root)
    (setq-local gnopon-knowledge-vault-root vault-root)
    (insert (gnopon/knowledge-vault-text))
    (gnopon/markdown-buffer-mode)
    (goto-char (point-max))
    (gnopon/knowledge-vault-insert-actions)
    (gnopon-knowledge-vault-mode 1)
    (setq-local default-directory vault-root)
    (setq-local gnopon-knowledge-vault-root vault-root)
    (goto-char (point-min))
    (read-only-mode 1)))

(defun gnopon/knowledge-vault-refresh ()
  "Refresh the current knowledge-vault buffer."
  (interactive)
  (unless gnopon-knowledge-vault-root
    (user-error "Current buffer is not a knowledge vault"))
  (gnopon/knowledge-vault-render gnopon-knowledge-vault-root))

(defun gnopon/knowledge-vault ()
  "Open the Gnoponics knowledge-vault dashboard."
  (interactive)
  (let* ((root (file-name-as-directory (file-truename (gnopon/project-root))))
         (buffer (get-buffer-create
                  (format "*knowledge-vault:%s*"
                          (file-name-nondirectory
                           (directory-file-name root))))))
    (with-current-buffer buffer
      (gnopon/knowledge-vault-render root))
    (pop-to-buffer buffer)))

(defun gnopon/create-adr (title)
  "Create an ADR Markdown file for TITLE."
  (interactive "sADR title: ")
  (let* ((slug (gnopon/markdown-slugify title))
         (dir (gnopon/project-file "docs/adr/"))
         (path (expand-file-name (format "%s-%s.md" (format-time-string "%Y%m%d") slug) dir)))
    (make-directory dir t)
    (find-file path)
    (when (= (point-min) (point-max))
      (gnopon/insert-frontmatter title)
      (insert "# " title "\n\n## Status\n\nProposed\n\n## Context\n\n## Decision\n\n## Consequences\n"))))

(defun gnopon/create-rfc (title)
  "Create an RFC Markdown file for TITLE."
  (interactive "sRFC title: ")
  (let* ((slug (gnopon/markdown-slugify title))
         (dir (gnopon/project-file "docs/rfc/"))
         (path (expand-file-name (format "%s.md" slug) dir)))
    (make-directory dir t)
    (find-file path)
    (when (= (point-min) (point-max))
      (gnopon/insert-frontmatter title)
      (insert "# " title "\n\n## Summary\n\n## Goals\n\n## Non-Goals\n\n## Design\n\n## Rollout\n"))))

(define-key gnopon-map (kbd "m o") #'gnopon/open-context-file)
(define-key gnopon-map (kbd "m f") #'gnopon/insert-frontmatter)
(define-key gnopon-map (kbd "m n") #'gnopon/insert-task)
(define-key gnopon-map (kbd "m N") #'gnopon/toggle-task-at-point)
(define-key gnopon-map (kbd "m e") #'gnopon/insert-evidence-block)
(define-key gnopon-map (kbd "m s") #'gnopon/search-tasks)
(define-key gnopon-map (kbd "m b") #'gnopon/search-backlinks)
(define-key gnopon-map (kbd "m k") #'gnopon/knowledge-vault)
(define-key gnopon-map (kbd "m i") #'gnopon/project-memory-index)
(define-key gnopon-map (kbd "m g") #'gnopon/markdown-link-graph-report)
(define-key gnopon-map (kbd "m u") #'gnopon/markdown-structure-report)
(define-key gnopon-map (kbd "m M") #'gnopon/search-project-memory)
(define-key gnopon-map (kbd "m B") #'gnopon/bootstrap-project-memory)
(define-key gnopon-map (kbd "m G") #'gnopon/open-goals-file)
(define-key gnopon-map (kbd "m K") #'gnopon/capture-knowledge-note)
(define-key gnopon-map (kbd "m S") #'gnopon/sync-agent-context-files)
(define-key gnopon-map (kbd "m v") #'gnopon/validate-project-memory)
(define-key gnopon-map (kbd "m a") #'gnopon/create-adr)
(define-key gnopon-map (kbd "m r") #'gnopon/create-rfc)

(provide 'gnopon-markdown)
;;; gnopon-markdown.el ends here
