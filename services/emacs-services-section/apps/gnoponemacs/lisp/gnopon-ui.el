;;; gnopon-ui.el --- Cockpit UI -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)

(defun gnopon/load-theme-safely (theme)
  "Load THEME without aborting GnoponEmacs startup."
  (condition-case err
      (load-theme theme t)
    (error
     (message "GnoponEmacs: theme %s unavailable: %s"
              theme
              (error-message-string err)))))

(gnopon/use-optional-package modus-themes
  :demand t
  :custom
  (modus-themes-bold-constructs t)
  (modus-themes-italic-constructs t)
  (modus-themes-mixed-fonts t)
  :config
  (gnopon/load-theme-safely 'modus-operandi))

(gnopon/use-optional-package mixed-pitch
  :hook (text-mode . mixed-pitch-mode))

(gnopon/use-optional-package olivetti
  :hook (text-mode . olivetti-mode))

(gnopon/use-optional-package auto-dark
  :config
  (auto-dark-mode 1))

(defun gnopon/toggle-theme ()
  "Toggle the active Modus theme, or report when it is unavailable."
  (interactive)
  (if (fboundp 'modus-themes-toggle)
      (modus-themes-toggle)
    (user-error "gnopon: install modus-themes to toggle the application theme")))

(define-key gnopon-map (kbd "u t") #'gnopon/toggle-theme)

(unless custom-enabled-themes
  (gnopon/load-theme-safely 'modus-operandi))

(use-package which-key
  :if (gnopon/optional-package-available-p 'which-key)
  :demand t
  :diminish
  :custom
  (which-key-idle-delay 0.35)
  (which-key-separator " -> ")
  :config
  (which-key-mode 1))

(use-package transient
  :if (gnopon/optional-package-available-p 'transient)
  :demand t)

(gnopon/use-optional-package helpful
  :bind
  (([remap describe-function] . helpful-callable)
   ([remap describe-variable] . helpful-variable)
   ([remap describe-key] . helpful-key)
   ([remap describe-command] . helpful-command)))

(use-package nerd-icons
  :if (and (display-graphic-p)
           (gnopon/optional-package-available-p 'nerd-icons)))

(use-package doom-modeline
  :if (and (display-graphic-p)
           (gnopon/optional-package-available-p 'doom-modeline))
  :custom
  (doom-modeline-height 24)
  (doom-modeline-buffer-file-name-style 'truncate-with-project)
  :config
  (doom-modeline-mode 1))

(provide 'gnopon-ui)
;;; gnopon-ui.el ends here
