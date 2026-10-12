;;; gnopon-tasks.el --- GitHub Markdown task cockpit -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)
(require 'gnopon-markdown)
(require 'seq)
(require 'transient)

(defvar gnopon-task-search-globs
  '("*.md" "docs/**/*.md" ".github/**/*.md")
  "Ripgrep globs scanned by the Markdown task cockpit.")

(defun gnopon/task-rg-lines ()
  "Return raw ripgrep lines for project Markdown task items."
  (if (executable-find "rg")
      (with-temp-buffer
        (let ((args (append
                     '("-n" "^- \\[[ xX-]\\] ")
                     (apply #'append
                            (mapcar (lambda (glob) (list "--glob" glob))
                                    gnopon-task-search-globs))
                     (list (gnopon/project-root)))))
          (apply #'call-process "rg" nil t nil args)
          (split-string (buffer-string) "\n" t)))
    nil))

(defun gnopon/task-parse-rg-line (line)
  "Parse a ripgrep task LINE into an alist."
  (when (string-match "^\\([^:\n]+\\):\\([0-9]+\\):\\(.*\\)$" line)
    (let* ((file (match-string 1 line))
           (line-number (string-to-number (match-string 2 line)))
           (text (match-string 3 line))
           (state (gnopon/markdown-task-state text)))
      `((file . ,file)
        (line . ,line-number)
        (text . ,text)
        (state . ,state)))))

(defun gnopon/task-items ()
  "Return parsed project Markdown task items."
  (delq nil (mapcar #'gnopon/task-parse-rg-line (gnopon/task-rg-lines))))

(defun gnopon/task-counts (tasks)
  "Return task state counts for TASKS."
  (let ((counts (list (cons 'todo 0)
                      (cons 'done 0)
                      (cons 'canceled 0)
                      (cons 'unknown 0))))
    (dolist (task tasks)
      (let* ((state (or (alist-get 'state task) 'unknown))
             (cell (assoc state counts)))
        (when cell
          (setcdr cell (1+ (cdr cell))))))
    counts))

(defun gnopon/task-format-item (task)
  "Return a Markdown line for TASK."
  (format "- `%s:%s` %s"
          (alist-get 'file task)
          (alist-get 'line task)
          (alist-get 'text task)))

(defun gnopon/task-dashboard-text ()
  "Return a Markdown task dashboard for the current project."
  (let* ((tasks (gnopon/task-items))
         (counts (gnopon/task-counts tasks)))
    (concat
     "# Markdown Task Cockpit\n\n"
     "- project: `" (file-truename (gnopon/project-root)) "`\n"
     "- todo: `" (number-to-string (alist-get 'todo counts)) "`\n"
     "- done: `" (number-to-string (alist-get 'done counts)) "`\n"
     "- canceled: `" (number-to-string (alist-get 'canceled counts)) "`\n\n"
     "## Todo\n\n"
     (or (mapconcat #'gnopon/task-format-item
                    (seq-filter (lambda (task)
                                  (eq (alist-get 'state task) 'todo))
                                tasks)
                    "\n")
         "- none")
     "\n\n## Done\n\n"
     (or (mapconcat #'gnopon/task-format-item
                    (seq-filter (lambda (task)
                                  (eq (alist-get 'state task) 'done))
                                tasks)
                    "\n")
         "- none")
     "\n\n## Canceled\n\n"
     (or (mapconcat #'gnopon/task-format-item
                    (seq-filter (lambda (task)
                                  (eq (alist-get 'state task) 'canceled))
                                tasks)
                    "\n")
         "- none")
     "\n")))

(defun gnopon/task-dashboard ()
  "Open a read-only Markdown task dashboard."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-tasks*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/task-dashboard-text))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/open-todo-file ()
  "Open project TODO.md, creating it if needed."
  (interactive)
  (gnopon/open-context-file "TODO.md"))

(defun gnopon/capture-task (title)
  "Append a GitHub Markdown task TITLE to TODO.md."
  (interactive "sTask: ")
  (let ((path (gnopon/project-file "TODO.md")))
    (unless (file-exists-p path)
      (make-directory (file-name-directory path) t)
      (with-temp-file path
        (gnopon/insert-context-template "TODO.md")))
    (with-current-buffer (find-file-noselect path)
      (goto-char (point-max))
      (unless (bolp)
        (insert "\n"))
      (insert (format "- [ ] %s %s\n" (format-time-string "%Y-%m-%d") title))
      (save-buffer))
    (find-file path)))

(transient-define-prefix gnopon/task-cockpit ()
  "GitHub Markdown task cockpit."
  [["Tasks"
    ("d" "dashboard" gnopon/task-dashboard)
    ("c" "capture" gnopon/capture-task)
    ("o" "open TODO.md" gnopon/open-todo-file)
    ("s" "search tasks" gnopon/search-tasks)
    ("t" "insert task" gnopon/insert-task)
    ("T" "toggle at point" gnopon/toggle-task-at-point)]])

(define-key gnopon-map (kbd "m t") #'gnopon/task-cockpit)
(define-key gnopon-map (kbd "m T") #'gnopon/task-dashboard)

(provide 'gnopon-tasks)
;;; gnopon-tasks.el ends here
