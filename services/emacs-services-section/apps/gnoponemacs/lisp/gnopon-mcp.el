;;; gnopon-mcp.el --- Local MCP-style project memory adapters -*- lexical-binding: t; -*-

;;; Code:

(require 'json)
(require 'seq)
(require 'gnopon-core)
(require 'gnopon-lib)
(require 'gnopon-markdown)
(require 'gnopon-predication)
(require 'transient)

(defcustom gnopon-mcp-output-directory "logs/mcp/"
  "Project-relative directory for local MCP adapter exports."
  :type 'string
  :group 'gnopon)

(defun gnopon/mcp-output-directory ()
  "Return the project-local MCP adapter output directory."
  (let ((dir (gnopon/project-file gnopon-mcp-output-directory)))
    (make-directory dir t)
    dir))

(defun gnopon/mcp-index-path (name)
  "Return output path for MCP adapter index NAME."
  (expand-file-name name (gnopon/mcp-output-directory)))

(defun gnopon/mcp-markdown-files-under (root directory)
  "Return Markdown files under project ROOT and project-relative DIRECTORY."
  (let ((absolute (expand-file-name directory root)))
    (if (file-directory-p absolute)
        (sort (directory-files-recursively absolute "\\.md\\'")
              #'string<)
      nil)))

(defun gnopon/mcp-file-frontmatter (path)
  "Return parsed Markdown frontmatter from PATH, or nil."
  (when (file-readable-p path)
    (with-temp-buffer
      (insert-file-contents path nil 0 20000)
      (gnopon/markdown-frontmatter-alist (buffer-string)))))

(defun gnopon/mcp-file-sha256 (path)
  "Return the SHA-256 content hash for PATH."
  (with-temp-buffer
    (insert-file-contents-literally path)
    (secure-hash 'sha256 (current-buffer))))

(defun gnopon/mcp-file-entry (root relative kind)
  "Return a JSON-ready index entry for RELATIVE file under ROOT as KIND."
  (let* ((path (expand-file-name relative root))
         (exists (file-readable-p path))
         (attrs (when exists (file-attributes path)))
         (frontmatter (gnopon/mcp-file-frontmatter path)))
    `((id . ,relative)
      (kind . ,kind)
      (path . ,relative)
      (uri . ,(concat "file://" (file-truename path)))
      (mimeType . "text/markdown")
      (exists . ,(if exists t json-false))
      (bytes . ,(if attrs (file-attribute-size attrs) 0))
      (sha256 . ,(when exists (gnopon/mcp-file-sha256 path)))
      (frontmatter . ,frontmatter))))

(defun gnopon/mcp-project-memory-entries (root)
  "Return JSON-ready project memory entries for ROOT."
  (mapcar (lambda (file)
            (gnopon/mcp-file-entry root file "project-memory"))
          gnopon-context-files))

(defun gnopon/mcp-predication-entries (root)
  "Return JSON-ready predication-cell entries for ROOT."
  (mapcar (lambda (file)
            (gnopon/mcp-file-entry root (file-relative-name file root) "predication-cell"))
          (seq-remove
           (lambda (file)
             (string= (file-name-nondirectory file) "README.md"))
           (gnopon/mcp-markdown-files-under root gnopon-predication-directory))))

(defun gnopon/mcp-agent-session-entries (root)
  "Return JSON-ready agent session entries for ROOT."
  (mapcar (lambda (file)
            (gnopon/mcp-file-entry root (file-relative-name file root) "agent-session"))
          (gnopon/mcp-markdown-files-under root "logs/agent/")))

(defun gnopon/mcp-all-resource-entries (root)
  "Return every local MCP-readable resource entry for ROOT."
  (append (gnopon/mcp-project-memory-entries root)
          (gnopon/mcp-predication-entries root)
          (gnopon/mcp-agent-session-entries root)))

(defun gnopon/mcp-resource-descriptor (entry)
  "Return an MCP-style resource descriptor for indexed ENTRY."
  `((uri . ,(alist-get 'uri entry))
    (name . ,(alist-get 'path entry))
    (mimeType . ,(alist-get 'mimeType entry))
    (description . ,(format "GnoponEmacs %s resource at %s"
                            (alist-get 'kind entry)
                            (alist-get 'path entry)))
    (annotations . ((gnoponKind . ,(alist-get 'kind entry))
                    (exists . ,(alist-get 'exists entry))
                    (sha256 . ,(alist-get 'sha256 entry))))))

(defun gnopon/mcp-project-memory-index-data ()
  "Return JSON-ready project memory index data for the current project."
  (let* ((root (file-truename (gnopon/project-root)))
         (entries (gnopon/mcp-project-memory-entries root)))
    `((schema . "gnopon.project-memory.v1")
      (projectRoot . ,root)
      (generatedAt . ,(format-time-string "%Y-%m-%dT%H:%M:%SZ" nil t))
      (resources . ,(vconcat entries)))))

(defun gnopon/mcp-agent-session-index-data ()
  "Return JSON-ready agent session index data for the current project."
  (let* ((root (file-truename (gnopon/project-root)))
         (entries (gnopon/mcp-agent-session-entries root)))
    `((schema . "gnopon.agent-sessions.v1")
      (projectRoot . ,root)
      (generatedAt . ,(format-time-string "%Y-%m-%dT%H:%M:%SZ" nil t))
      (sessions . ,(vconcat entries)))))

(defun gnopon/mcp-resource-manifest-data ()
  "Return an MCP-style resource manifest for the current project."
  (let* ((root (file-truename (gnopon/project-root)))
         (entries (seq-filter
                   (lambda (entry) (eq (alist-get 'exists entry) t))
                   (gnopon/mcp-all-resource-entries root)))
         (resources (mapcar #'gnopon/mcp-resource-descriptor entries)))
    `((schema . "gnopon.mcp.resources.v1")
      (projectRoot . ,root)
      (generatedAt . ,(format-time-string "%Y-%m-%dT%H:%M:%SZ" nil t))
      (resources . ,(vconcat resources)))))

(defun gnopon/mcp-write-json (path data)
  "Write JSON DATA to PATH and return PATH."
  (make-directory (file-name-directory path) t)
  (let ((json-encoding-pretty-print t))
    (with-temp-file path
      (insert (json-encode data))
      (insert "\n")))
  path)

(defun gnopon/mcp-write-indexes ()
  "Write local MCP adapter indexes under `logs/mcp/'."
  (interactive)
  (let ((paths (list
                (gnopon/mcp-write-json
                 (gnopon/mcp-index-path "resources.json")
                 (gnopon/mcp-resource-manifest-data))
                (gnopon/mcp-write-json
                 (gnopon/mcp-index-path "project-memory.json")
                 (gnopon/mcp-project-memory-index-data))
                (gnopon/mcp-write-json
                 (gnopon/mcp-index-path "agent-sessions.json")
                 (gnopon/mcp-agent-session-index-data)))))
    (when (called-interactively-p 'interactive)
      (message "Wrote MCP adapter indexes: %s" (string-join paths ", ")))
    paths))

(defun gnopon/mcp-open-resource-manifest ()
  "Write and open the local MCP resource manifest."
  (interactive)
  (gnopon/mcp-write-indexes)
  (find-file (gnopon/mcp-index-path "resources.json")))

(defun gnopon/mcp-status ()
  "Open a Markdown status buffer for local MCP adapter exports."
  (interactive)
  (let* ((root (file-truename (gnopon/project-root)))
         (memory (gnopon/mcp-project-memory-entries root))
         (predications (gnopon/mcp-predication-entries root))
         (sessions (gnopon/mcp-agent-session-entries root))
         (buffer (get-buffer-create "*gnopon-mcp*")))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# Local MCP Adapter Status\n\n")
      (insert "- project: `" root "`\n")
      (insert "- output: `" (gnopon/mcp-output-directory) "`\n")
      (insert "- project-memory entries: `" (number-to-string (length memory)) "`\n")
      (insert "- predication entries: `" (number-to-string (length predications)) "`\n")
      (insert "- agent sessions: `" (number-to-string (length sessions)) "`\n\n")
      (insert "## Index Files\n\n")
      (dolist (file '("resources.json" "project-memory.json" "agent-sessions.json"))
        (let ((path (gnopon/mcp-index-path file)))
          (insert (if (file-readable-p path) "- [x] " "- [ ] ")
                  "`" (file-relative-name path root) "`\n")))
      (insert "\n## Resource Kinds\n\n")
      (insert "- `project-memory`: standard Markdown context files.\n")
      (insert "- `predication-cell`: typed Markdown predication notes.\n")
      (insert "- `agent-session`: timestamped agent workflow records.\n")
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(transient-define-prefix gnopon/mcp-cockpit ()
  "Local MCP adapter commands."
  [["Indexes"
    ("w" "write indexes" gnopon/mcp-write-indexes)
    ("o" "open manifest" gnopon/mcp-open-resource-manifest)
    ("s" "status" gnopon/mcp-status)]
   ["Source"
    ("m" "memory index" gnopon/project-memory-index)
    ("p" "predication index" gnopon/predication-index)
    ("a" "agent sessions" gnopon/agent-session-index)]])

(define-key gnopon-map (kbd "a M") #'gnopon/mcp-cockpit)
(define-key gnopon-map (kbd "m X") #'gnopon/mcp-write-indexes)

(provide 'gnopon-mcp)
;;; gnopon-mcp.el ends here
