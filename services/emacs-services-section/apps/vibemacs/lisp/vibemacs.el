;;; vibemacs.el --- Agent-directed development in Emacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Vibemacs is the application boundary.  It composes durable work state,
;; project evidence, inspectable artifacts, and interactive controls; the
;; individual modules do not install global editor behavior themselves.

;;; Code:

(require 'vibemacs-foundation)
(require 'vibemacs-appearance)
(require 'vibemacs-workflow)
(require 'vibemacs-evidence)
(require 'vibemacs-artifacts)
(require 'vibemacs-interface)

(defvar vibemacs--activated nil
  "Non-nil after the Vibemacs application profile has been installed.")

;;;###autoload
(defun vibemacs-activate ()
  "Install the complete Vibemacs application profile once.

The application remains usable through its commands when the profile is not
active; activation installs the global editor defaults, appearance, hooks,
and `C-c v' command prefix."
  (interactive)
  (unless vibemacs--activated
    (vibemacs-foundation-apply-defaults)
    (vibemacs-appearance-apply-defaults)
    (vibemacs-apply-defaults)
    (setq vibemacs--activated t))
  vibemacs--activated)

(provide 'vibemacs)

;;; vibemacs.el ends here
