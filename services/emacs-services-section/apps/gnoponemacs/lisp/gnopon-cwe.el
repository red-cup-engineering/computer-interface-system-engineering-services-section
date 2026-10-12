;;; gnopon-cwe.el --- Gnopon cockpit on organizing-with-emacs -*- lexical-binding: t; -*-

;;; Commentary:
;; GnoponEmacs supplies the human engineering surface and its project-specific
;; cockpit configuration.  organizing-with-emacs supplies the general Emacs
;; realization of an engine plan.  The relation engine remains the authority
;; for agent identities, sessions, and stream topology.

;;; Code:

(require 'gnopon-core)
(require 'organizing-with-emacs)

(defcustom gnopon-cockpit-engine-entrypoint nil
  "Relation-engine entry point used by the Gnopon cockpit.
The entry point implements the organizing-with-emacs JSON/stdin protocol.  It
is deliberately explicit: loading a human-controlled Emacs configuration must
not locate or launch an agent harness unexpectedly."
  :type '(choice (const nil) file)
  :group 'gnopon)

(defcustom gnopon-cockpit-engine-program "node"
  "Program used to invoke `gnopon-cockpit-engine-entrypoint'."
  :type 'string
  :group 'gnopon)

(defcustom gnopon-cockpit-config-file nil
  "Cockpit topology data for this person or project.
The topology is user data consumed by the relation engine, not a GnoponEmacs
default.  Start from `cockpit.example.json' and keep the resulting file with
the project or personal service that owns its agents and evidence streams."
  :type '(choice (const :tag "Choose a topology before launching" nil) file)
  :group 'gnopon)

(defun gnopon/cockpit-config-path ()
  "Return the explicit cockpit topology data for this launch."
  (unless gnopon-cockpit-config-file
    (user-error "gnopon: set `gnopon-cockpit-config-file' from cockpit.example.json"))
  (expand-file-name gnopon-cockpit-config-file))

(defun gnopon/cockpit-workspace ()
  "Return the project whose agent relation cockpit will be opened."
  (file-truename (gnopon/project-root)))

(defun gnopon/cockpit-launch (&optional agent-id)
  "Choose AGENT-ID, or prompt for one, and open its project relation cockpit.
Gnopon configures the application data; organizing-with-emacs validates and
realizes the engine's fresh session plan in terminal and evidence buffers."
  (interactive)
  (let ((organizing-with-emacs-engine-program gnopon-cockpit-engine-program)
        (organizing-with-emacs-engine-entrypoint gnopon-cockpit-engine-entrypoint)
        (organizing-with-emacs-engine-config (gnopon/cockpit-config-path))
        (organizing-with-emacs-workspace (gnopon/cockpit-workspace)))
    (organizing-with-emacs-launch-cockpit agent-id)))

(defun gnopon/cockpit-claude ()
  "Open the Claude CLI cockpit directly."
  (interactive)
  (gnopon/cockpit-launch "claude"))

(defun gnopon/cockpit-codex ()
  "Open the Codex CLI cockpit directly."
  (interactive)
  (gnopon/cockpit-launch "codex"))

(defun gnopon/cockpit-openai-tui ()
  "Open the OpenAI Agent TUI cockpit directly."
  (interactive)
  (gnopon/cockpit-launch "openai-tui"))

(define-key gnopon-map (kbd "a g") #'gnopon/cockpit-launch)

(provide 'gnopon-cwe)
;;; gnopon-cwe.el ends here
