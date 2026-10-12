;;; gnopon-formal.el --- RDF, SHACL, and proof obligations -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)
(require 'gnopon-markdown)
(require 'gnopon-predication)
(require 'transient)

(defvar gnopon-formal-directory "docs/formal/"
  "Project-relative directory for formal validation exports.")

(defun gnopon/formal-directory ()
  "Return the project-local formal validation directory."
  (let ((dir (gnopon/project-file gnopon-formal-directory)))
    (make-directory dir t)
    dir))

(defun gnopon/formal-path (name)
  "Return project-local formal artifact path NAME."
  (expand-file-name name (gnopon/formal-directory)))

(defun gnopon/formal-read-frontmatter (file)
  "Return parsed frontmatter from Markdown FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (gnopon/markdown-frontmatter-alist (buffer-string))))

(defun gnopon/formal-frontmatter-value (frontmatter key)
  "Return unquoted FRONTMATTER scalar KEY."
  (gnopon/yaml-scalar-unquote (or (alist-get key frontmatter) "")))

(defun gnopon/formal-shacl-template ()
  "Return a conservative SHACL/Turtle schema for predication cells."
  (concat
   "@prefix g: <https://561.group/ns/gnopon#> .\n"
   "@prefix sh: <http://www.w3.org/ns/shacl#> .\n"
   "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n\n"
   "g:PredicationCellShape a sh:NodeShape ;\n"
   "  sh:targetClass g:PredicationCell ;\n"
   "  sh:property [ sh:path g:subject ; sh:minCount 1 ; sh:datatype xsd:string ] ;\n"
   "  sh:property [ sh:path g:predicate ; sh:minCount 1 ; sh:datatype xsd:string ] ;\n"
   "  sh:property [ sh:path g:object ; sh:minCount 1 ; sh:datatype xsd:string ] ;\n"
   "  sh:property [ sh:path g:value ; sh:minCount 1 ; sh:in (g:present g:absent g:both g:neither g:potential) ] ;\n"
   "  sh:property [ sh:path g:evidenceRegime ; sh:minCount 1 ; sh:in (g:strict g:scott_continuous g:transfinite_bounded g:aperiodic) ] ;\n"
   "  sh:property [ sh:path g:evidenceSide ; sh:minCount 1 ; sh:in (g:truth g:knowledge g:conflict g:gap) ] .\n"))

(defun gnopon/formal-write-shacl-schema ()
  "Write the predication-cell SHACL schema under `docs/formal/'."
  (interactive)
  (let ((path (gnopon/formal-path "schema.ttl")))
    (with-temp-file path
      (insert (gnopon/formal-shacl-template)))
    (when (called-interactively-p 'interactive)
      (find-file path))
    path))

(defun gnopon/formal-predication-turtle (file root)
  "Return Turtle triples for predication-cell FILE under ROOT."
  (let* ((frontmatter (gnopon/formal-read-frontmatter file))
         (relative (file-relative-name file root))
         (subject (gnopon/formal-frontmatter-value frontmatter 'subject))
         (predicate (gnopon/formal-frontmatter-value frontmatter 'predicate))
         (object (gnopon/formal-frontmatter-value frontmatter 'object))
         (value (gnopon/formal-frontmatter-value frontmatter 'value))
         (regime (gnopon/formal-frontmatter-value frontmatter 'evidence-regime))
         (side (gnopon/formal-frontmatter-value frontmatter 'evidence-side))
         (node (concat "cell_" (gnopon/turtle-local-name relative))))
    (format (concat "g:%s a g:PredicationCell ;\n"
                    "  g:sourcePath %s ;\n"
                    "  g:subject %s ;\n"
                    "  g:predicate %s ;\n"
                    "  g:object %s ;\n"
                    "  g:value g:%s ;\n"
                    "  g:evidenceRegime g:%s ;\n"
                    "  g:evidenceSide g:%s .\n")
            node
            (gnopon/turtle-string relative)
            (gnopon/turtle-string subject)
            (gnopon/turtle-string predicate)
            (gnopon/turtle-string object)
            (gnopon/turtle-local-name value)
            (gnopon/turtle-local-name regime)
            (gnopon/turtle-local-name side))))

(defun gnopon/formal-predications-turtle ()
  "Return Turtle export for project predication cells."
  (let* ((root (file-truename (gnopon/project-root)))
         (files (gnopon/predication-files)))
    (concat
     "@prefix g: <https://561.group/ns/gnopon#> .\n\n"
     (if files
         (mapconcat (lambda (file)
                      (gnopon/formal-predication-turtle file root))
                    files
                    "\n")
       "# No predication cells found.\n"))))

(defun gnopon/formal-write-rdf ()
  "Write Turtle RDF export for project predication cells."
  (interactive)
  (let ((path (gnopon/formal-path "predications.ttl")))
    (with-temp-file path
      (insert (gnopon/formal-predications-turtle)))
    (when (called-interactively-p 'interactive)
      (find-file path))
    path))

(defun gnopon/formal-proof-obligation-section (file root)
  "Return Markdown proof obligations for predication-cell FILE under ROOT."
  (let* ((frontmatter (gnopon/formal-read-frontmatter file))
         (relative (file-relative-name file root))
         (title (or (alist-get 'title frontmatter) relative))
         (value (gnopon/formal-frontmatter-value frontmatter 'value))
         (regime (gnopon/formal-frontmatter-value frontmatter 'evidence-regime))
         (side (gnopon/formal-frontmatter-value frontmatter 'evidence-side))
         (issues (gnopon/predication-file-issues file)))
    (concat "## " (gnopon/yaml-scalar-unquote title) "\n\n"
            "- source: `" relative "`\n"
            "- value: `" value "`\n"
            "- evidence-regime: `" regime "`\n"
            "- evidence-side: `" side "`\n"
            "- validation: " (if issues (string-join issues "; ") "frontmatter ok") "\n\n"
            "- [ ] Evidence block names an inspectable source.\n"
            "- [ ] `depends-on` edges have been reviewed.\n"
            "- [ ] Conflict/gap labels are intentional when present.\n"
            "- [ ] Current value remains justified after latest project diff.\n\n")))

(defun gnopon/formal-proof-obligations-text ()
  "Return Markdown proof obligations for project predication cells."
  (let* ((root (file-truename (gnopon/project-root)))
         (files (gnopon/predication-files)))
    (concat "# Proof Obligations\n\n"
            "- project: `" root "`\n"
            "- generated: " (format-time-string "%Y-%m-%d %H:%M:%S") "\n\n"
            (if files
                (mapconcat (lambda (file)
                             (gnopon/formal-proof-obligation-section file root))
                           files
                           "")
              "_No predication cells found._\n"))))

(defun gnopon/formal-write-proof-obligations ()
  "Write Markdown proof obligations under `docs/formal/'."
  (interactive)
  (let ((path (gnopon/formal-path "proof-obligations.md")))
    (with-temp-file path
      (insert (gnopon/formal-proof-obligations-text)))
    (when (called-interactively-p 'interactive)
      (find-file path))
    path))

(defun gnopon/formal-bootstrap ()
  "Create formal validation scaffolds under `docs/formal/'."
  (interactive)
  (let ((readme (gnopon/formal-path "README.md")))
    (unless (file-exists-p readme)
      (with-temp-file readme
        (insert "# Formal Validation\n\n")
        (insert "Source artifacts remain GitHub-renderable Markdown predication cells under `docs/predications/`.\n\n")
        (insert "- `schema.ttl`: SHACL shape for predication-cell exports.\n")
        (insert "- `predications.ttl`: generated RDF/Turtle export.\n")
        (insert "- `proof-obligations.md`: generated Markdown review checklist.\n")))
    (gnopon/formal-write-shacl-schema)
    (gnopon/formal-write-rdf)
    (gnopon/formal-write-proof-obligations)
    (when (called-interactively-p 'interactive)
      (find-file readme))
    readme))

(defun gnopon/formal-validation-report ()
  "Open a Markdown validation report for formal artifacts."
  (interactive)
  (let* ((buffer (get-buffer-create "*formal-validation*"))
         (root (file-truename (gnopon/project-root)))
         (files (gnopon/predication-files))
         (issue-count 0))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# Formal Validation\n\n")
      (insert "- project: `" root "`\n")
      (insert "- predication cells: `" (number-to-string (length files)) "`\n\n")
      (insert "## Artifacts\n\n")
      (dolist (file '("docs/formal/schema.ttl"
                      "docs/formal/predications.ttl"
                      "docs/formal/proof-obligations.md"))
        (let ((path (expand-file-name file root)))
          (insert (if (file-readable-p path) "- [x] " "- [ ] ")
                  "`" file "`\n")))
      (insert "\n## Predication Cell Checks\n\n")
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
                  "Predication cells are structurally ready for RDF/SHACL validation.\n"
                (format "%s predication issue(s) must be fixed before formal validation.\n"
                        issue-count)))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(transient-define-prefix gnopon/formal-cockpit ()
  "Formal validation commands."
  [["Write"
    ("b" "bootstrap formal docs" gnopon/formal-bootstrap)
    ("s" "write SHACL schema" gnopon/formal-write-shacl-schema)
    ("r" "write RDF export" gnopon/formal-write-rdf)
    ("p" "write proof obligations" gnopon/formal-write-proof-obligations)]
   ["Inspect"
    ("v" "validation report" gnopon/formal-validation-report)
    ("P" "predication validation" gnopon/validate-predications)
    ("i" "predication index" gnopon/predication-index)]])

(define-key gnopon-map (kbd "m F") #'gnopon/formal-cockpit)

(provide 'gnopon-formal)
;;; gnopon-formal.el ends here
