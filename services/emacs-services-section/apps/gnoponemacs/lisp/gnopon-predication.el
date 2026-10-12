;;; gnopon-predication.el --- Predicated Markdown memory -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)
(require 'gnopon-markdown)
(require 'seq)

(defvar gnopon-predication-directory "docs/predications/"
  "Project-relative directory for predication-cell Markdown notes.")

(defvar gnopon-predication-required-fields
  '(type subject predicate object value evidence-regime evidence-side)
  "Required YAML frontmatter fields for predication-cell notes.")

(defun gnopon/predication-directory ()
  "Return the project-local predication note directory."
  (let ((dir (gnopon/project-file gnopon-predication-directory)))
    (make-directory dir t)
    dir))

(defun gnopon/predication-path (subject predicate object)
  "Return the project-local path for SUBJECT PREDICATE OBJECT."
  (expand-file-name
   (format "%s-%s.md"
           (format-time-string "%Y%m%d")
           (gnopon/markdown-slugify
            (gnopon/predication-cell-title subject predicate object)))
   (gnopon/predication-directory)))

(defun gnopon/predication-template (subject predicate object value regime side)
  "Return a Markdown predication-cell note body."
  (let ((title (gnopon/predication-cell-title subject predicate object)))
    (concat
     (gnopon/predication-frontmatter-string subject predicate object value regime side)
     "# " title "\n\n"
     "## Cell\n\n"
     "- subject: `" subject "`\n"
     "- predicate: `" predicate "`\n"
     "- object: `" object "`\n"
     "- value: `" value "`\n"
     "- evidence-regime: `" regime "`\n"
     "- evidence-side: `" side "`\n\n"
     "## Evidence\n\n"
     "- [ ] source: \n"
     "- [ ] observation: \n\n"
     "## Conflict\n\n"
     "- [ ] conflicting witness: \n"
     "- [ ] reconciliation note: \n\n"
     "## Closure\n\n"
     "- [ ] `depends-on` edges resolve.\n"
     "- [ ] Evidence can be inspected without private context.\n"
     "- [ ] Current value is still justified after review.\n\n"
     "## Agent Notes\n\n")))

(defun gnopon/insert-predication-cell (subject predicate object value regime side)
  "Insert a Markdown predication-cell note at point."
  (interactive
   (list (read-string "Subject: ")
         (read-string "Predicate: ")
         (read-string "Object: ")
         (completing-read "Value: " gnopon/predication-values nil t nil nil "potential")
         (completing-read "Regime: " gnopon-evidence-regimes nil t nil nil "strict")
         (completing-read "Side: " gnopon-evidence-sides nil t nil nil "knowledge")))
  (insert (gnopon/predication-template subject predicate object value regime side)))

(defun gnopon/create-predication-cell (subject predicate object value regime side)
  "Create a project-local Markdown predication cell."
  (interactive
   (list (read-string "Subject: ")
         (read-string "Predicate: ")
         (read-string "Object: ")
         (completing-read "Value: " gnopon/predication-values nil t nil nil "potential")
         (completing-read "Regime: " gnopon-evidence-regimes nil t nil nil "strict")
         (completing-read "Side: " gnopon-evidence-sides nil t nil nil "knowledge")))
  (let ((path (gnopon/predication-path subject predicate object)))
    (find-file path)
    (when (= (point-min) (point-max))
      (insert (gnopon/predication-template subject predicate object value regime side)))))

(defun gnopon/predication-files ()
  "Return project predication-cell Markdown files."
  (let ((dir (gnopon/predication-directory)))
    (if (file-directory-p dir)
        (seq-remove
         (lambda (file)
           (string= (file-name-nondirectory file) "README.md"))
         (directory-files-recursively dir "\\.md\\'"))
      nil)))

(defun gnopon/predication-file-issues (file)
  "Return validation issues for predication-cell FILE."
  (let* ((text (with-temp-buffer
                 (insert-file-contents file)
                 (buffer-string)))
         (frontmatter (gnopon/markdown-frontmatter-alist text))
         (issues nil))
    (dolist (field gnopon-predication-required-fields)
      (unless (alist-get field frontmatter)
        (push (format "missing `%s`" field) issues)))
    (let ((type (alist-get 'type frontmatter))
          (value (alist-get 'value frontmatter))
          (regime (alist-get 'evidence-regime frontmatter))
          (side (alist-get 'evidence-side frontmatter)))
      (unless (equal type "predication-cell")
        (push "type is not `predication-cell`" issues))
      (unless (or (null value) (member value gnopon/predication-values))
        (push (format "unknown value `%s`" value) issues))
      (unless (or (null regime) (member regime gnopon-evidence-regimes))
        (push (format "unknown evidence-regime `%s`" regime) issues))
      (unless (or (null side) (member side gnopon-evidence-sides))
        (push (format "unknown evidence-side `%s`" side) issues)))
    (nreverse issues)))

(defun gnopon/predication-index ()
  "Open a generated index of project predication cells."
  (interactive)
  (let ((buffer (get-buffer-create "*predications*"))
        (root (file-truename (gnopon/project-root)))
        (files (gnopon/predication-files)))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# Predication Cells\n\n")
      (insert "- project: `" root "`\n")
      (insert "- count: `" (number-to-string (length files)) "`\n\n")
      (dolist (file files)
        (let* ((relative (file-relative-name file root))
               (issues (gnopon/predication-file-issues file)))
          (insert (if issues "- [ ] " "- [x] ")
                  "`" relative "`")
          (when issues
            (insert " - " (string-join issues "; ")))
          (insert "\n")))
      (insert "\n## Search Hints\n\n")
      (insert "- `type: predication-cell`\n")
      (insert "- `value: both` for paraconsistent conflict.\n")
      (insert "- `evidence-side: gap` for work needing witness.\n")
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(defun gnopon/search-predications ()
  "Search project predication cells."
  (interactive)
  (gnopon/search-project
   "type: predication-cell\\|subject:\\|predicate:\\|object:\\|value:\\|evidence-side:\\|depends-on:"
   (gnopon/predication-directory)))

(defun gnopon/validate-predications ()
  "Open a Markdown validation report for project predication cells."
  (interactive)
  (let ((buffer (get-buffer-create "*predication-validation*"))
        (root (file-truename (gnopon/project-root)))
        (files (gnopon/predication-files))
        (issue-count 0))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# Predication Validation\n\n")
      (insert "- project: `" root "`\n")
      (insert "- cells: `" (number-to-string (length files)) "`\n\n")
      (insert "## Allowed Values\n\n")
      (insert "- values: `" (string-join gnopon/predication-values "`, `") "`\n")
      (insert "- regimes: `" (string-join gnopon-evidence-regimes "`, `") "`\n")
      (insert "- sides: `" (string-join gnopon-evidence-sides "`, `") "`\n\n")
      (insert "## Files\n\n")
      (dolist (file files)
        (let ((issues (gnopon/predication-file-issues file)))
          (setq issue-count (+ issue-count (length issues)))
          (insert (if issues "- [ ] " "- [x] ")
                  "`" (file-relative-name file root) "`")
          (when issues
            (insert " - " (string-join issues "; ")))
          (insert "\n")))
      (insert "\n## Result\n\n")
      (insert (if (zerop issue-count)
                  "No predication validation issues found.\n"
                (format "%s predication validation issue(s) found.\n" issue-count)))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(define-key gnopon-map (kbd "m p") #'gnopon/create-predication-cell)
(define-key gnopon-map (kbd "m P") #'gnopon/insert-predication-cell)
(define-key gnopon-map (kbd "m I") #'gnopon/predication-index)
(define-key gnopon-map (kbd "m /") #'gnopon/search-predications)
(define-key gnopon-map (kbd "m V") #'gnopon/validate-predications)

(provide 'gnopon-predication)
;;; gnopon-predication.el ends here
