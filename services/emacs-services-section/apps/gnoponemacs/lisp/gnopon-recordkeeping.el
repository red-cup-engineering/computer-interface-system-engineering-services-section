;;; gnopon-recordkeeping.el --- Human-controlled Org recordkeeping -*- lexical-binding: t; -*-

;;; Commentary:
;; The Markdown project knowledge system and this Org-based recordkeeping system
;; are distinct carriers.  This module recovers InfoPonEmacs's useful effects
;; without baking one person's directories, correspondence, publications, or
;; private records into the shared application.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-capture)
(require 'org-agenda)
(require 'ox-publish)
(require 'seq)
(require 'ucs-normalize)
(require 'gnopon-core)

(defgroup gnopon-recordkeeping nil
  "Human-controlled Org recordkeeping in GnoponEmacs."
  :group 'gnopon)

(defcustom gnopon-records-directory
  (expand-file-name "records/" gnopon-state-dir)
  "Root directory for a person's or group's Org records.
Set this to an existing record corpus before using agenda, capture, or roam
commands.  It is data, not an application source directory."
  :type 'directory
  :group 'gnopon-recordkeeping)

(defcustom gnopon-records-agenda-files nil
  "Explicit Org agenda files or directories.
When nil, all Org files under `gnopon-records-directory' form the agenda."
  :type '(repeat file)
  :group 'gnopon-recordkeeping)

(defcustom gnopon-org-publish-projects nil
  "Org publishing projects owned by the active records corpus.
Each value uses the normal `org-publish-project-alist' format.  This keeps
publication topology with its records instead of embedding personal websites
and paths in GnoponEmacs."
  :type '(repeat sexp)
  :group 'gnopon-recordkeeping)

(defcustom gnopon-org-cite-global-bibliography nil
  "Bibliography files belonging to the configured records corpus.
These are corpus data; GnoponEmacs does not prescribe a person's references."
  :type '(repeat file)
  :group 'gnopon-recordkeeping)

(defcustom gnopon-org-babel-languages '((shell . t))
  "Languages that may be evaluated in the configured record corpus.
This is explicit corpus policy.  The old configurations enabled different
languages for different bodies of work; Gnopon keeps that distinction instead
of silently inheriting a personal evaluation surface."
  :type '(repeat (cons symbol boolean))
  :group 'gnopon-recordkeeping)

(defcustom gnopon-org-link-abbreviations nil
  "Named Org link abbreviations supplied by the active record corpus."
  :type '(repeat (cons string string))
  :group 'gnopon-recordkeeping)

(defcustom gnopon-org-capture-templates nil
  "Additional ordinary `org-capture-templates' for the active corpus.
The generic inbox remains available through `gnopon/org-capture-record'; this
option carries a person's or group's deliberately chosen record forms."
  :type '(repeat sexp)
  :group 'gnopon-recordkeeping)

(defcustom gnopon-org-todo-keywords
  '((sequence "DRAFT" "EDIT" "|" "DONE")
    (sequence "|" "CANCELED"))
  "TODO workflow used by human records.
This retains the writing-to-publication workflow without prescribing a
particular person's projects or record files."
  :type '(repeat sexp)
  :group 'gnopon-recordkeeping)

(defcustom gnopon-org-agenda-span 'day
  "Time span shown by the ordinary Gnopon record agenda."
  :type 'symbol
  :group 'gnopon-recordkeeping)

(defcustom gnopon-org-deadline-warning-days 14
  "How far ahead the record agenda warns about deadlines."
  :type 'integer
  :group 'gnopon-recordkeeping)

(defcustom gnopon-record-profile nil
  "Identity properties used by a record corpus.
An alist such as `((name . NAME) (email . EMAIL))'.
It is deliberately empty in the shared application."
  :type '(repeat (cons symbol string))
  :group 'gnopon-recordkeeping)

(defcustom gnopon-record-projects nil
  "Project metadata owned by the active records corpus.
Each entry is `(ID . PLIST)', with useful keys including `:name', `:type',
`:description', `:author', `:origin-country', and `:license'."
  :type '(repeat sexp)
  :group 'gnopon-recordkeeping)

(defcustom gnopon-record-license-templates nil
  "License prose templates for `gnopon/record-insert-project-license'.
Each entry is `(LICENSE-ID . TEMPLATE)'.  TEMPLATE uses `%n' for project
name, `%a' for author, `%t' for project type, and `%o' for origin country."
  :type '(repeat (cons string string))
  :group 'gnopon-recordkeeping)

(defcustom gnopon-record-dictionary nil
  "Definitions belonging to the active record corpus.
Each entry is `(TERM . PLIST)', whose useful keys are `:definition' and
`:source'.  The application supplies the lookup and insertion effects; a
person or project supplies its own terms."
  :type '(repeat sexp)
  :group 'gnopon-recordkeeping)

(defcustom gnopon-record-fortunes nil
  "Short record-corpus prompts available for insertion at point."
  :type '(repeat string)
  :group 'gnopon-recordkeeping)

(defcustom gnopon-record-reading-list-file nil
  "Org file holding pending reading records.
Nil means `reading.org' below `gnopon-records-directory'."
  :type '(choice (const :tag "records-directory/reading.org" nil) file)
  :group 'gnopon-recordkeeping)

(defcustom gnopon-record-inventory-file nil
  "Org file holding physical inventory records.
Nil means `inventory.org' below `gnopon-records-directory'."
  :type '(choice (const :tag "records-directory/inventory.org" nil) file)
  :group 'gnopon-recordkeeping)

(defcustom gnopon-org-screenshot-command nil
  "Command template used by `org-attach-screenshot', when that package exists.
It must contain the package's output-file placeholder.  No desktop-specific
capture program is assumed by the application."
  :type '(choice (const :tag "Do not configure a screenshot tool" nil) string)
  :group 'gnopon-recordkeeping)

(defun gnopon/records-root ()
  "Return the normalized root directory for human recordkeeping."
  (file-name-as-directory (expand-file-name gnopon-records-directory)))

(defun gnopon/records-agenda-files ()
  "Return configured agenda files, discovering a record root when appropriate."
  (let ((configured gnopon-records-agenda-files)
        (root (gnopon/records-root)))
    (cond
     (configured (mapcar #'expand-file-name configured))
     ((file-directory-p root) (directory-files-recursively root "\\.org\\'"))
     (t nil))))

(defun gnopon/record-file (configured fallback)
  "Return CONFIGURED record file, or FALLBACK below the records root."
  (expand-file-name (or configured fallback) (gnopon/records-root)))

(defun gnopon/record-project (identifier)
  "Return configured metadata for project IDENTIFIER, or signal clearly."
  (or (cdr (assq identifier gnopon-record-projects))
      (user-error "gnopon: no record project named `%s'" identifier)))

(defun gnopon/record-project-property (identifier property)
  "Return PROPERTY from record project IDENTIFIER."
  (plist-get (gnopon/record-project identifier) property))

(defun gnopon/record-insert-project-license (identifier)
  "Insert the configured license prose for record project IDENTIFIER."
  (interactive
   (list (intern (completing-read "Record project: "
                                  (mapcar (lambda (entry) (symbol-name (car entry)))
                                          gnopon-record-projects)
                                  nil t))))
  (let* ((project (gnopon/record-project identifier))
         (license (plist-get project :license))
         (template (cdr (assoc-string (format "%s" license)
                                      gnopon-record-license-templates))))
    (unless template
      (user-error "gnopon: no license template configured for `%s'" license))
    (insert (format-spec template
                         `((?n . ,(or (plist-get project :name) (symbol-name identifier)))
                           (?a . ,(or (plist-get project :author)
                                      (alist-get 'name gnopon-record-profile) ""))
                           (?t . ,(or (plist-get project :type) "work"))
                           (?o . ,(or (plist-get project :origin-country) "")))))))

(defun gnopon/record-dictionary-entry (term)
  "Return the configured dictionary entry for TERM, or signal clearly."
  (or (cdr (assoc-string term gnopon-record-dictionary))
      (user-error "gnopon: no record dictionary entry for `%s'" term)))

(defun gnopon/record-insert-definition (term)
  "Insert the configured definition for TERM at point."
  (interactive (list (completing-read "Definition: "
                                      (mapcar #'car gnopon-record-dictionary) nil t)))
  (let ((definition (plist-get (gnopon/record-dictionary-entry term) :definition)))
    (unless definition (user-error "gnopon: `%s' has no configured definition" term))
    (insert definition)))

(defun gnopon/record-open-definition-source (term)
  "Open TERM's configured dictionary source in a browser."
  (interactive (list (completing-read "Definition source: "
                                      (mapcar #'car gnopon-record-dictionary) nil t)))
  (let ((source (plist-get (gnopon/record-dictionary-entry term) :source)))
    (unless source (user-error "gnopon: `%s' has no configured source" term))
    (browse-url source)))

(defun gnopon/record-insert-fortune ()
  "Insert one configured record-corpus prompt at point."
  (interactive)
  (unless gnopon-record-fortunes
    (user-error "gnopon: configure `gnopon-record-fortunes' first"))
  (insert (seq-random-elt gnopon-record-fortunes)))

(defun gnopon/record-append-entry (file heading properties)
  "Append an Org entry with HEADING and PROPERTIES to FILE, then save it."
  (unless (file-directory-p (gnopon/records-root))
    (user-error "gnopon: set `gnopon-records-directory' to a records directory first"))
  (with-current-buffer (find-file-noselect file)
    (org-mode)
    (goto-char (point-max))
    (unless (bolp) (insert "\n"))
    (insert (format "* TODO %s\n:PROPERTIES:\n" heading))
    (dolist (property properties)
      (insert (format ":%s: %s\n" (upcase (car property)) (cdr property))))
    (insert ":END:\n")
    (save-buffer)))

(defun gnopon/record-add-reading (title author source)
  "Persist TITLE, AUTHOR, and SOURCE as a pending human reading record."
  (interactive "sTitle: \nsAuthor: \nsSource URL: ")
  (gnopon/record-append-entry
   (gnopon/record-file gnopon-record-reading-list-file "reading.org") title
   `(("AUTHOR" . ,author) ("SOURCE" . ,source) ("CAPTURED" . ,(format-time-string "[%FT%T%z]"))))
  (message "GnoponEmacs: recorded %s for reading" title))

(defun gnopon/record-open-random-reading ()
  "Open a randomly selected pending reading record's source URL."
  (interactive)
  (let ((file (gnopon/record-file gnopon-record-reading-list-file "reading.org")))
    (unless (file-readable-p file)
      (user-error "gnopon: no readable reading record file at %s" file))
    (with-temp-buffer
      (insert-file-contents file)
      (let (sources)
        (while (re-search-forward "^:SOURCE:[[:space:]]*\\(https?://[^[:space:]]+\\)" nil t)
          (push (match-string-no-properties 1) sources))
        (unless sources (user-error "gnopon: no source URLs in %s" file))
        (browse-url (seq-random-elt sources))))))

(defun gnopon/record-add-inventory-item (name location notes)
  "Persist NAME, LOCATION, and NOTES as a physical inventory record."
  (interactive "sItem: \nsLocation: \nsNotes: ")
  (gnopon/record-append-entry
   (gnopon/record-file gnopon-record-inventory-file "inventory.org") name
   `(("LOCATION" . ,location) ("NOTES" . ,notes) ("RECORDED" . ,(format-time-string "[%FT%T%z]"))))
  (message "GnoponEmacs: recorded inventory item %s" name))

(defun gnopon/org-configure ()
  "Apply GnoponEmacs's generic InfoPon recordkeeping configuration.
No directory is created and no record is changed by this function."
  (interactive)
  (setq org-directory (gnopon/records-root)
        org-agenda-files (gnopon/records-agenda-files)
        org-startup-folded 'fold
        org-hide-block-startup 'hideblocks
        org-catch-invisible-edits 'show-and-error
        org-agenda-todo-ignore-scheduled 'all
        org-agenda-todo-ignore-deadlines 'all
        org-agenda-span gnopon-org-agenda-span
        org-agenda-window-setup 'current-window
        org-deadline-warning-days gnopon-org-deadline-warning-days
        org-tags-column 3
        org-todo-keywords gnopon-org-todo-keywords
        org-export-allow-bind-keywords t
        org-export-with-sub-superscripts nil
        org-export-with-special-strings nil
        org-export-with-todo-keywords nil
        org-export-headline-levels 10
        org-export-with-section-numbers nil
        org-export-with-smart-quotes nil
        org-export-with-toc nil
        org-html-htmlize-output-type nil
        org-html-validation-link nil
        org-log-done 'time
        org-log-into-drawer 'LOGBOOK
        org-image-actual-width '(400)
        org-hide-emphasis-markers t
        org-startup-indented t
        org-ellipsis "→"
        org-cite-global-bibliography gnopon-org-cite-global-bibliography
        org-link-abbrev-alist gnopon-org-link-abbreviations
        org-babel-load-languages gnopon-org-babel-languages
        org-export-global-macros '(("nl" . "(eval \"\\n\")"))
        org-agenda-custom-commands
        '(("A" "Agenda and TODO" ((agenda "") (alltodo "")))))
  (setq org-capture-templates gnopon-org-capture-templates)
  (setq org-publish-project-alist gnopon-org-publish-projects)
  (org-babel-do-load-languages 'org-babel-load-languages org-babel-load-languages))

(defun gnopon/org-readable-layout ()
  "Use the recovered reading layout in an Org record buffer.
This narrows the former global visual-line setting to its actual carrier:
human-authored records, rather than source code and terminal buffers."
  (visual-line-mode 1)
  (setq-local truncate-lines nil))

(add-hook 'org-mode-hook #'gnopon/org-readable-layout)

(defun gnopon/org-enable-focused-writing ()
  "Enable the optional narrow, distraction-reduced record-writing carrier."
  (interactive)
  (gnopon/org-readable-layout)
  (unless (require 'visual-fill-column nil t)
    (user-error "gnopon: install visual-fill-column for focused record writing"))
  (visual-fill-column-mode 1))

(defun gnopon/org-enable-pretty-outline ()
  "Enable the optional modern visual outline for the current Org record."
  (interactive)
  (unless (require 'org-modern nil t)
    (user-error "gnopon: install org-modern for a pretty record outline"))
  (org-modern-mode 1))

(defun gnopon/org-html-format-drawer (_name contents)
  "Export an Org drawer's CONTENTS as a semantic HTML section."
  (format "<section class=\"org-drawer\"> %s </section>" contents))

(defun gnopon/org-publish-format-sitemap (title sitemap)
  "Format an Org-publish sitemap with TITLE and SITEMAP."
  (concat (format "#+title: %s\n" title)
          "#+options: timestamp:nil date:nil\n"
          (org-list-to-org sitemap)))

(defun gnopon/org-open-agenda ()
  "Open the recovered agenda-and-todo view for the configured record corpus."
  (interactive)
  (gnopon/org-configure)
  (org-agenda nil "A"))

(defun gnopon/org-capture-record ()
  "Capture an inbox record under the configured human record root."
  (interactive)
  (gnopon/org-configure)
  (unless (file-directory-p (gnopon/records-root))
    (user-error "gnopon: set `gnopon-records-directory' to a records directory first"))
  (let ((org-capture-templates
         (append
          `(("i" "inbox" entry
             (file ,(expand-file-name "inbox.org" (gnopon/records-root)))
             "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n"))
          org-capture-templates)))
    (org-capture nil "i")))

(defun gnopon/org-attach-screenshot ()
  "Attach a screenshot using the configured portable capture command.
The old KDE command remains a user choice, not an application dependency."
  (interactive)
  (unless (require 'org-attach-screenshot nil t)
    (user-error "gnopon: install org-attach-screenshot to attach screenshots"))
  (unless gnopon-org-screenshot-command
    (user-error "gnopon: set `gnopon-org-screenshot-command' for this desktop"))
  (let ((org-attach-screenshot-command-line gnopon-org-screenshot-command))
    (call-interactively #'org-attach-screenshot)))

(defun gnopon/org-paste-buffer ()
  "Publish the current buffer through the optional `webpaste' carrier."
  (interactive)
  (unless (require 'webpaste nil t)
    (user-error "gnopon: install webpaste to publish a buffer"))
  (call-interactively #'webpaste-paste-buffer))

(defun gnopon/org-paste-region (start end)
  "Publish the selected region through the optional `webpaste' carrier."
  (interactive "r")
  (unless (require 'webpaste nil t)
    (user-error "gnopon: install webpaste to publish a region"))
  (webpaste-paste-region start end))

(defun gnopon/org-writing-statistics ()
  "Report readability for the current record through optional Writegood."
  (interactive)
  (unless (require 'writegood-mode nil t)
    (user-error "gnopon: install writegood-mode for writing statistics"))
  (call-interactively #'writegood-grade-level))

(defun gnopon/org-enable-spellcheck ()
  "Enable built-in Flyspell in the current human-authored record."
  (interactive)
  (flyspell-mode 1))

(defun gnopon/org-publish (project)
  "Publish configured records PROJECT using Org's ordinary publishing carrier."
  (interactive
   (progn
     (gnopon/org-configure)
     (list (completing-read "Publish project: "
                            (mapcar #'car gnopon-org-publish-projects) nil t))))
  (gnopon/org-configure)
  (org-publish project t))

(defun gnopon/org-roam-available-p ()
  "Return non-nil when the optional Org-roam integration is available."
  (require 'org-roam nil t))

(defun gnopon/org-roam-require ()
  "Return non-nil when Org-roam is ready, else explain how to enable it."
  (or (gnopon/org-roam-available-p)
      (user-error "gnopon: Org-roam is optional; install it to use linked-record commands")))

(defun gnopon/org-roam-configure ()
  "Configure Org-roam for the same explicit human record root."
  (interactive)
  (gnopon/org-roam-require)
  (setq org-roam-directory (file-truename (gnopon/records-root))
        org-roam-dailies-directory "."
        org-roam-db-extra-links-exclude-keys '((node-property "ROAM_REFS"))
        org-roam-capture-templates
        '(("c" "communication" plain "%?" :target (file+head "com/%<%Y%m%d>-${slug}.org" "#+title: ${title}\n") :unnarrowed t)
          ("d" "definition" plain "\n#+name: definition\n- ${title} :: %?\n" :target (file+head "definitions/${slug}.org" "#+title: ${title}\n#+date: %U\n") :unnarrowed t)
          ("p" "project" plain "%?" :target (file+head "projects/${slug}/index.org" "#+title: ${title}\n") :unnarrowed t)
          ("r" "reference" plain "%?" :target (file+head "references/${slug}.org" "#+title: ${title}\n") :unnarrowed t)
          ("P" "private record" plain "%?" :target (file+head "private/${slug}.org" "#+title: ${title}\n") :unnarrowed t)
          ("w" "contact" plain "%?" :target (file+head "private/people/${slug}.org" "#+title: ${title}\n") :unnarrowed t))
        org-roam-dailies-capture-templates
        '(("l" "log" entry "* %U :log:\n%?\n"
           :target (file+datetree "ledger/index.org" week) :tree-type week)))
  (org-roam-db-autosync-mode 1))

(defun gnopon/org-slugify (title)
  "Return TITLE as a stable, Unicode-normalized record slug.
The transformation preserves the InfoPonEmacs effect of treating accented and
unaccented spellings alike while avoiding a dependency on an old helper stack."
  (let* ((decomposed (ucs-normalize-NFD-string title))
         (without-marks
          (apply #'string
                 (seq-remove (lambda (character)
                               (eq (get-char-code-property character 'general-category)
                                   'Mn))
                             decomposed)))
         (normalized (ucs-normalize-NFC-string without-marks)))
    (downcase
     (replace-regexp-in-string
      "\\`-\\|-\\'" ""
      (replace-regexp-in-string "-+" "-"
                                (replace-regexp-in-string "[^[:alnum:]]" "-" normalized))))))

(with-eval-after-load 'org-roam
  (cl-defmethod org-roam-node-slug ((node org-roam-node))
    "Return NODE's stable GnoponEmacs record slug."
    (gnopon/org-slugify (org-roam-node-title node))))

(defun gnopon/org-roam-backlinks-markdown (file)
  "Return FILE's direct Org-roam backlinks as portable Markdown links.
The result is a report carrier: it can be read outside Emacs and does not
assume one person's old record-directory topology."
  (gnopon/org-roam-require)
  (let ((file (expand-file-name file)))
    (if (org-roam-file-p file)
        (mapconcat
         (lambda (row)
           (let* ((source (car row))
                  (title (or (org-roam-db--get-title source)
                             (file-name-base source))))
             (format "- [[file:%s][%s]]"
                     (file-relative-name source (gnopon/records-root)) title)))
         (org-roam-db-query
          [:select [source] :from links :where (= dest $s1)] file)
         "\n")
      "")))

(defun gnopon/org-roam-open-graph ()
  "Open the optional browser graph for the configured linked records."
  (interactive)
  (gnopon/org-roam-configure)
  (unless (require 'org-roam-ui nil t)
    (user-error "gnopon: install org-roam-ui to view the linked-record graph"))
  (org-roam-ui-mode 1))

(defun gnopon/org-practice-records ()
  "Practice scheduled Org-drill material from the configured agenda corpus."
  (interactive)
  (gnopon/org-configure)
  (unless (require 'org-drill nil t)
    (user-error "gnopon: install org-drill to practice records"))
  (let ((org-drill-scope 'agenda))
    (call-interactively #'org-drill)))

(defun gnopon/org-enable-transclusion ()
  "Enable transclusion in the current Org record buffer."
  (interactive)
  (unless (require 'org-transclusion nil t)
    (user-error "gnopon: install org-transclusion to embed records"))
  (setq-local org-transclusion-exclude-elements '(keyword property-drawer))
  (org-transclusion-mode 1))

(defun gnopon/org-add-transclusion ()
  "Insert a transclusion into the current Org record buffer."
  (interactive)
  (gnopon/org-enable-transclusion)
  (call-interactively #'org-transclusion-add))

(defun gnopon/open-ledger (file)
  "Open ledger FILE and activate optional Beancount editing when available."
  (interactive "fLedger file: ")
  (find-file file)
  (when (require 'beancount nil t)
    (when (fboundp 'beancount-mode)
      (beancount-mode 1))))

(defun gnopon/org-roam-find-record ()
  "Find or create a linked record in the configured records corpus."
  (interactive)
  (gnopon/org-roam-configure)
  (call-interactively #'org-roam-node-find))

(defun gnopon/org-roam-insert-record ()
  "Insert a link to a linked record at point."
  (interactive)
  (gnopon/org-roam-configure)
  (call-interactively #'org-roam-node-insert))

(defun gnopon/org-roam-capture-record ()
  "Capture a typed linked record."
  (interactive)
  (gnopon/org-roam-configure)
  (call-interactively #'org-roam-capture))

(defun gnopon/org-roam-capture-daily ()
  "Capture a daily log entry in the configured records corpus."
  (interactive)
  (gnopon/org-roam-configure)
  (call-interactively #'org-roam-dailies-capture-today))

(define-key gnopon-map (kbd "r a") #'gnopon/org-open-agenda)
(define-key gnopon-map (kbd "r c") #'gnopon/org-capture-record)
(define-key gnopon-map (kbd "r f") #'gnopon/org-roam-find-record)
(define-key gnopon-map (kbd "r i") #'gnopon/org-roam-insert-record)
(define-key gnopon-map (kbd "r d") #'gnopon/org-roam-capture-daily)
(define-key gnopon-map (kbd "r g") #'gnopon/org-roam-open-graph)
(define-key gnopon-map (kbd "r l") #'gnopon/open-ledger)
(define-key gnopon-map (kbd "r p") #'gnopon/org-publish)
(define-key gnopon-map (kbd "r s") #'gnopon/org-practice-records)
(define-key gnopon-map (kbd "r S") #'gnopon/org-attach-screenshot)
(define-key gnopon-map (kbd "r b") #'gnopon/org-paste-buffer)
(define-key gnopon-map (kbd "r w") #'gnopon/org-writing-statistics)
(define-key gnopon-map (kbd "r F") #'gnopon/org-enable-spellcheck)
(define-key gnopon-map (kbd "r t") #'gnopon/org-enable-transclusion)
(define-key gnopon-map (kbd "r T") #'gnopon/org-add-transclusion)
(define-key gnopon-map (kbd "r L") #'org-store-link)
(define-key gnopon-map (kbd "r R") #'org-refile)
(define-key gnopon-map (kbd "r C") #'org-clock-goto)
(define-key gnopon-map (kbd "r O") #'org-clock-out)
(define-key gnopon-map (kbd "r m") #'gnopon/org-enable-focused-writing)
(define-key gnopon-map (kbd "r M") #'gnopon/org-enable-pretty-outline)
(define-key gnopon-map (kbd "r I") #'gnopon/record-add-inventory-item)
(define-key gnopon-map (kbd "r q") #'gnopon/record-add-reading)
(define-key gnopon-map (kbd "r Q") #'gnopon/record-open-random-reading)
(define-key gnopon-map (kbd "r D") #'gnopon/record-insert-definition)
(define-key gnopon-map (kbd "r U") #'gnopon/record-open-definition-source)
(define-key gnopon-map (kbd "r !") #'gnopon/record-insert-fortune)
(define-key gnopon-map (kbd "r P") #'gnopon/record-insert-project-license)

(gnopon/org-configure)

(provide 'gnopon-recordkeeping)
;;; gnopon-recordkeeping.el ends here
