;;; gnopon-ide.el --- Symbol, diagnostic, and code-action cockpit -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'flymake)
(require 'imenu)
(require 'project)
(require 'thingatpt)
(require 'xref)
(require 'transient)

(defun gnopon/symbol-at-point-string ()
  "Return the symbol at point as a string, or an empty string."
  (string-trim (or (thing-at-point 'symbol t) "")))

(defun gnopon/eglot-active-p ()
  "Return non-nil when the current buffer is managed by Eglot."
  (and (boundp 'eglot--managed-mode)
       (bound-and-true-p eglot--managed-mode)))

(defun gnopon/flymake-diagnostic-counts ()
  "Return an alist of Flymake diagnostic counts for the current buffer."
  (let ((counts '((:error . 0) (:warning . 0) (:note . 0))))
    (when (and (bound-and-true-p flymake-mode)
               (fboundp 'flymake-diagnostics))
      (dolist (diagnostic (flymake-diagnostics (point-min) (point-max)))
        (let* ((type (flymake-diagnostic-type diagnostic))
               (cell (assoc type counts)))
          (when cell
            (setcdr cell (1+ (cdr cell)))))))
    counts))

(defun gnopon/treesit-status ()
  "Return a short tree-sitter parser status string for the current buffer."
  (cond
   ((not (fboundp 'treesit-parser-list)) "unavailable")
   ((treesit-parser-list)
    (mapconcat (lambda (parser)
                 (format "%s" (treesit-parser-language parser)))
               (treesit-parser-list)
               ", "))
   (t "no parser")))

(defun gnopon/code-status ()
  "Open a Markdown status buffer for symbol and IDE state."
  (interactive)
  (let* ((source-buffer (current-buffer))
         (root (file-truename (gnopon/project-root)))
         (symbol (gnopon/symbol-at-point-string))
         (diagnostics (gnopon/flymake-diagnostic-counts))
         (eglot-status (if (gnopon/eglot-active-p) "active" "inactive"))
         (treesit-status (gnopon/treesit-status))
         (source-mode major-mode)
         (buffer (get-buffer-create "*gnopon-code-status*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# Code Status\n\n")
      (insert "- project: `" root "`\n")
      (insert "- buffer: `" (buffer-name source-buffer) "`\n")
      (insert "- major-mode: `" (format "%s" source-mode) "`\n")
      (insert "- symbol: `" symbol "`\n")
      (insert "- eglot: `" eglot-status "`\n")
      (insert "- tree-sitter: `" treesit-status "`\n")
      (insert "- diagnostics: `"
              (format "errors=%s warnings=%s notes=%s"
                      (alist-get :error diagnostics)
                      (alist-get :warning diagnostics)
                      (alist-get :note diagnostics))
              "`\n\n")
      (insert "## Actions\n\n")
      (insert "- `C-c g i s`: symbol index\n")
      (insert "- `C-c g i r`: references\n")
      (insert "- `C-c g i a`: code action\n")
      (insert "- `C-c g i d`: diagnostics\n")
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/find-symbol ()
  "Jump to a symbol in the current buffer."
  (interactive)
  (if (fboundp 'consult-imenu)
      (consult-imenu)
    (imenu (imenu--completion-buffer-index))))

(defun gnopon/find-references ()
  "Find references for the symbol at point."
  (interactive)
  (let ((symbol (gnopon/symbol-at-point-string)))
    (if (string-empty-p symbol)
        (call-interactively #'xref-find-references)
      (xref-find-references symbol))))

(defun gnopon/project-search-symbol ()
  "Search the current project for the symbol at point."
  (interactive)
  (let ((symbol (gnopon/symbol-at-point-string)))
    (gnopon/search-project
     (if (string-empty-p symbol)
         (read-regexp "Project search: ")
       (regexp-quote symbol)))))

(defun gnopon/rename-symbol ()
  "Rename the symbol at point through Eglot or project query-replace."
  (interactive)
  (cond
   ((and (gnopon/eglot-active-p)
         (fboundp 'eglot-rename))
    (call-interactively #'eglot-rename))
   ((fboundp 'project-query-replace-regexp)
    (call-interactively #'project-query-replace-regexp))
   (t
    (user-error "No rename backend available"))))

(defun gnopon/code-action ()
  "Run LSP code actions when Eglot is active."
  (interactive)
  (if (and (gnopon/eglot-active-p)
           (fboundp 'eglot-code-actions))
      (call-interactively #'eglot-code-actions)
    (user-error "No active Eglot code-action backend")))

(defun gnopon/show-diagnostics ()
  "Show diagnostics for the project or current buffer."
  (interactive)
  (cond
   ((fboundp 'flymake-show-project-diagnostics)
    (flymake-show-project-diagnostics))
   ((fboundp 'flymake-show-buffer-diagnostics)
    (flymake-show-buffer-diagnostics))
   (t
    (user-error "Flymake diagnostics UI is unavailable"))))

(defun gnopon/next-diagnostic ()
  "Move to the next diagnostic."
  (interactive)
  (if (fboundp 'flymake-goto-next-error)
      (flymake-goto-next-error)
    (user-error "Flymake is unavailable")))

(defun gnopon/previous-diagnostic ()
  "Move to the previous diagnostic."
  (interactive)
  (if (fboundp 'flymake-goto-prev-error)
      (flymake-goto-prev-error)
    (user-error "Flymake is unavailable")))

(transient-define-prefix gnopon/symbol-actions ()
  "Symbol and code actions for the current buffer."
  [["Navigate"
    ("s" "symbol index" gnopon/find-symbol)
    ("r" "references" gnopon/find-references)
    ("p" "project search" gnopon/project-search-symbol)
    ("." "status" gnopon/code-status)]
   ["Edit"
    ("a" "code action" gnopon/code-action)
    ("R" "rename" gnopon/rename-symbol)
    ("f" "format" gnopon/format-buffer)]
   ["Diagnostics"
    ("d" "show diagnostics" gnopon/show-diagnostics)
    ("n" "next diagnostic" gnopon/next-diagnostic)
    ("N" "previous diagnostic" gnopon/previous-diagnostic)]
   ["Project"
    ("c" "check" gnopon/check-project)
    ("t" "test" gnopon/test-project)
    ("l" "lint" gnopon/lint-project)]])

(define-key gnopon-map (kbd "i") #'gnopon/symbol-actions)

(provide 'gnopon-ide)
;;; gnopon-ide.el ends here
