;;; init.el --- Vibemacs entrypoint -*- lexical-binding: t; -*-

;;; Commentary:
;; Vibemacs is an Emacs configuration for agentic programmers.

;;; Code:

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(require 'vibemacs-core)
(require 'vibemacs-ui)
(require 'vibemacs-agent)

(vibemacs-core-apply-defaults)
(vibemacs-ui-apply-defaults)
(vibemacs-agent-apply-defaults)

(provide 'init)

;;; init.el ends here
