;;; cwe-cockpit.el --- Realize a computing-with-emacs cockpit plan -*- lexical-binding: t; -*-

;;; Commentary:
;; Generic, environment-agnostic Emacs consumer of @emsenn/computing-with-emacs.
;;
;; The cockpit topology — which agents exist, which context/hook/message streams
;; to watch — lives in a JSON config (`cwe-config-path') and is resolved by the
;; `cwe' bin (`cwe-cli'), never hard-coded here.  This file only: offers the
;; interactive agent chooser, asks the bin to resolve a window plan, and realizes
;; that plan as one live chat pane surrounded by monitor panes tailing the
;; configured streams.  Point it at a different config and it drives a different
;; environment unchanged.

;;; Code:

(require 'json)
(require 'term)
(require 'seq)
(require 'subr-x)
(require 'autorevert)

(declare-function eat-make "eat")
(declare-function markdown-mode "markdown-mode")

(defgroup cwe nil
  "Computing-with-emacs cockpit."
  :group 'tools
  :prefix "cwe-")

(defcustom cwe-node-program "node"
  "Program used to run the `cwe' dispatcher bin."
  :type 'string
  :group 'cwe)

(defcustom cwe-cli nil
  "Absolute path to the built `cwe' dispatcher (dist/scripts/cwe.mjs).
Set by the host package; nil means the cockpit is unconfigured."
  :type '(choice (const nil) file)
  :group 'cwe)

(defcustom cwe-config-path nil
  "Absolute path to the cockpit config JSON document.
This is the only environment-specific input: it names the agents and the
context/hook/message streams.  Set by the host package."
  :type '(choice (const nil) file)
  :group 'cwe)

(defcustom cwe-cwd nil
  "Working directory the cockpit resolves stream/agent paths against.
When nil, `default-directory' at launch time is used."
  :type '(choice (const nil) directory)
  :group 'cwe)

(defcustom cwe-chat-width-fraction 0.6
  "Fraction of the frame width given to the chat pane."
  :type 'number
  :group 'cwe)

(defcustom cwe-chat-terminal 'auto
  "Terminal backend for the chat pane.
`auto' uses `eat' when available (rich truecolor, full-screen TUIs such as
Claude and Codex render correctly) and falls back to the built-in `term'.
`eat' forces eat; `term' forces the built-in terminal."
  :type '(choice (const auto) (const eat) (const term))
  :group 'cwe)

(defvar-local cwe-monitor-pane nil
  "The resolved monitor pane alist realized in the current buffer.")

(defvar-local cwe-session nil
  "The resolved session alist this cockpit buffer belongs to, when any.")

;;; Bin transport --------------------------------------------------------------

(defun cwe--require-cli ()
  "Signal a user error unless the cockpit bin and config are ready."
  (unless (and cwe-cli (file-exists-p (expand-file-name cwe-cli)))
    (user-error "cwe: set `cwe-cli' to the built dist/scripts/cwe.mjs (got %s)" cwe-cli))
  (unless (and cwe-config-path (file-readable-p cwe-config-path))
    (user-error "cwe: set `cwe-config-path' to a readable cockpit config (got %s)" cwe-config-path)))

(defun cwe--cwd ()
  "Return the resolved cockpit working directory."
  (expand-file-name (or cwe-cwd default-directory)))

(defun cwe--run (args)
  "Run the cwe bin with ARGS, the cockpit config on stdin.
Return stdout as a string, or signal a user error with the bin's stderr."
  (cwe--require-cli)
  (with-temp-buffer
    (let ((err-file (make-temp-file "cwe-err")))
      (unwind-protect
          (let ((status (apply #'call-process cwe-node-program cwe-config-path
                               (list t err-file) nil
                               (cons (expand-file-name cwe-cli) args))))
            (if (eq status 0)
                (buffer-string)
              (user-error "cwe %s failed (%s): %s"
                          (string-join args " ") status
                          (with-temp-buffer
                            (insert-file-contents err-file)
                            (string-trim (buffer-string))))))
        (delete-file err-file)))))

(defun cwe--json (&rest args)
  "Run the cwe bin with ARGS and parse its JSON stdout into Lisp."
  (json-parse-string (cwe--run args)
                     :object-type 'alist
                     :array-type 'list
                     :null-object nil
                     :false-object nil))

(defun cwe-list-agents ()
  "Return the cockpit's agents as a list of alists."
  (cwe--json "list-agents"))

(defun cwe-resolve-plan (agent-id)
  "Resolve a sessionless cockpit window plan for AGENT-ID."
  (cwe--json "resolve-cockpit" "--agent" agent-id "--cwd" (cwe--cwd)))

(defun cwe-open-session (agent-id &optional session-id persona)
  "Open a fresh persona-bound cockpit session plan for AGENT-ID.
Optional SESSION-ID and PERSONA pin an explicit id/character; otherwise each
call mints a new session with its own character."
  (apply #'cwe--json
         "open-session" "--agent" agent-id "--cwd" (cwe--cwd)
         (append (when session-id (list "--session" session-id))
                 (when persona (list "--persona" persona)))))

;;; The interactive chooser ----------------------------------------------------

(defun cwe--agent-line (agent)
  "Return the completion line for AGENT."
  (format "%s — %s"
          (alist-get 'label agent)
          (or (alist-get 'description agent)
              (symbol-name (alist-get 'kind agent)))))

(defun cwe-choose-agent ()
  "Prompt for a cockpit agent and return its id string."
  (let* ((agents (cwe-list-agents))
         (default (seq-find (lambda (agent) (eq t (alist-get 'isDefault agent))) agents))
         (table (mapcar (lambda (agent) (cons (cwe--agent-line agent) (alist-get 'id agent)))
                        agents))
         (choice (completing-read
                  "Cockpit agent: " (mapcar #'car table) nil t nil nil
                  (when default (cwe--agent-line default)))))
    (or (cdr (assoc choice table))
        (user-error "cwe: no agent selected"))))

;;; Realizing the plan ---------------------------------------------------------

(defun cwe--term-name (buffer-name)
  "Return a process name derived from BUFFER-NAME (asterisks stripped)."
  (replace-regexp-in-string "\\`\\*\\|\\*\\'" "" buffer-name))

(defun cwe--env-list (env)
  "Turn an ENV alist of (KEY . VALUE) into \"KEY=VALUE\" strings."
  (mapcar (lambda (pair)
            (format "%s=%s"
                    (if (symbolp (car pair)) (symbol-name (car pair)) (car pair))
                    (cdr pair)))
          env))

(defun cwe--use-eat-p ()
  "Return non-nil when the chat pane should use the `eat' terminal."
  (and (memq cwe-chat-terminal '(auto eat))
       (require 'eat nil t)
       (fboundp 'eat-make)))

(defun cwe--spawn-terminal (name program args cwd env)
  "Spawn PROGRAM with ARGS in CWD under ENV; return a ready terminal buffer.
Uses the rich `eat' terminal when available, else the built-in `term'."
  (let ((process-environment (append env process-environment))
        (default-directory (file-name-as-directory (expand-file-name cwd))))
    (if (cwe--use-eat-p)
        (apply #'eat-make name program nil args)
      (let ((buffer (apply #'make-term name program nil args)))
        (with-current-buffer buffer
          (term-mode)
          (term-char-mode))
        buffer))))

(defun cwe--apply-persona (persona)
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

(defun cwe--make-chat (pane)
  "Return a live terminal buffer for chat PANE, starting it if needed.
The pane's identity env is exported to the process and its persona, when any,
tints the chat header so each session reads as its own character."
  (let* ((buffer-name (alist-get 'buffer pane))
         (program (alist-get 'command pane))
         (args (alist-get 'args pane))
         (cwd (or (alist-get 'cwd pane) (cwe--cwd)))
         (env (cwe--env-list (alist-get 'env pane)))
         (persona (alist-get 'persona pane))
         (existing (get-buffer buffer-name))
         (process (and existing (get-buffer-process existing))))
    (cond
     ((and process (process-live-p process)) existing)
     (t
      (when existing (kill-buffer existing))
      (unless (executable-find program)
        (user-error "cwe: chat program not found on PATH: %s" program))
      (let ((buffer (cwe--spawn-terminal (cwe--term-name buffer-name) program args cwd env)))
        (with-current-buffer buffer
          (rename-buffer buffer-name t)
          (cwe--apply-persona persona))
        buffer)))))

(defvar cwe-monitor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'cwe-monitor-refresh)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `cwe-monitor-mode'.")

(define-minor-mode cwe-monitor-mode
  "Minor mode for cockpit monitor panes that have no stream yet."
  :lighter " CweMon"
  :keymap cwe-monitor-mode-map)

(defun cwe--render-static (name pane body)
  "Render BODY into a fresh read-only monitor buffer NAME for PANE."
  (let ((buffer (get-buffer-create name)))
    (with-current-buffer buffer
      (setq-local cwe-monitor-pane pane)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert body)
        (when (fboundp 'markdown-mode)
          (ignore-errors (markdown-mode))))
      (cwe--apply-persona (alist-get 'persona pane))
      (cwe-monitor-mode 1)
      (setq buffer-read-only t)
      (goto-char (point-min)))
    buffer))

(defun cwe--make-monitor (pane)
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
          (setq-local cwe-monitor-pane pane)
          (goto-char (point-max))
          (auto-revert-tail-mode 1)
          (view-mode 1))
        buffer))
     (content
      (cwe--render-static name pane content))
     (t
      (cwe--render-static
       name pane
       (format "# %s\n\nNo stream yet at:\n  %s\n\nPress `g' to retry once it exists.\n"
               label (or path "(command stream)")))))))

(defun cwe-monitor-refresh ()
  "Re-attach the current monitor pane to its stream."
  (interactive)
  (unless cwe-monitor-pane
    (user-error "cwe: not a cockpit monitor buffer"))
  (let* ((pane cwe-monitor-pane)
         (window (selected-window))
         (buffer (cwe--make-monitor pane)))
    (set-window-buffer window buffer)
    (select-window window)))

(defun cwe--write-if-absent (path content)
  "Write CONTENT to PATH only when PATH does not already exist.
Ensures the parent directory.  Returns non-nil when it wrote."
  (unless (file-exists-p path)
    (make-directory (file-name-directory path) t)
    (with-temp-file path (insert content))
    t))

(defun cwe--provision-character (character)
  "Materialize a CHARACTER's data/memory home before launch.
Creates the home dir, seeds the character's own memory file once (never
clobbering accumulated memory), and ensures the shared memory files exist."
  (let ((home (alist-get 'home character))
        (memory-file (alist-get 'memoryFile character))
        (memory-seed (alist-get 'memorySeed character))
        (shared (alist-get 'sharedMemory character)))
    (when home (make-directory home t))
    (when (and memory-file memory-seed)
      (cwe--write-if-absent memory-file memory-seed))
    (dolist (path shared)
      (cwe--write-if-absent
       path
       "# Shared 561 Group Claude memory\n\nDeeper memory shared across all Claude characters and the general systems.\n"))))

(defun cwe-realize-cockpit (plan)
  "Realize cockpit PLAN: a chat pane with a column of monitor panes.
Return PLAN."
  (let* ((session (alist-get 'session plan))
         (character (alist-get 'character plan))
         (_ (when character (cwe--provision-character character)))
         (chat-buffer (cwe--make-chat (alist-get 'chat plan)))
         (monitor-buffers (mapcar #'cwe--make-monitor (alist-get 'monitors plan))))
    (when session
      (with-current-buffer chat-buffer (setq-local cwe-session session)))
    (delete-other-windows)
    (switch-to-buffer chat-buffer)
    (let ((chat-window (selected-window)))
      (when monitor-buffers
        (let ((right (split-window-right
                      (floor (* (window-total-width) cwe-chat-width-fraction)))))
          (select-window right)
          (switch-to-buffer (car monitor-buffers))
          (dolist (buffer (cdr monitor-buffers))
            (select-window (split-window-below))
            (switch-to-buffer buffer))
          (balance-windows right)))
      (select-window chat-window))
    plan))

;;;###autoload
(defun cwe-launch-cockpit (&optional agent-id)
  "Choose a cockpit agent (or use AGENT-ID) and open a fresh session cockpit.
Presents the interactive agent menu, mints a NEW persona-bound session through
the `cwe' bin (so each launch is its own character, not a shared \"claude\"),
and lays out the rich chat pane beside the session's world card and the
configured context, hook, and message monitor panes."
  (interactive)
  (cwe--require-cli)
  (let* ((id (or agent-id (cwe-choose-agent)))
         (plan (cwe-open-session id)))
    (cwe-realize-cockpit plan)
    (let ((persona (alist-get 'persona (alist-get 'session plan))))
      (message "cwe: %s session as %s %s"
               (alist-get 'label plan)
               (or (alist-get 'glyph persona) "")
               (or (alist-get 'name persona) "")))
    plan))

(provide 'cwe-cockpit)
;;; cwe-cockpit.el ends here
