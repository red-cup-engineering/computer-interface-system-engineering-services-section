# Emacs services section

Emacs-facing applications live in `apps/`.  Each application realizes one
distinct way of using Emacs; they do not share a configuration framework.

- `apps/vibemacs` — agent-controlled knowledge and research-and-development
  work in a project.
- `apps/organizing-with-emacs` — Emacs interface to the agentic-relation
  engine: relation plans become isolated terminals and inspectable evidence
  panes.
- `apps/gnoponemacs` — human-controlled knowledge, recordkeeping, research,
  and development, including explicit use of the relation cockpit.

All three application roots are canonical.  The direct Vibemacs,
computing-with-Emacs, GnoponEmacs, InfoPonEmacs, and personal-Emacs runtime
roots have been retired after their effects were recomposed.  Their personal
records and literate configurations moved to the owning personal text-triage
corpus; each application's non-personal technical history stays in its
`docs/history/` directory.  The former `lib/legacy` collection has been
retired: its remaining raw record corpus is in personal text triage, and its
historical code effects have been recomposed into the three applications.
