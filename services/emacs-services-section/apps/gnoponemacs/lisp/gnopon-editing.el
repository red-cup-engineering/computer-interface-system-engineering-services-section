;;; gnopon-editing.el --- Editing ergonomics -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)

(gnopon/use-optional-package avy
  :bind
  (("C-:" . avy-goto-char-timer)
   ("M-g w" . avy-goto-word-1)))

(gnopon/use-optional-package expand-region
  :bind ("C-=" . er/expand-region))

(gnopon/use-optional-package multiple-cursors
  :bind
  (("C-S-c C-S-c" . mc/edit-lines)
   ("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)))

(gnopon/use-optional-package yasnippet
  :demand t
  :diminish yas-minor-mode
  :config
  (yas-global-mode 1))

(gnopon/use-optional-package yasnippet-snippets
  :after yasnippet)

(gnopon/use-optional-package paredit
  :hook
  ((emacs-lisp-mode lisp-mode scheme-mode clojure-mode racket-mode) . paredit-mode))

(use-package whitespace
  :ensure nil
  :hook (before-save . delete-trailing-whitespace)
  :custom
  (whitespace-style '(face trailing tabs tab-mark)))

(provide 'gnopon-editing)
;;; gnopon-editing.el ends here
