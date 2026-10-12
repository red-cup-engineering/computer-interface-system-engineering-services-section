;;; early-init.el --- Early startup for GnoponEmacs -*- lexical-binding: t; -*-

;;; Commentary:
;; This file keeps startup strict: no packages, no user-specific state, and no
;; network.  The modular Markdown-native configuration handles the rest after
;; Emacs is ready.

;;; Code:

(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6
      package-enable-at-startup nil
      frame-inhibit-implied-resize t
      inhibit-startup-screen t
      inhibit-startup-echo-area-message user-login-name)

(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))
(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))
(when (fboundp 'menu-bar-mode)
  (menu-bar-mode -1))

(setq native-comp-async-report-warnings-errors 'silent
      native-comp-deferred-compilation t)

;;; early-init.el ends here
