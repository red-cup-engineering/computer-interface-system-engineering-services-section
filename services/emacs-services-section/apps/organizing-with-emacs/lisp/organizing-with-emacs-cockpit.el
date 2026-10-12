;;; organizing-with-emacs-cockpit.el --- Cockpit realization and launch -*- lexical-binding: t; -*-

;;; Commentary:
;; The engine produces the relation topology.  This module validates that plan
;; at the boundary, then gives its chat and evidence panes a useful window
;; arrangement without reimplementing engine policy.

;;; Code:

(require 'organizing-with-emacs-engine)
(require 'organizing-with-emacs-panes)

(defun organizing-with-emacs--plan-pane (plan key)
  "Return required pane KEY from PLAN or signal a useful boundary error."
  (let ((pane (alist-get key plan)))
    (unless (listp pane)
      (user-error "organizing-with-emacs: engine plan has no `%s' pane" key))
    pane))

(defun organizing-with-emacs-validate-plan (plan)
  "Validate the engine-provided cockpit PLAN and return it.
The relation engine remains free to change its topology, but the terminal and
monitor carriers require named buffers and a chat command to realize it."
  (unless (listp plan)
    (user-error "organizing-with-emacs: engine returned a non-object cockpit plan"))
  (let ((chat (organizing-with-emacs--plan-pane plan 'chat))
        (monitors (alist-get 'monitors plan)))
    (unless (and (stringp (alist-get 'buffer chat))
                 (stringp (alist-get 'command chat)))
      (user-error "organizing-with-emacs: chat pane needs string `buffer' and `command' fields"))
    (unless (or (null monitors) (listp monitors))
      (user-error "organizing-with-emacs: monitors must be an array"))
    (dolist (pane monitors)
      (unless (and (listp pane) (stringp (alist-get 'buffer pane)))
        (user-error "organizing-with-emacs: every monitor needs a string `buffer' field"))))
  plan)
(defun organizing-with-emacs-realize-cockpit (plan)
  "Realize cockpit PLAN: a chat pane with a column of monitor panes.
Return PLAN."
  (setq plan (organizing-with-emacs-validate-plan plan))
  (let* ((session (alist-get 'session plan))
         (character (alist-get 'character plan))
         (_ (when character (organizing-with-emacs--provision-character character)))
         (chat-buffer (organizing-with-emacs--make-chat (alist-get 'chat plan)))
         (monitor-buffers (mapcar #'organizing-with-emacs--make-monitor (alist-get 'monitors plan))))
    (when session
      (with-current-buffer chat-buffer (setq-local organizing-with-emacs-session session)))
    (delete-other-windows)
    (switch-to-buffer chat-buffer)
    (let ((chat-window (selected-window)))
      (when monitor-buffers
        (let ((right (split-window-right
                      (floor (* (window-total-width) organizing-with-emacs-chat-width-fraction)))))
          (select-window right)
          (switch-to-buffer (car monitor-buffers))
          (dolist (buffer (cdr monitor-buffers))
            (select-window (split-window-below))
            (switch-to-buffer buffer))
          (balance-windows right)))
      (select-window chat-window))
    plan))

;;;###autoload
(defun organizing-with-emacs-launch-cockpit (&optional agent-id)
  "Choose AGENT-ID, or prompt for one, and realize its fresh session cockpit.
Each invocation asks the relation engine for a new persona-bound session plan,
then places the terminal beside its world card and declared evidence streams."
  (interactive)
  (organizing-with-emacs--require-engine)
  (let* ((id (or agent-id (organizing-with-emacs-choose-agent)))
         (plan (organizing-with-emacs-open-session id)))
    (organizing-with-emacs-realize-cockpit plan)
    (let ((persona (alist-get 'persona (alist-get 'session plan))))
      (message "organizing-with-emacs: %s session as %s %s"
               (alist-get 'label plan)
               (or (alist-get 'glyph persona) "")
               (or (alist-get 'name persona) "")))
    plan))

(provide 'organizing-with-emacs-cockpit)
;;; organizing-with-emacs-cockpit.el ends here
