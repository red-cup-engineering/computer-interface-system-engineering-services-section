;;; gnopon-workspace.el --- Workspace and window cockpit -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'seq)
(require 'subr-x)

(use-package tab-bar
  :ensure nil
  :demand t
  :custom
  (tab-bar-show 1)
  (tab-bar-new-tab-choice "*scratch*")
  (tab-bar-close-button-show nil)
  (tab-bar-new-button-show nil)
  :config
  (tab-bar-mode 1))

(use-package winner
  :ensure nil
  :demand t
  :config
  (winner-mode 1))

(gnopon/use-optional-package ace-window
  :bind
  (("M-o" . ace-window)))

(use-package popper
  :if (gnopon/optional-package-available-p 'popper)
  :demand t
  :custom
  (popper-reference-buffers
   '("\\*Messages\\*"
     "\\*Warnings\\*"
     "\\*Compile-Log\\*"
     "\\*compilation\\*"
     "\\*Async Shell Command\\*"
     "\\*eat\\*"
     "\\*agent:"
     help-mode
     compilation-mode))
  :bind
  (("C-`" . popper-toggle)
   ("M-`" . popper-cycle))
  :config
  (popper-mode 1)
  (popper-echo-mode 1))

(defun gnopon/workspace-name ()
  "Return a concise name for the current project workspace."
  (file-name-nondirectory
   (directory-file-name (file-truename (gnopon/project-root)))))

(defun gnopon/project-tab ()
  "Create or switch to a tab named after the current project."
  (interactive)
  (let ((name (gnopon/workspace-name)))
    (tab-bar-new-tab)
    (tab-bar-rename-tab name)
    (project-find-file)))

(defun gnopon/dashboard-memory-section (root)
  "Return Markdown dashboard memory section for ROOT."
  (concat
   "## Project Memory\n\n"
   (mapconcat (lambda (file)
                (let ((path (expand-file-name file root)))
                  (format "- %s `%s`\n"
                          (if (file-readable-p path) "[x]" "[ ]")
                          file)))
              gnopon-context-files
              "")
   "\n"))

(defun gnopon/dashboard-task-section ()
  "Return Markdown dashboard task section."
  (if (and (fboundp 'gnopon/task-items)
           (fboundp 'gnopon/task-counts))
      (let* ((tasks (gnopon/task-items))
             (counts (gnopon/task-counts tasks)))
        (format (concat "## Tasks\n\n"
                        "- todo: `%s`\n"
                        "- done: `%s`\n"
                        "- canceled: `%s`\n"
                        "- dashboard: `C-c g m T`\n\n")
                (alist-get 'todo counts)
                (alist-get 'done counts)
                (alist-get 'canceled counts)))
    "## Tasks\n\n- task cockpit unavailable until task module loads\n\n"))

(defun gnopon/dashboard-tool-section ()
  "Return Markdown dashboard tool-readiness section."
  (let ((tools '(("rg" . "search")
                 ("git" . "version control")
                 ("gh" . "GitHub")
                 ("node" . "Node")
                 ("pnpm" . "package scripts")
                 ("cargo" . "Rust")
                 ("rust-analyzer" . "Rust LSP")
                 ("typescript-language-server" . "TypeScript LSP"))))
    (concat
     "## Tool Readiness\n\n"
     (mapconcat (lambda (tool)
                  (format "- %s `%s` - %s\n"
                          (if (executable-find (car tool)) "[x]" "[ ]")
                          (car tool)
                          (cdr tool)))
                tools
                "")
     "\n")))

(defun gnopon/dashboard-git-section ()
  "Return Markdown dashboard Git section."
  (concat
   "## Git\n\n```text\n"
   (if (fboundp 'gnopon/git-status-short)
       (gnopon/git-status-short)
     "git status unavailable")
   "\n```\n\n"))

(defun gnopon/dashboard-command-section ()
  "Return Markdown dashboard command section."
  (concat
   "## Command Paths\n\n"
   "- cockpit: `M-SPC`\n"
   "- knowledge vault: `C-c g m k`\n"
   "- goals: `C-c g m G`\n"
   "- knowledge note: `C-c g m K`\n"
   "- context actions: `C-c g .`\n"
   "- symbol actions: `C-c g i`\n"
   "- safe command runner: `C-c g s c`\n"
   "- API cockpit: `C-c g p a`\n"
   "- Codex cockpit: `C-c g a x`\n"
   "- agent session: `C-c g a n`\n"
   "- review cockpit: `C-c g r`\n"
   "- capability audit: `C-c g d c`\n\n"))

(defun gnopon/project-dashboard-text ()
  "Return the Markdown project cockpit dashboard."
  (let ((root (file-truename (gnopon/project-root))))
    (concat "# Project Cockpit\n\n"
            "- project: `" root "`\n"
            "- workspace: `" (gnopon/workspace-name) "`\n"
            "- generated: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n\n"
            (gnopon/dashboard-memory-section root)
            (gnopon/dashboard-task-section)
            (gnopon/dashboard-git-section)
            (gnopon/dashboard-tool-section)
            (gnopon/dashboard-command-section))))

(defun gnopon/project-dashboard ()
  "Open a compact project dashboard buffer."
  (interactive)
  (let ((buffer (get-buffer-create (format "*dashboard:%s*" (gnopon/workspace-name)))))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/project-dashboard-text))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/workspace-project-file-p (root file)
  "Return non-nil when FILE is under ROOT."
  (and file
       (string-prefix-p root (file-truename file))))

(defun gnopon/workspace-buffer-file-entry (root buffer)
  "Return a project-relative file entry for BUFFER under ROOT, or nil."
  (with-current-buffer buffer
    (when (gnopon/workspace-project-file-p root buffer-file-name)
      (let ((relative (file-relative-name (file-truename buffer-file-name) root)))
        `((file . ,relative)
          (buffer . ,(buffer-name buffer))
          (modified . ,(buffer-modified-p))
          (mode . ,(format "%s" major-mode)))))))

(defun gnopon/workspace-open-file-entries (root)
  "Return open project file entries under ROOT."
  (sort
   (delq nil (mapcar (lambda (buffer)
                       (gnopon/workspace-buffer-file-entry root buffer))
                     (buffer-list)))
   (lambda (left right)
     (string< (alist-get 'file left) (alist-get 'file right)))))

(defun gnopon/workspace-recent-files (root)
  "Return recent files under ROOT as project-relative paths."
  (when (boundp 'recentf-list)
    (let ((files (delq nil
                       (mapcar (lambda (file)
                                 (when (gnopon/workspace-project-file-p root file)
                                   (file-relative-name (file-truename file) root)))
                               recentf-list))))
      (seq-take (delete-dups files) 12))))

(defun gnopon/workspace-tab-names ()
  "Return current tab names when tab-bar state is available."
  (when (fboundp 'tab-bar-tabs)
    (delq nil
          (mapcar (lambda (tab)
                    (alist-get 'name tab))
                  (tab-bar-tabs)))))

(defun gnopon/workspace-snapshot-text ()
  "Return a Markdown workspace snapshot for the current project."
  (let* ((root (file-truename (gnopon/project-root)))
         (open-files (gnopon/workspace-open-file-entries root))
         (modified (seq-filter (lambda (entry)
                                 (alist-get 'modified entry))
                               open-files))
         (recent-files (gnopon/workspace-recent-files root))
         (tabs (gnopon/workspace-tab-names)))
    (concat "# Workspace Snapshot\n\n"
            "- project: `" root "`\n"
            "- workspace: `" (gnopon/workspace-name) "`\n"
            "- generated: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
            "- open-project-files: `" (number-to-string (length open-files)) "`\n"
            "- modified-project-files: `" (number-to-string (length modified)) "`\n"
            "- recent-project-files: `" (number-to-string (length recent-files)) "`\n\n"
            "## Open Project Files\n\n"
            (if open-files
                (mapconcat (lambda (entry)
                             (format "- %s `%s` (%s, `%s`)\n"
                                     (if (alist-get 'modified entry) "[!]" "[ ]")
                                     (alist-get 'file entry)
                                     (alist-get 'buffer entry)
                                     (alist-get 'mode entry)))
                           open-files
                           "")
              "- none\n")
            "\n## Recent Project Files\n\n"
            (if recent-files
                (mapconcat (lambda (file)
                             (format "- `%s`\n" file))
                           recent-files
                           "")
              "- none\n")
            "\n## Tabs\n\n"
            (if tabs
                (mapconcat (lambda (name)
                             (format "- `%s`\n" name))
                           tabs
                           "")
              "- none\n")
            "\n## Resume Commands\n\n"
            "- project dashboard: `C-c g w d`\n"
            "- find project file: `C-c p f`\n"
            "- command matrix: `C-c g p m`\n"
            "- context actions: `C-c g .`\n"
            "- agent handoff: `C-c g a h`\n")))

(defun gnopon/workspace-snapshot ()
  "Open a read-only workspace snapshot."
  (interactive)
  (let ((buffer (get-buffer-create "*workspace-snapshot*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/workspace-snapshot-text))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/workspace-snapshot-path ()
  "Return a project-local workspace snapshot path."
  (let ((dir (gnopon/project-file "logs/workspace/")))
    (make-directory dir t)
    (expand-file-name
     (format "%s-workspace-snapshot.md" (format-time-string "%Y%m%d-%H%M%S"))
     dir)))

(defun gnopon/write-workspace-snapshot ()
  "Write a workspace snapshot under `logs/workspace/'."
  (interactive)
  (let ((path (gnopon/workspace-snapshot-path)))
    (with-temp-file path
      (insert (gnopon/workspace-snapshot-text)))
    (find-file path)
    path))

(define-key gnopon-map (kbd "w t") #'gnopon/project-tab)
(define-key gnopon-map (kbd "w d") #'gnopon/project-dashboard)
(define-key gnopon-map (kbd "w s") #'gnopon/workspace-snapshot)
(define-key gnopon-map (kbd "w S") #'gnopon/write-workspace-snapshot)
(define-key gnopon-map (kbd "w u") #'winner-undo)
(define-key gnopon-map (kbd "w r") #'winner-redo)

(provide 'gnopon-workspace)
;;; gnopon-workspace.el ends here
