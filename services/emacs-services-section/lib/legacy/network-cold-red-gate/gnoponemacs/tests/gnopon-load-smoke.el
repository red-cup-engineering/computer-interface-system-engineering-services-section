;;; gnopon-load-smoke.el --- No-network load smoke for GnoponEmacs -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)

(defvar gnopon-load-smoke-root
  (file-name-directory (directory-file-name (file-name-directory load-file-name))))

(add-to-list 'load-path (expand-file-name "lisp/" gnopon-load-smoke-root))

(defmacro use-package (&rest _args)
  "No-op `use-package' for package-free load smoke."
  nil)

(provide 'use-package)

(defmacro transient-define-prefix (name args &optional docstring &rest _body)
  "Define NAME as a no-op command for load smoke."
  `(defun ,name ,args
     ,(or docstring "Transient stub.")
     (interactive)))

(provide 'transient)

(require 'package)
(advice-add 'package-installed-p :override (lambda (&rest _args) t))
(advice-add 'package-refresh-contents :override (lambda (&rest _args) nil))
(advice-add 'package-install :override (lambda (&rest _args) nil))

(setq user-emacs-directory (make-temp-file "gnopon-emacs-" t))

(load (expand-file-name "init.el" gnopon-load-smoke-root) nil t)

(dolist (feature '(gnopon-lib
                   gnopon-core
                   gnopon-ui
                   gnopon-workspace
                   gnopon-completion
                   gnopon-editing
                   gnopon-programming
                   gnopon-ide
                   gnopon-api
                   gnopon-markdown
                   gnopon-tasks
                   gnopon-predication
                   gnopon-formal
                   gnopon-git
                   gnopon-shell
                   gnopon-context
                   gnopon-agents
                   gnopon-mcp
                   gnopon-review
                   gnopon-actions
                   gnopon-security
                   gnopon-persistence
                   gnopon-doctor
                   gnopon-capability
                   gnopon-control
                   gnopon-cockpit))
  (unless (featurep feature)
    (error "Feature did not load: %s" feature)))

(princ "GnoponEmacs no-network load smoke passed.")

;;; gnopon-load-smoke.el ends here
