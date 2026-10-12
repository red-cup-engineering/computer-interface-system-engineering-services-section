;;; init.el --- Vibemacs entry point -*- lexical-binding: t; -*-

;;; Code:

(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory (or load-file-name buffer-file-name))))

(require 'vibemacs)
(vibemacs-activate)

;;; init.el ends here
