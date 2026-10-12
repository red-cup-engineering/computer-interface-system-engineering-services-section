// ansi-text — parse a MUD output line that carries ANSI SGR color codes into a list of STYLED
// SEGMENTS arnold can draw. Arnold's buffer stores a plain glyph + a structured style record per
// cell (it strips raw escapes); it does NOT interpret embedded SGR. MUD text, on the other hand,
// is ANSI-colored inline (the server writes "\x1b[1;31mYou are bleeding!\x1b[0m"). So before we
// hand a MUD line to arnold, we PARSE the SGR runs here into { text, style } segments whose style
// is an arnold style record ({ fg, bg, bold, ... }) — the same shape arnold/ansi.sgr() serializes.
//
// We cover the SGR codes a MUD actually uses: reset (0), bold (1), dim (2), italic (3), underline
// (4), inverse (7), strike (9); the 16 named fg/bg (30-37/90-97, 40-47/100-107); 256-color
// (38;5;n / 48;5;n) and truecolor (38;2;r;g;b / 48;2;r;g;b). Unknown codes are skipped. The parse
// is pure (string in, segments out) so it is trivially testable.

const ESC = "\x1b";

// the named-color index → arnold color name (arnold/ansi maps these back to 30..37 / 90..97).
const NAMES = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];

// applySGR(style, params) — fold one SGR escape's numeric params into a style record, returning the
// NEW style. params is an array of numbers (the bits between CSI and 'm'). Handles the multi-number
// 256/truecolor forms by consuming ahead.
export function applySGR(style, params) {
  let s = { ...style };
  for (let i = 0; i < params.length; i++) {
    const p = params[i];
    if (p === 0) { s = {}; }
    else if (p === 1) s.bold = true;
    else if (p === 2) s.dim = true;
    else if (p === 3) s.italic = true;
    else if (p === 4) s.underline = true;
    else if (p === 7) s.inverse = true;
    else if (p === 9) s.strike = true;
    else if (p === 22) { delete s.bold; delete s.dim; }
    else if (p === 23) delete s.italic;
    else if (p === 24) delete s.underline;
    else if (p === 27) delete s.inverse;
    else if (p === 29) delete s.strike;
    else if (p >= 30 && p <= 37) s.fg = NAMES[p - 30];
    else if (p >= 90 && p <= 97) s.fg = `bright-${NAMES[p - 90]}`;
    else if (p === 39) delete s.fg;
    else if (p >= 40 && p <= 47) s.bg = NAMES[p - 40];
    else if (p >= 100 && p <= 107) s.bg = `bright-${NAMES[p - 100]}`;
    else if (p === 49) delete s.bg;
    else if (p === 38 || p === 48) {
      const where = p === 38 ? "fg" : "bg";
      const mode = params[i + 1];
      if (mode === 5) { s[where] = params[i + 2] & 255; i += 2; }       // 256-color index
      else if (mode === 2) { s[where] = { r: params[i + 2] & 255, g: params[i + 3] & 255, b: params[i + 4] & 255 }; i += 4; } // truecolor
      else i += 1;
    }
    // any other SGR code: ignored
  }
  return s;
}

// parseAnsi(line, initialStyle) — split a line into [{ text, style }, ...], applying SGR runs. The
// returned style records are arnold style shapes. A trailing unstyled remainder still produces a
// segment. `initialStyle` lets a caller carry a pen across lines (MUD color often spans newlines);
// the function also RETURNS the final style so the caller can thread it to the next line.
const SGR_RE = /\x1b\[([0-9;]*)m/g;

export function parseAnsi(line, initialStyle = {}) {
  const segments = [];
  let style = { ...initialStyle };
  let last = 0;
  SGR_RE.lastIndex = 0;
  let m;
  const text = String(line);
  while ((m = SGR_RE.exec(text)) !== null) {
    if (m.index > last) segments.push({ text: text.slice(last, m.index), style });
    const params = m[1] === "" ? [0] : m[1].split(";").map((n) => parseInt(n, 10) || 0);
    style = applySGR(style, params);
    last = SGR_RE.lastIndex;
  }
  if (last < text.length) segments.push({ text: text.slice(last), style });
  // also strip any non-SGR escape sequences (cursor moves, etc.) that the MUD might emit, from the
  // segment text — arnold strips escapes per-cell anyway, but we keep the visible width honest.
  for (const seg of segments) seg.text = stripNonSGR(seg.text);
  return { segments, style };
}

// stripNonSGR — drop any leftover CSI sequences (non-'m') from already-SGR-split text.
const NON_SGR_RE = /\x1b\[[0-9;?]*[A-LN-Za-ln-z]/g;
function stripNonSGR(s) { return s.replace(NON_SGR_RE, ""); }

// hasAnsi(line) — does a line carry any SGR? (cheap check for callers that want to skip parsing.)
export function hasAnsi(line) { return line.includes(ESC + "["); }
