;;; gnopon-lib.el --- Pure helpers for GnoponEmacs -*- lexical-binding: t; -*-

;;; Code:

(require 'seq)
(require 'subr-x)

(defconst gnopon/task-regexp "^\\([[:space:]]*- \\[\\)\\([ xX-]\\)\\(\\] .*$\\)"
  "Regexp matching a GitHub-flavored Markdown task line.")

(defconst gnopon/secret-key-regexp
  "\\(api[_-]?key\\|token\\|secret\\|password\\|passwd\\|private[_-]?key\\|authorization\\)"
  "Regexp matching likely secret key names.")

(defconst gnopon/predication-values
  '("present" "absent" "both" "neither" "potential")
  "Bilattice-style values for project-memory predication cells.")

(defun gnopon/yaml-double-quote (value)
  "Return VALUE as a simple YAML double-quoted scalar."
  (format "\"%s\""
          (replace-regexp-in-string "\"" "\\\"" (format "%s" value) t t)))

(defun gnopon/yaml-scalar-unquote (value)
  "Return VALUE without one layer of simple YAML scalar quoting."
  (let ((text (string-trim (format "%s" value))))
    (if (and (>= (length text) 2)
             (string-prefix-p "\"" text)
             (string-suffix-p "\"" text))
        (replace-regexp-in-string "\\\\\"" "\"" (substring text 1 -1) t t)
      text)))

(defun gnopon/markdown-slugify (title)
  "Return a GitHub-friendly slug for TITLE."
  (let* ((downcased (downcase (string-trim title)))
         (ascii-ish (replace-regexp-in-string "[^a-z0-9]+" "-" downcased))
         (trim-left (replace-regexp-in-string "\\`-+" "" ascii-ish)))
    (replace-regexp-in-string "-+\\'" "" trim-left)))

(defun gnopon/turtle-local-name (value)
  "Return VALUE as a conservative Turtle prefixed-name local part."
  (let* ((slug (gnopon/markdown-slugify (gnopon/yaml-scalar-unquote value)))
         (name (replace-regexp-in-string "-" "_" slug)))
    (cond
     ((string-empty-p name) "x")
     ((string-match-p "\\`[0-9]" name) (concat "n_" name))
     (t name))))

(defun gnopon/turtle-string (value)
  "Return VALUE as an escaped Turtle string literal."
  (let ((text (gnopon/yaml-scalar-unquote value)))
    (concat "\""
            (mapconcat
             (lambda (char)
               (pcase char
                 (?\\ "\\\\")
                 (?\" "\\\"")
                 (?\n "\\n")
                 (?\t "\\t")
                 (_ (char-to-string char))))
             text
             "")
            "\"")))

(defun gnopon/markdown-frontmatter-string (title &optional status date tags)
  "Return YAML frontmatter for TITLE.
Optional STATUS defaults to draft.  Optional DATE defaults to today.  Optional
TAGS is a list of strings."
  (format "---\ntitle: %s\nstatus: %s\ncreated: %s\ntags: [%s]\n---\n\n"
          (gnopon/yaml-double-quote title)
          (or status "draft")
          (or date (format-time-string "%Y-%m-%d"))
          (mapconcat #'gnopon/yaml-double-quote (or tags nil) ", ")))

(defun gnopon/predication-cell-title (subject predicate object)
  "Return a readable title for a predication cell."
  (string-trim (format "%s / %s / %s" subject predicate object)))

(defun gnopon/predication-frontmatter-string (subject predicate object value regime side)
  "Return YAML frontmatter for a predication cell.
SUBJECT, PREDICATE, OBJECT, VALUE, REGIME, and SIDE are strings."
  (let ((title (gnopon/predication-cell-title subject predicate object)))
    (format (concat "---\n"
                    "title: %s\n"
                    "type: predication-cell\n"
                    "status: active\n"
                    "created: %s\n"
                    "subject: %s\n"
                    "predicate: %s\n"
                    "object: %s\n"
                    "value: %s\n"
                    "evidence-regime: %s\n"
                    "evidence-side: %s\n"
                    "depends-on: []\n"
                    "tags: [\"predication\", \"project-memory\"]\n"
                    "---\n\n")
            (gnopon/yaml-double-quote title)
            (format-time-string "%Y-%m-%d")
            (gnopon/yaml-double-quote subject)
            (gnopon/yaml-double-quote predicate)
            (gnopon/yaml-double-quote object)
            value
            regime
            side)))

(defun gnopon/markdown-frontmatter-end (text)
  "Return the end index of YAML frontmatter in TEXT, or nil."
  (when (string-prefix-p "---\n" text)
    (when (string-match "\n---\n" text 4)
      (match-end 0))))

(defun gnopon/markdown-frontmatter-body (text)
  "Return the YAML frontmatter body in TEXT, or nil."
  (when-let ((end (gnopon/markdown-frontmatter-end text)))
    (substring text 4 (- end 5))))

(defun gnopon/markdown-frontmatter-alist (text)
  "Return a simple alist parsed from YAML frontmatter in TEXT.
This intentionally supports the scalar and inline-list subset emitted by
GnoponEmacs, not arbitrary YAML."
  (when-let ((body (gnopon/markdown-frontmatter-body text)))
    (delq nil
          (mapcar
           (lambda (line)
             (when (string-match "^\\([^:#]+\\):[[:space:]]*\\(.*\\)$" line)
               (cons (intern (string-trim (match-string 1 line)))
                     (string-trim (match-string 2 line)))))
           (split-string body "\n" t)))))

(defun gnopon/markdown-frontmatter-set-field (text key value)
  "Return TEXT with YAML frontmatter KEY set to VALUE."
  (let* ((key-string (if (symbolp key) (symbol-name key) key))
         (line (format "%s: %s" key-string value))
         (end (gnopon/markdown-frontmatter-end text)))
    (if end
        (let* ((front (substring text 0 end))
               (rest (substring text end))
               (regexp (format "^%s:[^\n]*$" (regexp-quote key-string))))
          (if (string-match regexp front)
              (concat (replace-match line t t front) rest)
            (concat (substring front 0 -4) line "\n---\n" rest)))
      (concat "---\n" line "\n---\n\n" text))))

(defun gnopon/markdown-upsert-section (text heading body)
  "Return TEXT with Markdown HEADING section set to BODY.
HEADING should include leading # characters, such as \"## Tests\"."
  (let ((section (concat heading "\n\n" body)))
    (if (string-match (concat "^" (regexp-quote heading) "\n") text)
        (let* ((start (match-beginning 0))
               (content-start (match-end 0))
               (next (or (string-match "^#+ " text content-start)
                         (length text))))
          (concat (substring text 0 start)
                  section
                  (if (string-suffix-p "\n\n" body)
                      ""
                    (if (string-suffix-p "\n" body) "\n" "\n\n"))
                  (substring text next)))
      (concat (string-remove-suffix "\n" text) "\n\n" section
              (unless (string-suffix-p "\n" body) "\n")))))

(defun gnopon/markdown-heading-entries (text)
  "Return Markdown heading entries parsed from TEXT.
Each entry is an alist with `level', `title', `slug', and `line'."
  (let ((line-number 0)
        entries)
    (dolist (line (split-string text "\n"))
      (setq line-number (1+ line-number))
      (when (string-match "^\\(#+\\)[ \t]+\\(.+\\)$" line)
        (let* ((level (length (match-string 1 line)))
               (raw-title (string-trim (match-string 2 line)))
               (title (string-trim
                       (replace-regexp-in-string "[ \t]+#+[ \t]*\\'" "" raw-title))))
          (when (<= level 6)
            (push `((level . ,level)
                    (title . ,title)
                    (slug . ,(gnopon/markdown-slugify title))
                    (line . ,line-number))
                  entries)))))
    (nreverse entries)))

(defun gnopon/markdown-link-entries (text)
  "Return Markdown link entries parsed from TEXT.
Each entry is an alist with `type', `label', `target', and `line'."
  (let ((line-number 0)
        entries)
    (dolist (line (split-string text "\n"))
      (setq line-number (1+ line-number))
      (let ((position 0)
            (limit (length line)))
        (while (< position limit)
          (let ((open (string-search "[" line position)))
            (cond
             ((null open)
              (setq position limit))
             ((and (> open 0) (eq (aref line (1- open)) ?!))
              (setq position (1+ open)))
             ((and (< (1+ open) limit) (eq (aref line (1+ open)) ?\[))
              (if-let ((close (string-search "]]" line (+ open 2))))
                  (let* ((raw (substring line (+ open 2) close))
                         (parts (split-string raw (regexp-quote "|")))
                         (target (string-trim (car parts)))
                         (label (string-trim (or (cadr parts) target))))
                    (push `((type . wiki)
                            (label . ,label)
                            (target . ,target)
                            (line . ,line-number))
                          entries)
                    (setq position (+ close 2)))
                (setq position (1+ open))))
             (t
              (let ((separator (string-search "](" line (1+ open))))
                (if-let ((close (and separator
                                     (string-search ")" line (+ separator 2)))))
                    (let ((label (substring line (1+ open) separator))
                          (target (substring line (+ separator 2) close)))
                      (push `((type . markdown)
                              (label . ,label)
                              (target . ,target)
                              (line . ,line-number))
                            entries)
                      (setq position (1+ close)))
                  (setq position (1+ open))))))))))
    (nreverse entries)))

(defun gnopon/markdown-task-entries (text)
  "Return Markdown task entries parsed from TEXT.
Each entry is an alist with `state', `text', and `line'."
  (let ((line-number 0)
        entries)
    (dolist (line (split-string text "\n"))
      (setq line-number (1+ line-number))
      (when-let ((state (gnopon/markdown-task-state line)))
        (push `((state . ,state)
                (text . ,(string-trim line))
                (line . ,line-number))
              entries)))
    (nreverse entries)))

(defun gnopon/markdown-structure-summary (text)
  "Return structural counts for Markdown TEXT."
  (let* ((headings (gnopon/markdown-heading-entries text))
         (links (gnopon/markdown-link-entries text))
         (tasks (gnopon/markdown-task-entries text))
         (h1-count (length (seq-filter (lambda (entry)
                                         (= (alist-get 'level entry) 1))
                                       headings))))
    `((headings . ,(length headings))
      (h1 . ,h1-count)
      (links . ,(length links))
      (tasks . ,(length tasks)))))

(defun gnopon/markdown-task-state (line)
  "Return task state for Markdown task LINE.
The return value is one of `todo', `done', `canceled', or nil."
  (when (string-match gnopon/task-regexp line)
    (pcase (match-string 2 line)
      (" " 'todo)
      ((or "x" "X") 'done)
      ("-" 'canceled))))

(defun gnopon/markdown-toggle-task-line (line)
  "Toggle Markdown task LINE between todo and done.
Canceled tasks remain canceled.  Non-task lines are returned unchanged."
  (if (string-match gnopon/task-regexp line)
      (let* ((state (match-string 2 line))
             (next (pcase state
                     (" " "x")
                     ((or "x" "X") " ")
                     ("-" "-"))))
        (replace-match (concat "\\1" next "\\3") nil nil line))
    line))

(defun gnopon/safe-command-risk (command)
  "Return a risk label for shell COMMAND.
The result is one of `low', `write', `network', or `dangerous'."
  (cond
   ((string-match-p "\\brm\\s-+-rf\\b\\|\\bgit\\s-+reset\\b\\|\\bsudo\\b\\|[|;&`]" command)
    'dangerous)
   ((string-match-p "\\bcurl\\b\\|\\bwget\\b\\|\\bgh\\s-+api\\b" command)
    'network)
   ((string-match-p "\\bmv\\b\\|\\bcp\\b\\|\\btouch\\b\\|\\bmkdir\\b\\|\\bnpm\\s-+install\\b\\|\\bpnpm\\s-+install\\b" command)
    'write)
   (t 'low)))

(defun gnopon/redact-secret-line (line)
  "Redact likely secret values in LINE."
  (if (string-match-p gnopon/secret-key-regexp (downcase line))
      (cond
       ((string-match "^\\([^:=\n]+\\)\\([:=]\\)\\(.*\\)$" line)
        (concat (string-trim-right (match-string 1 line))
                (match-string 2 line)
                " [REDACTED]"))
       ((string-match "^\\([^ \t\n]+\\)[ \t]+\\(.*\\)$" line)
        (concat (match-string 1 line) " [REDACTED]"))
       (t "[REDACTED]"))
    line))

(defun gnopon/redact-secrets (text)
  "Redact likely secret values in TEXT."
  (mapconcat #'gnopon/redact-secret-line (split-string text "\n") "\n"))

(defun gnopon/truncate-text (text max-bytes)
  "Return TEXT truncated to MAX-BYTES characters with a Markdown notice."
  (if (<= (length text) max-bytes)
      text
    (concat (substring text 0 max-bytes)
            "\n\n...[truncated by GnoponEmacs at "
            (number-to-string max-bytes)
            " characters]...\n")))

(defun gnopon/markdown-buffer-mode ()
  "Use the best available Markdown-ish mode for generated buffers."
  (cond
   ((fboundp 'gfm-mode) (gfm-mode))
   ((fboundp 'markdown-mode) (markdown-mode))
   (t (text-mode))))

(provide 'gnopon-lib)
;;; gnopon-lib.el ends here
