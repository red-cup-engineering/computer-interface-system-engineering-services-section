;;; organizing-with-emacs-panes.el --- Terminal and evidence panes -*- lexical-binding: t; -*-

;;; Commentary:
;; Realizes an engine-provided plan in the carriers Emacs manages well: a
;; terminal process, tailing file buffers, and inspectable read-only documents.

;;; Code:

(require 'term)
(require 'subr-x)
(require 'autorevert)
(require 'organizing-with-emacs-engine)

(declare-function eat-make "eat")
(declare-function markdown-mode "markdown-mode")
(defun organizing-with-emacs--term-name (buffer-name)
  "Return a process name derived from BUFFER-NAME (asterisks stripped)."
  (replace-regexp-in-string "\\`\\*\\|\\*\\'" "" buffer-name))

(defun organizing-with-emacs--env-list (env)
  "Turn an ENV alist of (KEY . VALUE) into \"KEY=VALUE\" strings."
  (mapcar (lambda (pair)
            (format "%s=%s"
                    (if (symbolp (car pair)) (symbol-name (car pair)) (car pair))
                    (cdr pair)))
          env))

(defun organizing-with-emacs--use-eat-p ()
  "Return non-nil when the chat pane should use the `eat' terminal."
  (and (memq organizing-with-emacs-chat-terminal '(auto eat))
       (require 'eat nil t)
       (fboundp 'eat-make)))

(defun organizing-with-emacs--spawn-terminal (name program args cwd env)
  "Spawn PROGRAM with ARGS in CWD under ENV; return a ready terminal buffer.
Uses the rich `eat' terminal when available, else the built-in `term'."
  (let ((process-environment (append env process-environment))
        (default-directory (file-name-as-directory (expand-file-name cwd))))
    (if (organizing-with-emacs--use-eat-p)
        (apply #'eat-make name program nil args)
      (let ((buffer (apply #'make-term name program nil args)))
        (with-current-buffer buffer
          (term-mode)
          (term-char-mode))
        buffer))))

(defun organizing-with-emacs--apply-persona (persona)
  "Paint the current buffer with PERSONA's name, glyph, and colour."
  (when persona
    (let ((name (alist-get 'name persona))
          (color (alist-get 'color persona))
          (glyph (alist-get 'glyph persona)))
      (setq-local header-line-format
                  (format " %s  %s " (or glyph "") (or name "session")))
      (when (and color (stringp color))
        (face-remap-add-relative 'header-line
                                 `(:background ,color :foreground "white" :weight bold))))))

(defun organizing-with-emacs--make-chat (pane)
  "Return a live terminal buffer for chat PANE, starting it if needed.
The pane's identity env is exported to the process and its persona, when any,
tints the chat header so each session reads as its own character."
  (let* ((buffer-name (alist-get 'buffer pane))
         (program (alist-get 'command pane))
         (args (alist-get 'args pane))
         (cwd (or (alist-get 'cwd pane) (organizing-with-emacs--cwd)))
         (env (organizing-with-emacs--env-list (alist-get 'env pane)))
         (persona (alist-get 'persona pane))
         (existing (get-buffer buffer-name))
         (process (and existing (get-buffer-process existing))))
    (cond
     ((and process (process-live-p process)) existing)
     (t
      (when existing (kill-buffer existing))
      (unless (executable-find program)
        (user-error "organizing-with-emacs: chat program not found on PATH: %s" program))
      (let ((buffer (organizing-with-emacs--spawn-terminal (organizing-with-emacs--term-name buffer-name) program args cwd env)))
        (with-current-buffer buffer
          (rename-buffer buffer-name t)
          (organizing-with-emacs--apply-persona persona))
        buffer)))))

(defvar organizing-with-emacs-monitor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'organizing-with-emacs-monitor-refresh)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `organizing-with-emacs-monitor-mode'.")

(define-minor-mode organizing-with-emacs-monitor-mode
  "Minor mode for cockpit monitor panes that have no stream yet."
  :lighter " RelMon"
  :keymap organizing-with-emacs-monitor-mode-map)

(defun organizing-with-emacs--render-static (name pane body)
  "Render BODY into a fresh read-only monitor buffer NAME for PANE."
  (let ((buffer (get-buffer-create name)))
    (with-current-buffer buffer
      (setq-local organizing-with-emacs-monitor-pane pane)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert body)
        (when (fboundp 'markdown-mode)
          (ignore-errors (markdown-mode))))
      (organizing-with-emacs--apply-persona (alist-get 'persona pane))
      (organizing-with-emacs-monitor-mode 1)
      (setq buffer-read-only t)
      (goto-char (point-min)))
    buffer))

(defun organizing-with-emacs--make-monitor (pane)
  "Return a buffer monitoring PANE.
A present file is tailed live; an inline `content' pane (e.g. a session's world
card) is rendered static; an absent stream gets a retryable placeholder."
  (let* ((path (alist-get 'path pane))
         (content (alist-get 'content pane))
         (label (alist-get 'label pane))
         (name (alist-get 'buffer pane)))
    (cond
     ((and path (file-exists-p path))
      (let ((buffer (find-file-noselect path t)))
        (with-current-buffer buffer
          (rename-buffer name t)
          (setq-local organizing-with-emacs-monitor-pane pane)
          (goto-char (point-max))
          (auto-revert-tail-mode 1)
          (view-mode 1))
        buffer))
     (content
      (organizing-with-emacs--render-static name pane content))
     (t
      (organizing-with-emacs--render-static
       name pane
       (format "# %s\n\nNo stream yet at:\n  %s\n\nPress `g' to retry once it exists.\n"
               label (or path "(command stream)")))))))

(defun organizing-with-emacs-monitor-refresh ()
  "Re-attach the current monitor pane to its stream."
  (interactive)
  (unless organizing-with-emacs-monitor-pane
    (user-error "organizing-with-emacs: not a cockpit monitor buffer"))
  (let* ((pane organizing-with-emacs-monitor-pane)
         (window (selected-window))
         (buffer (organizing-with-emacs--make-monitor pane)))
    (set-window-buffer window buffer)
    (select-window window)))

(defun organizing-with-emacs--write-if-absent (path content)
  "Write CONTENT to PATH only when PATH does not already exist.
Ensures the parent directory.  Returns non-nil when it wrote."
  (unless (file-exists-p path)
    (make-directory (file-name-directory path) t)
    (with-temp-file path (insert content))
    t))

(defun organizing-with-emacs--provision-character (character)
  "Materialize a CHARACTER's data/memory home before launch.
Creates the home dir, seeds the character's own memory file once (never
clobbering accumulated memory), and ensures the shared memory files exist."
  (let ((home (alist-get 'home character))
        (memory-file (alist-get 'memoryFile character))
        (memory-seed (alist-get 'memorySeed character))
        (shared (alist-get 'sharedMemory character)))
    (when home (make-directory home t))
    (when (and memory-file memory-seed)
      (organizing-with-emacs--write-if-absent memory-file memory-seed))
    (dolist (path shared)
      (organizing-with-emacs--write-if-absent
       path
       "# Shared 561 Group Claude memory\n\nDeeper memory shared across all Claude characters and the general systems.\n"))))


(provide 'organizing-with-emacs-panes)
