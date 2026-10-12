;;; gnopon-completion.el --- Completion and navigation -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)

(gnopon/use-optional-package vertico
  :demand t
  :custom
  (vertico-cycle t)
  (vertico-resize nil)
  :config
  (vertico-mode 1))

(gnopon/use-optional-package orderless
  :demand t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

(gnopon/use-optional-package marginalia
  :demand t
  :config
  (marginalia-mode 1))

(use-package nerd-icons-completion
  :if (and (display-graphic-p)
           (gnopon/optional-package-available-p 'nerd-icons-completion))
  :after (marginalia nerd-icons)
  :config
  (nerd-icons-completion-mode 1)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))

(gnopon/use-optional-package consult
  :bind
  (("C-s" . consult-line)
   ("C-c s r" . consult-ripgrep)
   ("C-c s b" . consult-buffer)
   ("C-c s i" . consult-imenu)
   ("C-c s o" . consult-outline)
   ("C-c s e" . consult-compile-error)))

(gnopon/use-optional-package embark
  :bind
  (("C-." . embark-act)
   ("C-;" . embark-dwim)
   ("C-h B" . embark-bindings)))

(gnopon/use-optional-package embark-consult
  :after (embark consult)
  :hook (embark-collect-mode . consult-preview-at-point-mode))

(gnopon/use-optional-package corfu
  :demand t
  :custom
  (corfu-auto t)
  (corfu-cycle t)
  (corfu-preview-current nil)
  :config
  (global-corfu-mode 1))

(gnopon/use-optional-package corfu-terminal
  :after corfu
  :if (not (display-graphic-p))
  :config
  (corfu-terminal-mode 1))

(gnopon/use-optional-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev))

(use-package project
  :ensure nil
  :bind-keymap
  ("C-c p" . project-prefix-map)
  :custom
  (project-switch-commands '((project-find-file "Find file")
                             (gnopon/search-project "Search")
                             (project-dired "Dired")
                             (project-eshell "Eshell")
                             (gnopon/git-project-status "Git"))))

(use-package dired
  :ensure nil
  :commands dired
  :custom
  (dired-dwim-target t)
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-listing-switches "-alh --group-directories-first"))

(use-package nerd-icons-dired
  :if (and (display-graphic-p)
           (gnopon/optional-package-available-p 'nerd-icons-dired))
  :hook (dired-mode . nerd-icons-dired-mode))

(gnopon/use-optional-package consult-dir
  :bind
  (("C-x C-d" . consult-dir)
   ("C-x C-j" . consult-dir-jump-file)))

(gnopon/use-optional-package wgrep
  :commands wgrep-change-to-wgrep-mode)

(provide 'gnopon-completion)
;;; gnopon-completion.el ends here
