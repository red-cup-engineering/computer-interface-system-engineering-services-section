;;; vibemacs-foundation.el --- Core defaults for Vibemacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Foundational editor behavior shared by the rest of the configuration.

;;; Code:

(require 'cl-lib)
(require 'project)
(require 'subr-x)
(require 'xref)

(defgroup vibemacs nil
  "A next-generation Emacs configuration for agentic programmers."
  :group 'convenience
  :prefix "vibemacs-")

(defcustom vibemacs-cycle-directory "dev/docs/journal"
  "Repository-relative directory for public development journal entries."
  :type 'string
  :group 'vibemacs)

(defcustom vibemacs-notes-directory "dev/notes"
  "Repository-relative directory for local working notes."
  :type 'string
  :group 'vibemacs)

(defvar vibemacs-prefix-map
  (let ((map (make-sparse-keymap)))
    map)
  "Prefix map for Vibemacs commands.")

(define-minor-mode vibemacs-mode
  "Toggle Vibemacs project workflow bindings."
  :global t
  :lighter " Vibe"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c v") vibemacs-prefix-map)
            map))

(defun vibemacs-project-root ()
  "Return the current project root, falling back to `user-emacs-directory'."
  (file-name-as-directory
   (or (when-let ((project (project-current nil)))
         (project-root project))
       user-emacs-directory)))

(defun vibemacs-expand-project-file (path)
  "Expand repository-relative PATH from the current project root."
  (expand-file-name path (vibemacs-project-root)))

(defun vibemacs-ensure-directory (directory)
  "Create DIRECTORY when needed and return it."
  (unless (file-directory-p directory)
    (make-directory directory t))
  directory)

(defun vibemacs-slugify (title)
  "Return a lowercase URL slug for TITLE."
  (let* ((downcased (downcase (string-trim title)))
         (ascii-ish (replace-regexp-in-string "[^[:alnum:]]+" "-" downcased))
         (trimmed (replace-regexp-in-string "\\`-\\|-\\'" "" ascii-ish)))
    (if (string-empty-p trimmed) "untitled" trimmed)))

(defun vibemacs-today ()
  "Return today's date as YYYY-MM-DD."
  (format-time-string "%Y-%m-%d"))

(defun vibemacs-buffer-heading ()
  "Return a useful heading for the current buffer."
  (or (when buffer-file-name
        (file-relative-name buffer-file-name (vibemacs-project-root)))
      (buffer-name)))

(defun vibemacs-new-scratch-buffer (name mode)
  "Create or switch to scratch buffer NAME using major MODE."
  (let ((buffer (get-buffer-create name)))
    (pop-to-buffer buffer)
    (funcall mode)
    buffer))

(defun vibemacs-markdown-mode ()
  "Use `markdown-mode' when available, otherwise fall back to `text-mode'."
  (if (fboundp 'markdown-mode)
      (markdown-mode)
    (text-mode)))

(defun vibemacs-foundation-apply-defaults ()
  "Apply core Vibemacs defaults."
  (setq-default indent-tabs-mode nil)
  (setq-default tab-width 2)
  (setq make-backup-files nil)
  (setq auto-save-default nil)
  (setq create-lockfiles nil)
  (setq ring-bell-function #'ignore)
  (setq sentence-end-double-space nil)
  (setq confirm-kill-emacs #'y-or-n-p)
  (setq use-short-answers t)
  (setq read-process-output-max (* 1024 1024))
  (setq xref-search-program 'ripgrep)
  (electric-pair-mode 1)
  (save-place-mode 1)
  (unless noninteractive
    (recentf-mode 1))
  (global-auto-revert-mode 1)
  (delete-selection-mode 1)
  (vibemacs-mode 1))

(provide 'vibemacs-foundation)

;;; vibemacs-foundation.el ends here
