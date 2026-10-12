;;; organizing-with-emacs-engine.el --- Relation-engine transport for Emacs -*- lexical-binding: t; -*-

;;; Commentary:
;; The agent-organization-engine owns identities, session plans, and stream
;; topology.  This module sends it a configured JSON document on standard input
;; and consumes its JSON responses; it deliberately owns neither the topology
;; nor a vendor-specific agent implementation.

;;; Code:

(require 'json)
(require 'seq)
(require 'subr-x)

(defgroup organizing-with-emacs nil
  "Emacs interface to an agent organization engine."
  :group 'tools
  :prefix "organizing-with-emacs-")

(defcustom organizing-with-emacs-engine-program "node"
  "Program used to invoke the relation-engine entry point."
  :type 'string
  :group 'organizing-with-emacs)

(defcustom organizing-with-emacs-engine-entrypoint nil
  "Absolute path to the relation-engine command-line entry point.
The program receives this path followed by an action, and receives the engine
configuration JSON on standard input.  Nil means the application is not yet
connected to an engine."
  :type '(choice (const nil) file)
  :group 'organizing-with-emacs)

(defcustom organizing-with-emacs-engine-config nil
  "Absolute path to the relation-engine configuration JSON document.
It supplies the environment-specific agents, identities, and evidence streams."
  :type '(choice (const nil) file)
  :group 'organizing-with-emacs)

(defcustom organizing-with-emacs-workspace nil
  "Working directory the cockpit resolves stream/agent paths against.
When nil, `default-directory' at launch time is used."
  :type '(choice (const nil) directory)
  :group 'organizing-with-emacs)

(defcustom organizing-with-emacs-chat-width-fraction 0.6
  "Fraction of the frame width given to the chat pane."
  :type 'number
  :group 'organizing-with-emacs)

(defcustom organizing-with-emacs-chat-terminal 'auto
  "Terminal backend for the chat pane.
`auto' uses `eat' when available (rich truecolor, full-screen TUIs such as
Claude and Codex render correctly) and falls back to the built-in `term'.
`eat' forces eat; `term' forces the built-in terminal."
  :type '(choice (const auto) (const eat) (const term))
  :group 'organizing-with-emacs)

(defvar-local organizing-with-emacs-monitor-pane nil
  "The resolved monitor pane alist realized in the current buffer.")

(defvar-local organizing-with-emacs-session nil
  "The resolved session alist this cockpit buffer belongs to, when any.")

;;; Bin transport --------------------------------------------------------------

(defun organizing-with-emacs--require-engine ()
  "Signal a user error unless an engine entry point and configuration are ready."
  (unless (and organizing-with-emacs-engine-entrypoint (file-exists-p (expand-file-name organizing-with-emacs-engine-entrypoint)))
    (user-error "organizing-with-emacs: set `organizing-with-emacs-engine-entrypoint' to an existing relation-engine entry point (got %s)" organizing-with-emacs-engine-entrypoint))
  (unless (and organizing-with-emacs-engine-config (file-readable-p organizing-with-emacs-engine-config))
    (user-error "organizing-with-emacs: set `organizing-with-emacs-engine-config' to a readable engine config (got %s)" organizing-with-emacs-engine-config)))

(defun organizing-with-emacs--cwd ()
  "Return the resolved cockpit working directory."
  (expand-file-name (or organizing-with-emacs-workspace default-directory)))

(defun organizing-with-emacs--run (args)
  "Run the configured relation engine with ARGS and its config on standard input.
Return stdout as a string, or signal a user error containing the engine stderr."
  (organizing-with-emacs--require-engine)
  (with-temp-buffer
    (let ((err-file (make-temp-file "organizing-with-emacs-err")))
      (unwind-protect
          (let ((status (apply #'call-process organizing-with-emacs-engine-program organizing-with-emacs-engine-config
                               (list t err-file) nil
                               (cons (expand-file-name organizing-with-emacs-engine-entrypoint) args))))
            (if (eq status 0)
                (buffer-string)
              (user-error "organizing-with-emacs %s failed (%s): %s"
                          (string-join args " ") status
                          (with-temp-buffer
                            (insert-file-contents err-file)
                            (string-trim (buffer-string))))))
        (delete-file err-file)))))

(defun organizing-with-emacs--json (&rest args)
  "Run the configured engine with ARGS and parse its JSON stdout into Lisp."
  (json-parse-string (organizing-with-emacs--run args)
                     :object-type 'alist
                     :array-type 'list
                     :null-object nil
                     :false-object nil))

(defun organizing-with-emacs-list-agents ()
  "Return the cockpit's agents as a list of alists."
  (organizing-with-emacs--json "list-agents"))

(defun organizing-with-emacs-resolve-plan (agent-id)
  "Resolve a sessionless cockpit window plan for AGENT-ID."
  (organizing-with-emacs--json "resolve-cockpit" "--agent" agent-id "--cwd" (organizing-with-emacs--cwd)))

(defun organizing-with-emacs-open-session (agent-id &optional session-id persona)
  "Open a fresh persona-bound cockpit session plan for AGENT-ID.
Optional SESSION-ID and PERSONA pin an explicit id/character; otherwise each
call mints a new session with its own character."
  (apply #'organizing-with-emacs--json
         "open-session" "--agent" agent-id "--cwd" (organizing-with-emacs--cwd)
         (append (when session-id (list "--session" session-id))
                 (when persona (list "--persona" persona)))))

;;; The interactive chooser ----------------------------------------------------

(defun organizing-with-emacs--agent-line (agent)
  "Return the completion line for AGENT."
  (format "%s — %s"
          (alist-get 'label agent)
          (or (alist-get 'description agent)
              (symbol-name (alist-get 'kind agent)))))

(defun organizing-with-emacs-choose-agent ()
  "Prompt for a cockpit agent and return its id string."
  (let* ((agents (organizing-with-emacs-list-agents))
         (default (seq-find (lambda (agent) (eq t (alist-get 'isDefault agent))) agents))
         (table (mapcar (lambda (agent) (cons (organizing-with-emacs--agent-line agent) (alist-get 'id agent)))
                        agents))
         (choice (completing-read
                  "Cockpit agent: " (mapcar #'car table) nil t nil nil
                  (when default (organizing-with-emacs--agent-line default)))))
    (or (cdr (assoc choice table))
        (user-error "organizing-with-emacs: no agent selected"))))

;;; Realizing the plan ---------------------------------------------------------

(provide 'organizing-with-emacs-engine)
