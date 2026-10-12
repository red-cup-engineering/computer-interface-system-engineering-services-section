;;; vibemacs-appearance.el --- Interface defaults for Vibemacs -*- lexical-binding: t; -*-

;;; Commentary:
;; A restrained built-in UI profile suitable for long agentic sessions.

;;; Code:

(require 'vibemacs-foundation)

(deftheme vibemacs-dark
  "A quiet dark theme for Vibemacs.")

(custom-theme-set-faces
 'vibemacs-dark
 '(default ((t (:background "#101316" :foreground "#eef2f3"))))
 '(cursor ((t (:background "#7ad7b5"))))
 '(fringe ((t (:background "#101316"))))
 '(region ((t (:background "#24483d"))))
 '(mode-line ((t (:background "#34b991" :foreground "#07110e" :box nil :weight bold))))
 '(mode-line-inactive ((t (:background "#20272e" :foreground "#9aa8ad" :box nil))))
 '(minibuffer-prompt ((t (:foreground "#7ad7b5" :weight bold))))
 '(font-lock-comment-face ((t (:foreground "#9aa8ad"))))
 '(font-lock-keyword-face ((t (:foreground "#7ad7b5" :weight bold))))
 '(font-lock-string-face ((t (:foreground "#f2b84b"))))
 '(font-lock-function-name-face ((t (:foreground "#8fc7ff"))))
 '(font-lock-variable-name-face ((t (:foreground "#eef2f3"))))
 '(line-number ((t (:foreground "#53646d" :background "#101316"))))
 '(line-number-current-line ((t (:foreground "#7ad7b5" :background "#182026" :weight bold)))))

(provide-theme 'vibemacs-dark)

(defun vibemacs-appearance-apply-defaults ()
  "Apply built-in Vibemacs interface defaults."
  (setq visible-bell nil)
  (setq-default cursor-type 'bar)
  (blink-cursor-mode -1)
  (column-number-mode 1)
  (global-display-line-numbers-mode 1)
  (set-face-attribute 'default nil :height 110)
  (enable-theme 'vibemacs-dark))

(provide 'vibemacs-appearance)

;;; vibemacs-appearance.el ends here
