;;; init.el --- Bootstrap GnoponEmacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Direct modular bootstrap for the Markdown-native GnoponEmacs cockpit.

;;; Code:

(defvar gnopon/root
  (file-name-directory (file-truename (or load-file-name buffer-file-name)))
  "Root directory of the GnoponEmacs package.")

(add-to-list 'load-path (expand-file-name "lisp/" gnopon/root))
(add-to-list 'load-path
             (expand-file-name "../organizing-with-emacs/lisp/" gnopon/root))

(require 'gnopon-lib)
(require 'gnopon-core)
(require 'gnopon-ui)
(require 'gnopon-workspace)
(require 'gnopon-completion)
(require 'gnopon-editing)
(require 'gnopon-programming)
(require 'gnopon-ide)
(require 'gnopon-api)
(require 'gnopon-markdown)
(require 'gnopon-tasks)
(require 'gnopon-recordkeeping)
(require 'gnopon-predication)
(require 'gnopon-formal)
(require 'gnopon-git)
(require 'gnopon-shell)
(require 'gnopon-context)
(require 'gnopon-agents)
(require 'gnopon-cwe)
(require 'gnopon-mcp)
(require 'gnopon-review)
(require 'gnopon-actions)
(require 'gnopon-security)
(require 'gnopon-persistence)
(require 'gnopon-doctor)
(require 'gnopon-capability)
(require 'gnopon-control)
(require 'gnopon-cockpit)

;;; init.el ends here
