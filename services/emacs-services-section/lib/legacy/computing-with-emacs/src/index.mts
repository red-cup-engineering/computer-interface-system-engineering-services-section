/**
 * @emsenn/computing-with-emacs — computing with Emacs as one boundary system.
 *
 * The domain is the *cockpit topology*: a chat pane driving an external agent
 * (Claude CLI, Codex CLI, OpenAI TUI) and monitor panes streaming the context
 * injections, hook calls, and messages that flow beside it. The topology is data
 * (`CockpitConfig` → `CockpitPlan`); the same morphisms are projected to CLI,
 * OpenAPI, MCP, and web by `@emsenn/relating`'s `induceBins`, and
 * realized into Emacs windows by the elisp consumer shipped under `emacs/`.
 *
 * Nothing here is 561-specific. The agents, the stream paths, the default — all
 * arrive as a config document on the dispatcher's stdin.
 */
export * as cockpit from "./cockpit/index.mjs";
export { actions } from "./actions.mjs";
