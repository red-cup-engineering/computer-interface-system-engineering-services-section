;;; gnopon-programming.el --- Rust, Node, and engineering workflow -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'json)
(require 'seq)

(use-package treesit
  :ensure nil
  :custom
  (treesit-font-lock-level 4)
  (treesit-language-source-alist
   '((bash "https://github.com/tree-sitter/tree-sitter-bash")
     (css "https://github.com/tree-sitter/tree-sitter-css")
     (html "https://github.com/tree-sitter/tree-sitter-html")
     (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
     (json "https://github.com/tree-sitter/tree-sitter-json")
     (python "https://github.com/tree-sitter/tree-sitter-python")
     (rust "https://github.com/tree-sitter/tree-sitter-rust")
     (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript")
     (yaml "https://github.com/ikatyang/tree-sitter-yaml"))))

(use-package treesit-auto
  :if (gnopon/optional-package-available-p 'treesit-auto)
  :custom
  (treesit-auto-install 'prompt)
  :config
  (global-treesit-auto-mode 1))

(use-package eglot
  :ensure nil
  :commands (eglot eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-confirm-server-initiated-edits nil))

(defun gnopon/maybe-eglot ()
  "Start Eglot when `gnopon-enable-eglot-auto' is non-nil."
  (when gnopon-enable-eglot-auto
    (eglot-ensure)))

(dolist (hook '(rust-mode-hook rust-ts-mode-hook
                js-mode-hook js-ts-mode-hook typescript-ts-mode-hook
                sh-mode-hook bash-ts-mode-hook python-mode-hook python-ts-mode-hook))
  (add-hook hook #'gnopon/maybe-eglot))

(use-package flymake
  :ensure nil
  :hook (prog-mode . flymake-mode)
  :bind
  (("M-n" . flymake-goto-next-error)
   ("M-p" . flymake-goto-prev-error)))

(use-package compile
  :ensure nil
  :custom
  (compilation-scroll-output 'first-error)
  (compilation-always-kill t))

(use-package envrc
  :if (and (executable-find "direnv")
           (gnopon/optional-package-available-p 'envrc))
  :config
  (envrc-global-mode 1))

(use-package apheleia
  :if (gnopon/optional-package-available-p 'apheleia)
  :demand t
  :config
  (apheleia-global-mode 1))

(use-package dape
  :if (gnopon/optional-package-available-p 'dape)
  :commands (dape dape-info dape-repl)
  :custom
  (dape-buffer-window-arrangement 'right))

(defun gnopon/project-has-file-p (name)
  "Return non-nil when current project has NAME."
  (file-exists-p (expand-file-name name (gnopon/project-root))))

(defun gnopon/package-json-scripts ()
  "Return package.json script names for the current project."
  (let ((package-json (gnopon/project-file "package.json")))
    (when (file-readable-p package-json)
      (with-temp-buffer
        (insert-file-contents package-json)
        (let-alist (json-parse-buffer :object-type 'alist)
          (when .scripts
            (mapcar (lambda (key)
                      (if (symbolp key) (symbol-name key) key))
                    (mapcar #'car .scripts))))))))

(defun gnopon/package-manager ()
  "Return the likely Node package manager command."
  (cond
   ((gnopon/project-has-file-p "pnpm-lock.yaml") "pnpm")
   ((gnopon/project-has-file-p "yarn.lock") "yarn")
   ((gnopon/project-has-file-p "bun.lockb") "bun")
   ((gnopon/project-has-file-p "package-lock.json") "npm")
   ((gnopon/project-has-file-p "package.json") "npm")
   (t nil)))

(defun gnopon/command-candidate (kind label command source)
  "Return a project command candidate alist."
  `((kind . ,kind)
    (label . ,label)
    (command . ,command)
    (source . ,source)))

(defun gnopon/package-script-command-candidates ()
  "Return command candidates derived from package.json scripts."
  (when-let ((manager (gnopon/package-manager)))
    (mapcar (lambda (script)
              (gnopon/command-candidate
               (intern (if (member script '("test" "check" "lint" "build" "dev" "start" "format"))
                           script
                         "script"))
               (format "package:%s" script)
               (format "%s run %s" manager script)
               "package.json"))
            (or (gnopon/package-json-scripts) nil))))

(defun gnopon/cargo-command-candidates ()
  "Return command candidates for Rust projects."
  (when (gnopon/project-has-file-p "Cargo.toml")
    (list
     (gnopon/command-candidate 'check "cargo:check" "cargo check" "Cargo.toml")
     (gnopon/command-candidate 'test "cargo:test" "cargo test" "Cargo.toml")
     (gnopon/command-candidate 'lint "cargo:clippy" "cargo clippy --all-targets --all-features" "Cargo.toml")
     (gnopon/command-candidate 'format "cargo:fmt" "cargo fmt" "Cargo.toml")
     (gnopon/command-candidate 'build "cargo:build" "cargo build" "Cargo.toml")
     (gnopon/command-candidate 'run "cargo:run" "cargo run" "Cargo.toml"))))

(defun gnopon/make-command-candidates ()
  "Return command candidates for projects with Makefiles."
  (when (or (gnopon/project-has-file-p "Makefile")
            (gnopon/project-has-file-p "makefile"))
    (list
     (gnopon/command-candidate 'build "make:build" "make build" "Makefile")
     (gnopon/command-candidate 'test "make:test" "make test" "Makefile")
     (gnopon/command-candidate 'check "make:check" "make check" "Makefile")
     (gnopon/command-candidate 'lint "make:lint" "make lint" "Makefile"))))

(defun gnopon/project-command-candidates ()
  "Return known project command candidates for the current project."
  (append (gnopon/cargo-command-candidates)
          (gnopon/package-script-command-candidates)
          (gnopon/make-command-candidates)))

(defun gnopon/project-command-candidate-label (candidate)
  "Return a completion label for command CANDIDATE."
  (format "%s [%s] - %s"
          (alist-get 'label candidate)
          (alist-get 'kind candidate)
          (alist-get 'command candidate)))

(defun gnopon/project-command-matrix-text ()
  "Return a Markdown matrix of detected project commands."
  (let* ((root (file-truename (gnopon/project-root)))
         (manager (or (gnopon/package-manager) "none"))
         (candidates (gnopon/project-command-candidates)))
    (concat "# Project Command Matrix\n\n"
            "- project: `" root "`\n"
            "- package-manager: `" manager "`\n"
            "- cargo: `" (if (gnopon/project-has-file-p "Cargo.toml") "present" "absent") "`\n"
            "- makefile: `" (if (or (gnopon/project-has-file-p "Makefile")
                                     (gnopon/project-has-file-p "makefile"))
                                "present"
                              "absent")
            "`\n"
            "- commands: `" (number-to-string (length candidates)) "`\n\n"
            "| Kind | Label | Command | Source |\n"
            "|---|---|---|---|\n"
            (if candidates
                (mapconcat (lambda (candidate)
                             (format "| `%s` | `%s` | `%s` | `%s` |\n"
                                     (alist-get 'kind candidate)
                                     (alist-get 'label candidate)
                                     (alist-get 'command candidate)
                                     (alist-get 'source candidate)))
                           candidates
                           "")
              "| `none` | `none` | `none` | `no known command files` |\n")
            "\n## Run\n\n"
            "- run candidate: `C-c g p r`\n"
            "- package script picker: `C-c g p n`\n"
            "- safe command runner: `C-c g s c`\n")))

(defun gnopon/project-command-matrix ()
  "Open a read-only project command matrix."
  (interactive)
  (let ((buffer (get-buffer-create "*project-command-matrix*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert (gnopon/project-command-matrix-text))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/run-project-command-candidate (label)
  "Run a detected project command selected by LABEL."
  (interactive
   (let* ((candidates (gnopon/project-command-candidates))
          (labels (mapcar #'gnopon/project-command-candidate-label candidates)))
     (unless candidates
       (user-error "No project command candidates detected"))
     (list (completing-read "Command: " labels nil t))))
  (let* ((candidates (gnopon/project-command-candidates))
         (candidate (seq-find (lambda (item)
                                (string= label (gnopon/project-command-candidate-label item)))
                              candidates)))
    (unless candidate
      (user-error "Unknown project command candidate: %s" label))
    (gnopon/compile-in-project (alist-get 'command candidate))))

(defun gnopon/compile-in-project (command)
  "Run compile COMMAND from the current project root."
  (interactive "sCommand: ")
  (let ((default-directory (gnopon/project-root)))
    (compile command)))

(defun gnopon/test-project ()
  "Run the most likely test command for the current project."
  (interactive)
  (let* ((root (gnopon/project-root))
         (default-directory root)
         (command (cond
                   ((file-exists-p (expand-file-name "Cargo.toml" root)) "cargo test")
                   ((file-exists-p (expand-file-name "pnpm-lock.yaml" root)) "pnpm test")
                   ((file-exists-p (expand-file-name "bun.lockb" root)) "bun test")
                   ((file-exists-p (expand-file-name "yarn.lock" root)) "yarn test")
                   ((file-exists-p (expand-file-name "package-lock.json" root)) "npm test")
                   ((file-exists-p (expand-file-name "package.json" root)) "npm test")
                   (t (read-shell-command "Test command: ")))))
    (compile command)))

(defun gnopon/check-project ()
  "Run the most likely check command for the current project."
  (interactive)
  (let* ((root (gnopon/project-root))
         (default-directory root)
         (command (cond
                   ((file-exists-p (expand-file-name "Cargo.toml" root)) "cargo check")
                   ((file-exists-p (expand-file-name "pnpm-lock.yaml" root)) "pnpm run check")
                   ((file-exists-p (expand-file-name "bun.lockb" root)) "bun run check")
                   ((file-exists-p (expand-file-name "yarn.lock" root)) "yarn check")
                   ((file-exists-p (expand-file-name "package.json" root)) "npm run check")
                   (t (read-shell-command "Check command: ")))))
    (compile command)))

(defun gnopon/lint-project ()
  "Run the most likely lint command for the current project."
  (interactive)
  (let* ((root (gnopon/project-root))
         (default-directory root)
         (command (cond
                   ((file-exists-p (expand-file-name "Cargo.toml" root)) "cargo clippy --all-targets --all-features")
                   ((member "lint" (gnopon/package-json-scripts))
                    (format "%s run lint" (gnopon/package-manager)))
                   (t (read-shell-command "Lint command: ")))))
    (compile command)))

(defun gnopon/format-buffer ()
  "Format the current buffer through Eglot or Apheleia."
  (interactive)
  (cond
   ((and (bound-and-true-p eglot--managed-mode)
         (fboundp 'eglot-format-buffer))
    (eglot-format-buffer))
   ((fboundp 'apheleia-format-buffer)
    (apheleia-format-buffer))
   (t
    (indent-region (point-min) (point-max)))))

(defun gnopon/run-package-script (script)
  "Run package.json SCRIPT in the current project."
  (interactive
   (list (completing-read "Script: " (gnopon/package-json-scripts) nil t)))
  (unless (gnopon/package-manager)
    (user-error "No package manager detected"))
  (gnopon/compile-in-project (format "%s run %s" (gnopon/package-manager) script)))

(defun gnopon/debug-project ()
  "Start a debugger session using Dape."
  (interactive)
  (if (fboundp 'dape)
      (call-interactively #'dape)
    (user-error "Dape is not installed; install the package closure to use debugger integration")))

(gnopon/use-optional-package rust-mode
  :mode ("\\.rs\\'" . rust-mode)
  :custom
  (rust-format-on-save t))

(gnopon/use-optional-package fennel-mode
  :mode ("\\.fnl\\'" . fennel-mode))

(gnopon/use-optional-package typescript-mode
  :mode ("\\.ts\\'" "\\.tsx\\'")
  :custom
  (typescript-indent-level 2))

(gnopon/use-optional-package json-mode
  :mode ("\\.json\\'" . json-mode))

(gnopon/use-optional-package yaml-mode
  :mode ("\\.ya?ml\\'" . yaml-mode))

(gnopon/use-optional-package nix-mode
  :mode "\\.nix\\'")

(gnopon/use-optional-package dockerfile-mode
  :mode "Dockerfile\\'")

(define-key gnopon-map (kbd "p l") #'eglot)
(define-key gnopon-map (kbd "p c") #'gnopon/check-project)
(define-key gnopon-map (kbd "p t") #'gnopon/test-project)
(define-key gnopon-map (kbd "p x") #'gnopon/compile-in-project)
(define-key gnopon-map (kbd "p n") #'gnopon/run-package-script)
(define-key gnopon-map (kbd "p m") #'gnopon/project-command-matrix)
(define-key gnopon-map (kbd "p r") #'gnopon/run-project-command-candidate)
(define-key gnopon-map (kbd "p i") #'gnopon/lint-project)
(define-key gnopon-map (kbd "p f") #'gnopon/format-buffer)
(define-key gnopon-map (kbd "p d") #'gnopon/debug-project)

(provide 'gnopon-programming)
;;; gnopon-programming.el ends here
