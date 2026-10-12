;;; gnopon-core.el --- Core GnoponEmacs kernel -*- lexical-binding: t; -*-

;;; Code:

(require 'package)
(require 'seq)
(require 'subr-x)
(require 'gnopon-lib)

(defgroup gnopon nil
  "Markdown-native engineering cockpit."
  :group 'convenience)

(defcustom gnopon-enable-eglot-auto nil
  "When non-nil, start Eglot automatically in supported programming buffers."
  :type 'boolean
  :group 'gnopon)

(defcustom gnopon-agent-command "codex"
  "Default project-scoped agent command."
  :type 'string
  :group 'gnopon)

(defvar gnopon-start-time (current-time)
  "Time when GnoponEmacs started loading.")

(defcustom gnopon-state-dir
  (expand-file-name "gnoponemacs/" user-emacs-directory)
  "Directory containing GnoponEmacs-generated state and local settings.

This is intentionally separate from Emacs's general state: the application can
be started, inspected, and removed without claiming another Emacs setup's
recent files, package directory, or customization file."
  :type 'directory
  :group 'gnopon)

(defcustom gnopon-legacy-state-dir
  (expand-file-name "var/" user-emacs-directory)
  "Former shared state directory, retained only as an explicit import source.
`gnopon/import-legacy-state' copies missing data from this location; loading
GnoponEmacs never reads it implicitly."
  :type 'directory
  :group 'gnopon)

(defvar gnopon-map (make-sparse-keymap)
  "Prefix map for GnoponEmacs cockpit commands.")

(define-key global-map (kbd "C-c g") gnopon-map)
(define-key global-map (kbd "M-SPC") gnopon-map)

(defvar gnopon-package-manifest
  '(ace-window
    apheleia
    auto-dark
    avy
    beancount
    cape
    consult
    consult-dir
    corfu
    corfu-terminal
    dape
    diff-hl
    diminish
    dockerfile-mode
    doom-modeline
    eat
    embark
    embark-consult
    envrc
    expand-region
    fennel-mode
    forge
    gptel
    helpful
    htmlize
    jq-mode
    json-mode
    magit
    markdown-mode
    markdown-toc
    mixed-pitch
    modus-themes
    multiple-cursors
    nerd-icons
    nerd-icons-completion
    nerd-icons-dired
    nix-mode
    no-littering
    ob-crystal
    orderless
    org-drill
    org-modern
    org-roam
    org-roam-ui
    org-transclusion
    olivetti
    ox-gfm
    ox-hugo
    paredit
    popper
    restclient
    rust-mode
    transient
    treesit-auto
    typescript-mode
    vertico
    visual-fill-column
    which-key
    webpaste
    writegood-mode
    yaml-mode
    yasnippet
    yasnippet-snippets
    wgrep)
  "Third-party packages expected by GnoponEmacs.")

(defun gnopon/path (&rest segments)
  "Return a path under `gnopon-state-dir' from SEGMENTS."
  (expand-file-name (mapconcat #'identity segments "/") gnopon-state-dir))

(defun gnopon/ensure-directory (directory)
  "Create DIRECTORY and return it."
  (make-directory directory t)
  directory)

(defun gnopon/import-legacy-state ()
  "Copy missing legacy GnoponEmacs state into `gnopon-state-dir'.
Existing destination files are never replaced.  This is a one-time data import,
not a compatibility path: subsequent sessions use only the application state
directory."
  (interactive)
  (unless (file-directory-p gnopon-legacy-state-dir)
    (user-error "gnopon: legacy state directory does not exist: %s"
                gnopon-legacy-state-dir))
  (let ((source (file-name-as-directory (expand-file-name gnopon-legacy-state-dir)))
        (target (file-name-as-directory (expand-file-name gnopon-state-dir)))
        (copied 0))
    (dolist (path (directory-files-recursively source "."))
      (unless (file-directory-p path)
        (let ((destination (expand-file-name (file-relative-name path source) target)))
          (unless (file-exists-p destination)
            (make-directory (file-name-directory destination) t)
            (copy-file path destination)
            (setq copied (1+ copied))))))
    (message "gnopon: imported %d legacy state file%s" copied
             (if (= copied 1) "" "s"))))

(defun gnopon/project-root ()
  "Return the active project root or `default-directory'."
  (if-let ((project (project-current nil)))
      (project-root project)
    default-directory))

(defun gnopon/project-file (name)
  "Return project-local file NAME."
  (expand-file-name name (gnopon/project-root)))

(defun gnopon/report-startup ()
  "Report approximate startup time."
  (interactive)
  (message "GnoponEmacs loaded in %.3fs with %d garbage collections"
           (float-time (time-subtract (current-time) gnopon-start-time))
           gcs-done))

(defun gnopon/loaded-module-features ()
  "Return loaded GnoponEmacs feature names."
  (sort
   (mapcar #'symbol-name
           (seq-filter (lambda (feature)
                         (string-prefix-p "gnopon-" (symbol-name feature)))
                       features))
   #'string<))

(defun gnopon/performance-report-text ()
  "Return a Markdown runtime performance and startup report."
  (let* ((startup-seconds (float-time (time-subtract (current-time) gnopon-start-time)))
         (modules (gnopon/loaded-module-features)))
    (concat "# GnoponEmacs Performance Report\n\n"
            "- project: `" (file-truename (gnopon/project-root)) "`\n"
            "- generated: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n"
            "- startup-seconds: `" (format "%.3f" startup-seconds) "`\n"
            "- garbage-collections: `" (number-to-string gcs-done) "`\n"
            "- gc-cons-threshold: `" (number-to-string gc-cons-threshold) "`\n"
            "- read-process-output-max: `" (number-to-string read-process-output-max) "`\n"
            "- package-quickstart: `" (format "%s" package-quickstart) "`\n"
            "- package-count: `" (number-to-string (length gnopon-package-manifest)) "`\n"
            "- loaded-gnopon-modules: `" (number-to-string (length modules)) "`\n"
            "- native-comp: `" (if (fboundp 'native-comp-available-p)
                                   (format "%s" (native-comp-available-p))
                                 "unavailable")
            "`\n"
            "- state-dir: `" gnopon-state-dir "`\n"
            "- package-dir: `" package-user-dir "`\n\n"
            "## Loaded Modules\n\n"
            (if modules
                (mapconcat (lambda (module) (format "- `%s`\n" module)) modules "")
              "- none\n")
            "\n## External Benchmark\n\n"
            "- no-network startup benchmark: `pnpm --dir apps/gnoponemacs benchmark -- --iterations 5 --json`\n"
            "- package verifier: `pnpm --dir apps/gnoponemacs test`\n"
            "- reproducibility verifier: `pnpm --dir apps/gnoponemacs repro -- --require-tools`\n")))

(defun gnopon/performance-report ()
  "Open a read-only GnoponEmacs performance report."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-performance*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/performance-report-text))
      (when (fboundp 'gnopon/markdown-buffer-mode)
        (gnopon/markdown-buffer-mode))
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/performance-report-path ()
  "Return a project-local performance report path."
  (let ((dir (gnopon/project-file "logs/performance/")))
    (make-directory dir t)
    (expand-file-name
     (format "%s-performance.md" (format-time-string "%Y%m%d-%H%M%S"))
     dir)))

(defun gnopon/write-performance-report ()
  "Write a GnoponEmacs performance report under `logs/performance/'."
  (interactive)
  (let ((path (gnopon/performance-report-path)))
    (with-temp-file path
      (insert (gnopon/performance-report-text)))
    (find-file path)
    path))

(defun gnopon/open-module ()
  "Open a GnoponEmacs module."
  (interactive)
  (let* ((module-dir (expand-file-name "lisp/" gnopon/root))
         (file (completing-read "Module: " (directory-files module-dir nil "\\.el\\'") nil t)))
    (find-file (expand-file-name file module-dir))))

(dolist (directory '("" "auto-save" "backup" "eln-cache" "packages"))
  (make-directory (gnopon/path directory) t))

(setq custom-file (gnopon/path "local.el")
      package-user-dir (gnopon/path "packages/elpa/")
      package-selected-packages gnopon-package-manifest
      package-quickstart nil
      package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ("melpa" . "https://melpa.org/packages/")))

(package-initialize)

(unless (require 'use-package nil t)
  (unless (package-installed-p 'use-package)
    (package-refresh-contents)
    (package-install 'use-package)))

(eval-when-compile
  (require 'use-package))
(require 'use-package)

(setq use-package-always-ensure nil
      use-package-always-defer t
      use-package-expand-minimally t
      use-package-enable-imenu-support t)

(defun gnopon/optional-package-available-p (package)
  "Return non-nil when optional PACKAGE is available on `load-path'."
  (locate-library (symbol-name package)))

(defmacro gnopon/use-optional-package (name &rest args)
  "Declare optional package NAME with `use-package' and ARGS.
The declaration is skipped when NAME is not available, so package absence does
not abort GnoponEmacs startup."
  (declare (indent defun))
  `(use-package ,name
     :if (gnopon/optional-package-available-p ',name)
     ,@args))

(use-package no-littering
  :if (gnopon/optional-package-available-p 'no-littering)
  :demand t
  :custom
  (no-littering-etc-directory (gnopon/path "etc/"))
  (no-littering-var-directory (gnopon/path "no-littering/")))

(use-package diminish
  :if (gnopon/optional-package-available-p 'diminish))

(unless (require 'transient nil t)
  (defmacro transient-define-prefix (name args &optional docstring &rest _body)
    "Define NAME as a non-fatal fallback command when transient is absent.
ARGS and DOCSTRING follow `defun'.  The transient body is ignored so modules can
still load before the optional `transient' package is installed."
    `(defun ,name ,args
       ,(or docstring "Fallback command for a missing transient menu.")
       (interactive)
       (message "GnoponEmacs: transient is unavailable; use direct C-c g keys or install the package closure.")))
  (provide 'transient))

(use-package emacs
  :ensure nil
  :defer nil
  :custom
  (ad-redefinition-action 'accept)
  (auto-save-default t)
  (backup-by-copying t)
  (create-lockfiles nil)
  (delete-by-moving-to-trash t)
  (enable-recursive-minibuffers t)
  (fill-column 88)
  (global-auto-revert-non-file-buffers t)
  (help-window-select t)
  (history-length 300)
  (indent-tabs-mode nil)
  (large-file-warning-threshold (* 100 1024 1024))
  (mouse-wheel-scroll-amount '(1 ((shift) .1)))
  (require-final-newline t)
  (read-answer-short t)
  (read-buffer-completion-ignore-case t)
  (read-file-name-completion-ignore-case t)
  (read-process-output-max (* 1024 1024))
  (sentence-end-double-space nil)
  (tab-always-indent 'complete)
  (use-dialog-box nil)
  (use-short-answers t)
  :config
  (setq-default tab-width 2)
  (setq completion-ignore-case t
        completion-cycle-threshold 3
        echo-keystrokes 0.1
        ring-bell-function #'ignore
        scroll-conservatively 101
        scroll-margin 3)
  (set-language-environment "UTF-8")
  (prefer-coding-system 'utf-8-unix)
  (global-auto-revert-mode 1)
  (global-display-line-numbers-mode 1)
  (column-number-mode 1)
  (delete-selection-mode 1)
  (electric-indent-mode 1)
  (electric-pair-mode 1)
  (show-paren-mode 1)
  (when (fboundp 'menu-bar-mode) (menu-bar-mode -1))
  (when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
  (when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
  (when (fboundp 'blink-cursor-mode) (blink-cursor-mode -1))
  (repeat-mode 1)
  (define-key global-map (kbd "C-c g") gnopon-map)
  (define-key global-map (kbd "M-SPC") gnopon-map)
  (define-key gnopon-map (kbd "d s") #'gnopon/report-startup)
  (define-key gnopon-map (kbd "d p") #'gnopon/performance-report)
  (define-key gnopon-map (kbd "d P") #'gnopon/write-performance-report)
  (define-key gnopon-map (kbd "d m") #'gnopon/open-module))

(defun gnopon/search-project (pattern &optional directory)
  "Search DIRECTORY for PATTERN using the best available project search backend."
  (interactive (list (read-regexp "Search project: ")))
  (let ((root (file-name-as-directory (or directory (gnopon/project-root)))))
    (cond
     ((fboundp 'consult-ripgrep)
      (consult-ripgrep root pattern))
     ((fboundp 'project-find-regexp)
      (let ((default-directory root))
        (project-find-regexp pattern)))
     ((fboundp 'rgrep)
      (rgrep pattern "*" root))
     (t
      (user-error "No project search backend available")))))

(defun gnopon/switch-buffer ()
  "Switch buffers through Consult when available, otherwise use built-in completion."
  (interactive)
  (if (fboundp 'consult-buffer)
      (consult-buffer)
    (switch-to-buffer (read-buffer "Buffer: " (other-buffer)))))

(when (file-readable-p custom-file)
  (load custom-file nil 'nomessage))

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024)
                  gc-cons-percentage 0.1)
            (gnopon/report-startup)))

(provide 'gnopon-core)
;;; gnopon-core.el ends here
