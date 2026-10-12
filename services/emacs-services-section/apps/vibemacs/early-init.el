;;; early-init.el --- Early startup for Vibemacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Keep startup deterministic and quiet before the main configuration loads.

;;; Code:

(setq package-enable-at-startup nil)
(setq inhibit-startup-screen t)
(setq frame-inhibit-implied-resize t)
(setq site-run-file nil)

(when (fboundp 'menu-bar-mode)
  (menu-bar-mode -1))
(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))

(provide 'early-init)

;;; early-init.el ends here
