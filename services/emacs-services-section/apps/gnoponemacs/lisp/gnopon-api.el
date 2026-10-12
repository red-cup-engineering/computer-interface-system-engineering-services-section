;;; gnopon-api.el --- API, HTTP, and CLI engineering -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'gnopon-lib)
(require 'transient)

(gnopon/use-optional-package restclient
  :mode ("\\.http\\'" "\\.rest\\'"))

(gnopon/use-optional-package jq-mode
  :mode "\\.jq\\'")

(gnopon/use-optional-package json-mode
  :mode ("\\.json\\'" . json-mode))

(defvar gnopon-api-log-directory "logs/api/"
  "Project-relative directory for API request logs.")

(defun gnopon/open-api-scratch ()
  "Open a project-local HTTP scratch file."
  (interactive)
  (let ((path (gnopon/project-file "requests.http")))
    (find-file path)
    (when (= (point-min) (point-max))
      (insert "# Project API scratch\n\nGET http://localhost:3000/health\nAccept: application/json\n"))))

(defun gnopon/open-env-example ()
  "Open or create `.env.example' for explicit environment documentation."
  (interactive)
  (find-file (gnopon/project-file ".env.example")))

(defun gnopon/open-json-scratch ()
  "Open a project-local JSON scratch file."
  (interactive)
  (let ((path (gnopon/project-file "scratch.json")))
    (find-file path)
    (when (= (point-min) (point-max))
      (insert "{\n  \"ok\": true\n}\n"))))

(defun gnopon/open-jq-scratch ()
  "Open a project-local jq scratch file."
  (interactive)
  (let ((path (gnopon/project-file "scratch.jq")))
    (find-file path)
    (when (= (point-min) (point-max))
      (insert ".\n"))))

(defun gnopon/api-log-path ()
  "Return a timestamped project-local API log path."
  (let ((dir (gnopon/project-file gnopon-api-log-directory)))
    (make-directory dir t)
    (expand-file-name (format "%s-curl.md" (format-time-string "%Y%m%d-%H%M%S")) dir)))

(defun gnopon/curl-to-buffer (url)
  "Run curl for URL after explicit confirmation and show output."
  (interactive "sURL: ")
  (unless (yes-or-no-p (format "Run curl for %s? " url))
    (user-error "Canceled"))
  (let ((buffer (get-buffer-create "*curl*")))
    (with-current-buffer buffer
      (erase-buffer)
      (let ((exit (call-process "curl" nil buffer t "--fail" "--show-error" "--silent" url)))
        (goto-char (point-min))
        (cond
         ((fboundp 'json-mode) (json-mode))
         ((fboundp 'js-json-mode) (js-json-mode)))
        (message "curl exited with %s" exit)))
    (pop-to-buffer buffer)))

(defun gnopon/curl-to-log (url)
  "Run curl for URL after confirmation and capture a Markdown API log."
  (interactive "sURL: ")
  (unless (yes-or-no-p (format "Run curl and log %s? " url))
    (user-error "Canceled"))
  (let ((path (gnopon/api-log-path))
        (buffer (get-buffer-create "*curl-log*"))
        (exit-code nil))
    (with-current-buffer buffer
      (erase-buffer)
      (insert "# Curl Request Log\n\n")
      (insert "- url: `" url "`\n")
      (insert "- project: `" (file-truename (gnopon/project-root)) "`\n")
      (insert "- created: `" (format-time-string "%Y-%m-%d %H:%M:%S") "`\n\n")
      (insert "## Response\n\n```text\n")
      (setq exit-code
            (call-process "curl" nil buffer t "--fail" "--show-error" "--silent" url))
      (insert "\n```\n\n")
      (insert (format "exit-code: `%s`\n" exit-code))
      (write-region (point-min) (point-max) path))
    (find-file path)))

(defun gnopon/api-request-note (title)
  "Create an API request note with TITLE."
  (interactive "sAPI note title: ")
  (let* ((dir (gnopon/project-file "docs/api/"))
         (path (expand-file-name
                (format "%s-%s.md" (format-time-string "%Y%m%d")
                        (gnopon/markdown-slugify title))
                dir)))
    (make-directory dir t)
    (find-file path)
    (when (= (point-min) (point-max))
      (insert (gnopon/markdown-frontmatter-string title "active" nil '("api" "request")))
      (insert "# " title "\n\n")
      (insert "## Request\n\n```http\nGET http://localhost:3000/health\nAccept: application/json\n```\n\n")
      (insert "## Environment\n\n- `.env.example` documents required variables.\n\n")
      (insert "## Expected Response\n\n```json\n{}\n```\n\n")
      (insert "## Evidence\n\n- [ ] Curl log captured under `logs/api/`.\n"))))

(defun gnopon/api-status ()
  "Open a Markdown status report for project API assets."
  (interactive)
  (let ((buffer (get-buffer-create "*gnopon-api-status*"))
        (root (file-truename (gnopon/project-root))))
    (with-current-buffer buffer
      (read-only-mode -1)
      (erase-buffer)
      (insert "# API Status\n\n")
      (dolist (file '("requests.http" ".env.example" "scratch.json" "scratch.jq"))
        (insert "- " (if (file-exists-p (expand-file-name file root)) "[x] " "[ ] ")
                "`" file "`\n"))
      (insert "\n## Logs\n\n")
      (let ((dir (expand-file-name gnopon-api-log-directory root)))
        (if (file-directory-p dir)
            (dolist (file (last (sort (directory-files dir nil "\\.md\\'") #'string<) 10))
              (insert "- `" file "`\n"))
          (insert "- none\n")))
      (gnopon/markdown-buffer-mode)
      (goto-char (point-min))
      (read-only-mode 1))
    (pop-to-buffer buffer)))

(transient-define-prefix gnopon/api-cockpit ()
  "API, HTTP, and JSON cockpit."
  [["Files"
    ("h" "HTTP scratch" gnopon/open-api-scratch)
    ("e" ".env.example" gnopon/open-env-example)
    ("j" "JSON scratch" gnopon/open-json-scratch)
    ("q" "jq scratch" gnopon/open-jq-scratch)]
   ["Requests"
    ("c" "curl to buffer" gnopon/curl-to-buffer)
    ("l" "curl to log" gnopon/curl-to-log)
    ("n" "request note" gnopon/api-request-note)
    ("s" "API status" gnopon/api-status)]])

(define-key gnopon-map (kbd "p a") #'gnopon/api-cockpit)
(define-key gnopon-map (kbd "p A") #'gnopon/open-api-scratch)
(define-key gnopon-map (kbd "p E") #'gnopon/open-env-example)
(define-key gnopon-map (kbd "p C") #'gnopon/curl-to-buffer)

(provide 'gnopon-api)
;;; gnopon-api.el ends here
