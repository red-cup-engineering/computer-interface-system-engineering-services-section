;;; gnopon-persistence.el --- Local state -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)

(setq backup-directory-alist `(("." . ,(gnopon/path "backup/")))
      auto-save-file-name-transforms `((".*" ,(gnopon/path "auto-save/") t))
      auto-save-list-file-prefix (gnopon/path "auto-save/sessions-")
      native-comp-eln-load-path (list (gnopon/path "eln-cache/")))

(use-package savehist
  :ensure nil
  :demand t
  :custom
  (savehist-file (gnopon/path "savehist"))
  (savehist-additional-variables '(kill-ring search-ring regexp-search-ring))
  :config
  (savehist-mode 1))

(use-package saveplace
  :ensure nil
  :demand t
  :custom
  (save-place-file (gnopon/path "places"))
  :config
  (save-place-mode 1))

(use-package recentf
  :ensure nil
  :demand t
  :custom
  (recentf-save-file (gnopon/path "recentf"))
  (recentf-max-saved-items 500)
  :config
  (recentf-mode 1))

(provide 'gnopon-persistence)
;;; gnopon-persistence.el ends here
