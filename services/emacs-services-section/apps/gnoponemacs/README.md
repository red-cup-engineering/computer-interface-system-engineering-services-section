# GnoponEmacs

GnoponEmacs is the human-controlled knowledge, research, and development
application. It is a project-aware Emacs cockpit: people inspect evidence,
write and link records, decide what to run, and explicitly open any agent
session.

## Recovered application capabilities

- Markdown-native project knowledge: task files, specifications, plans, ADRs,
  RFCs, backlinks, context files, predication cells, RDF/Turtle export, SHACL
  scaffolds, proof obligations, and capability audits.
- Project engineering: workspace tabs and dashboards, project terminals and
  safe commands, Git/Magit/Forge and diff-hunk workflows, programming modes,
  Eglot/Flymake diagnostics, symbol navigation, code actions, compilation,
  tests, HTTP/JSON tools, and review/PR packets.
- Human-controlled agent work: explicit context bundles, project-scoped Codex
  terminals, session records and handoffs, command logs, evidence capture,
  patch review, commit/PR drafts, safety boundaries, and local MCP-style
  manifests.
- InfoPonEmacs recordkeeping: configurable Org agenda and inbox capture,
  citation metadata, generic Org publishing with semantic drawers and
  sitemaps, linked Org records, typed communication/definition/project/
  reference/private/contact capture, dailies, normalized slugs and backlink
  reports, ledger editing, typed reading and inventory records, reusable
  project/license metadata, corpus dictionaries and prompts, focused/pretty
  writing, and optional Org-roam graph, Org-transclusion, and Org-drill
  carriers.
- A discoverable control center, transient cockpit/action palette, completion,
  navigation, editing assistance, persistence, diagnostics, security review,
  and startup/performance reporting.

## Start

Load early-init.el and init.el as the application configuration. The C-c g
prefix organizes its human-facing commands. Gnopon loads without network
access; optional packages improve the relevant carrier when installed.

The agent relation cockpit is explicit. Configure
gnopon-cockpit-engine-program and gnopon-cockpit-engine-entrypoint, then run
M-x gnopon/cockpit-launch. Set `gnopon-cockpit-config-file` to a project- or
personal-service-owned copy of `cockpit.example.json`; Gnopon passes that data
and its project to organizing-with-emacs, which obtains and realizes a fresh
engine-owned session plan. Loading Gnopon does not discover or start an agent
harness.

Set gnopon-records-directory to the human or group record corpus before using
the agenda, capture, or linked-record commands. Publication projects are data
in gnopon-org-publish-projects rather than paths embedded in application code.
The recovered record commands live under C-c g r: agenda, capture, linked
record find/insert/daily capture, graph, ledger, publishing, practice, and
transclusion.  `gnopon/import-legacy-state` is an explicit, non-overwriting
one-time import for a previous shared `var/` state directory; normal startup
does not read it.

## InfoPonEmacs synthesis boundary

The five distinct InfoPonEmacs documents and the two personal Emacs copies
were read as evidence of effects, not configuration templates.  Their generic
effects now have a carrier in GnoponEmacs:

| Recovered effect | GnoponEmacs carrier |
| --- | --- |
| Org agenda, capture, logs, Babel, citation metadata | `gnopon/org-configure`, `gnopon/org-open-agenda`, `gnopon/org-capture-record` |
| HTML drawers, sitemaps, publication | `gnopon/org-html-format-drawer`, `gnopon/org-publish-format-sitemap`, `gnopon/org-publish` |
| Roam records, typed captures, dailies, Unicode slugs, backlinks | `gnopon/org-roam-*`, `gnopon/org-slugify`, `gnopon/org-roam-backlinks-markdown` |
| Graph, transclusion, spaced repetition, ledger files | `gnopon/org-roam-open-graph`, `gnopon/org-enable-transclusion`, `gnopon/org-practice-records`, `gnopon/open-ledger` |
| Screenshot attachment, paste publishing, readability, spell checking | `gnopon/org-attach-screenshot`, `gnopon/org-paste-*`, `gnopon/org-writing-statistics`, `gnopon/org-enable-spellcheck` |
| Reading queue, inventory, dictionary, prompts, project license prose | `gnopon/record-add-reading`, `gnopon/record-add-inventory-item`, `gnopon/record-insert-definition`, `gnopon/record-insert-fortune`, `gnopon/record-insert-project-license` |
| Agenda deadlines/TODO stages, Org links/refiles/clocks, focused/pretty writing | `gnopon-org-*` customization, `C-c g r L/R/C/O`, `gnopon/org-enable-focused-writing`, `gnopon/org-enable-pretty-outline` |
| Terminal completion and editable search results | optional `corfu-terminal` and `wgrep` integrations |

Email address, personal notes, private capture targets, bibliography paths,
website hierarchy, stylesheets, publication preambles, persona topology, and
the archived records themselves are intentionally not application defaults.
They now live in the personal text-triage corpus at
`emsenn-services-section/content/text/triage/emacs-services-section/`; no
personal content was discarded or copied into this app.  The retired Gnopon
implementation's technical rationale remains in `docs/history/legacy-readme.md`.
