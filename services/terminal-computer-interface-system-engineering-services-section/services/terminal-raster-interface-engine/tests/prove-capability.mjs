// prove-capability — the kitty | sixel | none detection, including the GRACEFUL FALLBACK chain.
// Proves: kitty signatures win, sixel-capable programs fall to sixel, an unknown env yields the text
// fallback ("none"), an explicit override is honored, and probe() reports "none" for a non-TTY
// stream (piped/redirected output) regardless of env.

import { detectFromEnv, probe, ENCODERS } from "../src/capability.mjs";
import { ok, eq, done } from "./_harness.mjs";

eq(ENCODERS, ["kitty", "sixel", "none"], "the encoder ladder is kitty -> sixel -> none");

// === kitty signatures =========================================================================
eq(detectFromEnv({ KITTY_WINDOW_ID: "1" }).encoder, "kitty", "$KITTY_WINDOW_ID detects kitty");
eq(detectFromEnv({ TERM: "xterm-kitty" }).encoder, "kitty", "TERM=xterm-kitty detects kitty");
eq(detectFromEnv({ TERM_PROGRAM: "ghostty" }).encoder, "kitty", "TERM_PROGRAM=ghostty detects kitty");

// === sixel programs ===========================================================================
eq(detectFromEnv({ TERM_PROGRAM: "mlterm" }).encoder, "sixel", "mlterm detects sixel");
eq(detectFromEnv({ TERM: "foot" }).encoder, "sixel", "TERM=foot detects sixel");

// === the text fallback ========================================================================
eq(detectFromEnv({ TERM: "dumb" }).encoder, "none", "an unknown terminal falls back to none (text)");
eq(detectFromEnv({}).encoder, "none", "an empty env falls back to none");

// === explicit override ========================================================================
eq(detectFromEnv({ DALESKE_ENCODER: "sixel", KITTY_WINDOW_ID: "1" }).encoder, "sixel",
  "DALESKE_ENCODER overrides even a kitty signature");
eq(detectFromEnv({ DALESKE_ENCODER: "bogus" }).encoder, "none",
  "an invalid override is ignored and detection proceeds (here: none)");

// === probe gates on TTY =======================================================================
const ttyKitty = probe({ isTTY: true }, { KITTY_WINDOW_ID: "1" });
eq(ttyKitty.encoder, "kitty", "probe on a TTY with a kitty env detects kitty");
ok(ttyKitty.tty, "probe reports tty:true for a TTY stream");

const piped = probe({ isTTY: false }, { KITTY_WINDOW_ID: "1" });
eq(piped.encoder, "none", "probe on a NON-tty stream is none even with a kitty env (no terminal to draw to)");
ok(!piped.tty, "probe reports tty:false for a piped/redirected stream");

done("prove-capability");
