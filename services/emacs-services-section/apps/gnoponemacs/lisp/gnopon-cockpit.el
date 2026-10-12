;;; gnopon-cockpit.el --- Transient command cockpit -*- lexical-binding: t; -*-

;;; Code:

(require 'gnopon-core)
(require 'transient)

(transient-define-prefix gnopon/cockpit ()
  "GnoponEmacs cockpit."
  [["Project"
    ("o" "control center" gnopon/control-center)
    ("k" "knowledge vault" gnopon/knowledge-vault)
    ("f" "find file" project-find-file)
    ("d" "dashboard" gnopon/project-dashboard)
    ("s" "workspace snapshot" gnopon/workspace-snapshot)
    ("." "context actions" gnopon/context-actions)
    ("!" "doctor" gnopon/doctor)
    ("%" "performance" gnopon/performance-report)
    ("C" "capability audit" gnopon/capability-audit)
    ("?" "safety audit" gnopon/safety-audit)
    ("r" "search" gnopon/search-project)
    ("b" "buffer" gnopon/switch-buffer)]
   ["Code"
    ("." "symbol actions" gnopon/symbol-actions)
    ("c" "check" gnopon/check-project)
    ("t" "test" gnopon/test-project)
    ("m" "command matrix" gnopon/project-command-matrix)
    ("R" "run candidate" gnopon/run-project-command-candidate)
    ("n" "npm/pnpm script" gnopon/run-package-script)
    ("x" "compile" gnopon/compile-in-project)
    ("l" "lint" gnopon/lint-project)
    ("F" "format" gnopon/format-buffer)
    ("D" "debug" gnopon/debug-project)
    ("H" "HTTP scratch" gnopon/open-api-scratch)
    ("A" "API cockpit" gnopon/api-cockpit)]
   ["Memory"
    ("k" "knowledge vault" gnopon/knowledge-vault)
    ("G" "goals" gnopon/open-goals-file)
    ("N" "knowledge note" gnopon/capture-knowledge-note)
    ("m" "context file" gnopon/open-context-file)
    ("i" "memory index" gnopon/project-memory-index)
    ("g" "link graph" gnopon/markdown-link-graph-report)
    ("u" "structure report" gnopon/markdown-structure-report)
    ("t" "task cockpit" gnopon/task-cockpit)
    ("P" "predication cell" gnopon/create-predication-cell)
    ("Q" "predication index" gnopon/predication-index)
    ("F" "formal validation" gnopon/formal-cockpit)
    ("b" "bootstrap memory" gnopon/bootstrap-project-memory)
    ("v" "validate memory" gnopon/validate-project-memory)
    ("Y" "validate predications" gnopon/validate-predications)
    ("s" "sync agents" gnopon/sync-agent-context-files)
    ("T" "tasks" gnopon/search-tasks)
    ("B" "backlinks" gnopon/search-backlinks)
    ("?" "predication search" gnopon/search-predications)
    ("M" "memory search" gnopon/search-project-memory)
    ("A" "ADR" gnopon/create-adr)
    ("R" "RFC" gnopon/create-rfc)]
   ["Agent"
    ("g" "agent cockpit" gnopon/cockpit-launch)
    ("x" "Codex cockpit" gnopon/codex-cockpit)
    ("z" "Codex workspace" gnopon/codex-workspace)
    ("a" "Codex activity" gnopon/codex-monitor)
    ("q" "Codex prompt" gnopon/codex-compose-prompt)
    ("C" "copy context" gnopon/agent-context)
    ("O" "open context" gnopon/open-context-bundle)
    ("W" "write context" gnopon/write-context-bundle)
    ("M" "MCP exports" gnopon/mcp-cockpit)
    ("H" "agent handoff" gnopon/open-agent-handoff)
    ("h" "write handoff" gnopon/write-agent-handoff)
    ("S" "agent shell" gnopon/agent-shell)
    ("N" "new session" gnopon/start-agent-session)
    ("I" "session index" gnopon/agent-session-index)
    ("/" "search sessions" gnopon/search-agent-sessions)
    ("X" "close session" gnopon/close-agent-session)
    ("L" "log command" gnopon/capture-command-log)
    ("P" "PR draft" gnopon/draft-pr-description)
    ("V" "review diff" gnopon/review-agent-diff)]
   ["Shell"
    ("c" "command runner" gnopon/command-cockpit)
    ("e" "eshell" gnopon/project-eshell)
    ("t" "terminal" gnopon/project-terminal)]
   ["Git"
    ("r" "review cockpit" gnopon/review-cockpit)
    ("g" "status" gnopon/git-status)
    ("h" "hunk diff" gnopon/git-show-hunk)
    ("G" "git project" gnopon/git-project-status)
    ("d" "GitHub dashboard" gnopon/github-dashboard)
    ("p" "GitHub PRs" gnopon/gh-pr-list)
    ("s" "GitHub PR status" gnopon/gh-pr-status)
    ("v" "GitHub PR view" gnopon/gh-pr-view-current)
    ("i" "GitHub issues" gnopon/gh-issue-list)
    ("k" "GitHub checks" gnopon/gh-pr-checks)]])

(define-key gnopon-map (kbd "SPC") #'gnopon/cockpit)
(define-key global-map (kbd "M-SPC") #'gnopon/cockpit)

(provide 'gnopon-cockpit)
;;; gnopon-cockpit.el ends here
