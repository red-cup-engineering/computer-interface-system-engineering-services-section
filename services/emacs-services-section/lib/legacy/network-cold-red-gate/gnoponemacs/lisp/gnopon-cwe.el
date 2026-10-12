;;; gnopon-cwe.el --- Multi-agent cockpit via computing-with-emacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Binds GnoponEmacs to @emsenn/computing-with-emacs: the generic cockpit realizer
;; (`cwe-cockpit.el') plus the 561 Group cockpit config (`cockpit.config.json').
;;
;; `gnopon/cockpit-launch' offers the interactive agent menu (Claude CLI, Codex
;; CLI, OpenAI Agent TUI), resolves a window plan through the `cwe' bin, and lays
;; out the live chat pane beside monitor panes tailing the Operations Manifold
;; context-injection, hook, and message streams.  Everything 561-specific is in
;; the config and these path bindings; the realizer itself stays environment-free.

;;; Code:

(require 'gnopon-core)

(defvar gnopon-cwe-repo-root
  (file-truename (expand-file-name "../../" gnopon/root))
  "Repository root that owns the GnoponEmacs package (the cockpit cwd).")

(defvar gnopon-cwe-lib-dir
  (expand-file-name "lib/computing-with-emacs/" gnopon-cwe-repo-root)
  "Directory of the @emsenn/computing-with-emacs package.")

(add-to-list 'load-path (expand-file-name "emacs/" gnopon-cwe-lib-dir))

(require 'cwe-cockpit)

(setq cwe-cli (expand-file-name "dist/scripts/cwe.mjs" gnopon-cwe-lib-dir)
      cwe-config-path (expand-file-name "cockpit.config.json" gnopon/root)
      cwe-cwd gnopon-cwe-repo-root)

(defun gnopon/cockpit-launch (&optional agent-id)
  "Choose an agent and open its cockpit over the 561 Group streams.
With AGENT-ID, skip the menu and open that agent directly."
  (interactive)
  (let ((default-directory (file-name-as-directory gnopon-cwe-repo-root)))
    (cwe-launch-cockpit agent-id)))

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
