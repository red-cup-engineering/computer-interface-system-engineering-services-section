# Organizing with Emacs

`organizing-with-emacs` is the Emacs interface for an agentic relation engine.
The engine owns agent identities, sessions, and evidence-stream topology; Emacs
owns the useful local carriers: interactive terminals, durable persona homes,
tailing files, inspectable documents, and a navigable cockpit layout.

## Recovered capabilities

- Resolve available agents, cockpit topology, and fresh persona-bound sessions
  through the existing JSON/stdin engine protocol.
- Start each planned chat as an isolated `eat` terminal when available, or a
  built-in `term` terminal otherwise, with the plan's working directory and
  identity environment.
- Provision a character home, seed its individual memory only once, and ensure
  shared memory files exist without overwriting accumulated content.
- Make engine-declared evidence visible as live tailing file buffers, static
  world-card/document buffers, or retryable placeholders when a stream has not
  appeared yet.
- Show a session/persona glyph and colour in the relevant pane; retain session
  information locally in the chat buffer.
- Arrange the chat beside a balanced monitor column and offer `g` to reconnect
  an evidence pane and `q` to close it.

## Use

Load `init.el`, then configure `organizing-with-emacs-engine-program`,
`organizing-with-emacs-engine-entrypoint`, and
`organizing-with-emacs-engine-config`. The configured program is invoked with
its entry point and an action; the JSON configuration is supplied on standard
input. It must support the recovered actions `list-agents`,
`resolve-cockpit`, and `open-session`.

Run `M-x organizing-with-emacs-launch-cockpit`. The application asks the engine
for a fresh session plan, validates the panes needed by Emacs, then realizes the
plan. It does not hard-code agents, vendors, paths, or policy.

`docs/history/computing-with-emacs-readme.md` preserves the original protocol
and cockpit rationale.  The old Emacs realizer copies have been retired: this
application is their one live Emacs carrier.  The relation engine itself is an
external dependency; it remains the authority for topology and returns the
plans that this app realizes.
