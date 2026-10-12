# @emsenn/computing-with-emacs

Computing with Emacs as one boundary system, greenfielded in the `@emsenn/relating` idiom.

The domain is a **cockpit**: a live chat pane driving an external agent (a Claude CLI, a Codex CLI, an OpenAI TUI) surrounded by **monitor panes** that stream the context injections, hook calls, and messages flowing past it — so a human watches exactly what the agent is being fed and how the harness reacts.

The cockpit topology is **data**, never code:

- `AgentEndpoint` — the chat pane: the program to run, its args, the streams to watch beside it.
- `StreamSource` — a monitor pane: a file to tail (or command to stream) carrying context injections, hook calls, or messages.
- `CockpitConfig` — the one environment binding, supplied as a JSON document on the dispatcher's stdin.
  Nothing in this package names a 561 path or command.
- `CockpitPlan` — the resolved read-model: a chat pane and its monitor panes, every path made absolute, ready for any realizer.

## Sessions are characters

Each cockpit launch is a **session**, not a return to one shared "claude".
A session binds an agent to a `Persona` — a name, colour, and glyph assigned deterministically from the session id (so a session always wears the same face) and drawn from a pool that the config may override.
The session namespaces its own buffers, exports its identity as env (`CWE_SESSION`, `CWE_PERSONA`, …) to the chat process, and gets a leading **world pane** holding its persona card — its own sense of who it is.
Two Claude sessions are two distinct characters side by side, never one lump.

The chat pane renders through the rich `eat` terminal when available (truecolor, full-screen TUIs like Claude and Codex render correctly), falling back to `term`.

### Discrete embodiment via the agent's own capabilities

When an agent declares an `identity`, a session is embodied as a discrete, persistent character using the agent's *upstream-native* capabilities rather than anything bespoke.
For Claude Code the config maps:

- `--session-id {session}` — the cockpit session id **is** the Claude session id, so the persona, the cockpit, and the manifold all key the same world.
- `--name {persona}` — the character's display name in Claude's own UI / `/resume`.
- `--append-system-prompt {embodiment}` — the character's embodiment prompt.
- `CLAUDE_CONFIG_DIR` → `{cwd}/.../characters/{slug}` — the character's **own** data and memory home (history, todos, and a `CLAUDE.md`).

The character's `CLAUDE.md` is seeded once (never clobbered, so its memory accumulates across that character's sessions) and `@imports` the configured `sharedMemory` — the deeper memory every character shares.
So each session is its own self with its own data, while still sharing memory with its siblings.
The realizer materializes the home and seeds before launch.
Agents without an `identity` (e.g. a plain Codex) simply skip embodiment.

## One dispatcher, four transports

Each operation is registered once as a `relating` **action** (a cocone leg); `induceBins` projects the whole module to CLI, OpenAPI, MCP, and web.
The `cwe` binary reads the config on stdin and runs the pure morphism; `cwe-serve` binds the same actions to HTTP.
Every scripted invocation is witnessed as EAVT when `CWE_DATA` is set.

```sh
echo "$CONFIG" | cwe list-agents
echo "$CONFIG" | cwe resolve-cockpit --agent claude --cwd /repo
echo '{"initDirectory":"/pkg","cwd":"/repo","eval":["(cwe-launch-cockpit)"]}' | cwe emacs-invocation
```

## The Emacs realizer

`emacs/cwe-cockpit.el` is the generic consumer.
Set `cwe-cli` to the built `dist/scripts/cwe.mjs` and `cwe-config-path` to a cockpit config, then `M-x cwe-launch-cockpit` offers the interactive agent menu, resolves a window plan through the bin, and lays out the live chat pane beside the configured monitor panes.
Point it at a different config and it drives a different environment unchanged — the elisp holds no environment knowledge.

Use the package `exports` map and source JSDoc as the normative API.
