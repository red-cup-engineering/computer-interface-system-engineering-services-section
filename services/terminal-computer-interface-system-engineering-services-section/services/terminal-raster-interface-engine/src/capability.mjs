// capability — Daleske's raster vocabulary over the shared terminal capability observation. This
// module preserves the public encoder-shaped result and DALESKE_ENCODER override, but the actual
// terminal classification lives in terminal-user-interface-engine.
//
//   detectFromEnv(env)  — a PURE classification from environment variables alone (no I/O, testable).
//                         It reads the signals a terminal advertises about itself ($TERM,
//                         $TERM_PROGRAM, $KITTY_WINDOW_ID, $COLORTERM) and names the best encoder.
//   probe(stream, env)  — the live form: env first, and if inconclusive it could query the terminal
//                         (a kitty/sixel capability handshake) — here it just trusts env + a tty
//                         check, staying dependency- and side-effect-light.
//
// The result is one of: "kitty" | "sixel" | "none". "none" means a renderer must fall back to a
// TEXT representation (a caller can present a textual fallback for its own frame).

import {
  GRAPHICS_PROTOCOLS,
  detectTerminalCapabilities,
  probeTerminal,
} from "@red-cup-engineering/terminal-user-interface-engine";

export const ENCODERS = GRAPHICS_PROTOCOLS;

// detectFromEnv(env) -> { encoder, why } — PURE. `env` is a plain object (default process.env).
// `why` names the signal that decided it, so a status line / test can explain the choice.
export function detectFromEnv(env = process.env) {
  const result = detectTerminalCapabilities(env, {
    graphicsOverride: env.DALESKE_ENCODER,
    overrideName: "DALESKE_ENCODER",
  });
  return { encoder: result.graphics, why: result.why };
}

// probe(stream, env) -> { encoder, why, tty } — the live form used by the screen. If the stream is
// not a TTY there is no terminal to draw to, so the encoder is "none" regardless of env (e.g. a
// piped or redirected stdout). Otherwise it defers to detectFromEnv. Kept side-effect-free so it is
// safe to call before any terminal setup.
export function probe(stream = process.stdout, env = process.env) {
  const result = probeTerminal(stream, env, {
    graphicsOverride: env.DALESKE_ENCODER,
    overrideName: "DALESKE_ENCODER",
  });
  return { encoder: result.graphics, why: result.why, tty: result.tty };
}
