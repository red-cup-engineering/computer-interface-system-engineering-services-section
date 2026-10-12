# @red-cup-engineering/wheatstone

A MUD client, built over [`@red-cup-engineering/arnold`](http://127.0.0.1:4873/@red-cup-engineering/arnold)'s
diffed cell buffer. Named for Charles Wheatstone, telegraph pioneer.

```sh
npm test             # node --test tests/prove-*.mjs
npm run demo         # a scripted fake MUD server + a real socket — IAC negotiation transcript, headless
npm start            # wheatstone <host> <port>, or idle (/connect inside)
```

## What it is

- The telnet **client** side of the protocol (`src/telnet.mjs`) — option negotiation from the
  client's perspective (a server WILL, we DO/DONT), GMCP (Core.Hello handshake on up), MSDP
  (`parseMSDP`), MXP accepted as an option only (rendered as text, no markup), NAWS/TTYPE answered
  on request, ECHO flips local echo off (password-prompt convention), prompt marks (GA/EOR) flush
  the partial line, and **COMPRESS2/MCCP2** decoded through a streaming zlib inflater. Callers that
  cannot accept compression can set `acceptCompression: false` and Wheatstone answers `DONT`.
- A **pluggable carrier** (`src/world.mjs`): a "world" is an interface (`connect/send/onLine/
  onGMCP/onMSDP/onPrompt/onStatus/close/supports`). `telnetWorld` is a `node:net` socket + the
  codec above; `localWorld` is callback-backed and has no wire. Domain-specific adapters belong
  to the domain applications that consume this interface, not to Wheatstone.
- **ANSI→style parsing** (`src/ansi-text.mjs`) that folds SGR codes into an arnold style record,
  threading the pen across lines.
- An append-only **scrollback** (`src/scrollback.mjs`), a folded **world-state** model with a
  status line and an on-demand **audit trail** (`src/worldstate.mjs`), and **command-line** logic
  — history, aliases, triggers, slash-commands (`src/commands.mjs`).
- A **pure view** (`src/render.mjs`) over arnold's `flex/stack/box/text/input/statusLine`, and the
  composition root (`src/app.mjs`) that wires a world's events to that view and keypresses to
  edits.

### The wire-alphabet shim

`src/telnet.mjs` needs a small set of constants and byte helpers — the IAC/verb/option constants,
the MSDP framing bytes, `bytesOf`, `escapeIAC`, and `parseMSDP` — that historically lived in
`@561-group/tab`, a large, unpublished MUD *server* framework. That surface is small, pure, and
self-contained (about 70 lines, zero deps beyond node builtins), so it is copied into
[`src/tab-wire.mjs`](src/tab-wire.mjs), citing the exact source line range in its own header.
`src/telnet.mjs` imports from `./tab-wire.mjs`, not from `@561-group/tab` — this package has no
dependency on tab.

## World-state and the audit trail

A MUD feeds out-of-band state over GMCP (JSON packages like `Char.Vitals`, `Room.Info`) and MSDP
(var/val pairs). `WorldState` folds both into one flat model. When two sources disagree about a
field (e.g. GMCP and MSDP both report `hp`), the status line shows the latest value plainly; the
side panel's audit view (`/audit`) shows the full history of values and sources for that field on
demand.

## The telnet negotiation demo

[`bin/demo-telnet.mjs`](bin/demo-telnet.mjs) drives the real client codec (`src/telnet.mjs`)
against a small, purpose-built [`bin/lib/fake-mud-server.mjs`](bin/lib/fake-mud-server.mjs) over an
actual local TCP socket — no live MUD, no terminal required. It prints the exact byte-level IAC
negotiation transcript both sides exchanged:

```
── wheatstone demo-telnet: IAC negotiation transcript (scripted fake server, real socket) ──

  S→C  IAC WILL GMCP
  S→C  TEXT "Connected to the test server.\r\n"
  C→S  IAC DO GMCP
  C→S  IAC SB GMCP "Core.Hello {\"client\":\"wheatstone\",\"version\":\"0.3.0\"}" IAC SE
  C→S  IAC SB GMCP "Core.Supports.Set [\"Char 1\",\"Room 1\",\"Comm 1\"]" IAC SE
  C→S  TEXT "look\r\n"
  S→C  IAC SB GMCP "Char.Vitals {\"hp\":99,\"maxhp\":100}" IAC SE
  S→C  TEXT "You see the test room.\r\n"
```

The fake server pushes its GMCP update only once it observes the client's `IAC DO GMCP` answer on
the wire, never on a fixed timer.

## The `bin/wheatstone.mjs` CLI

```
wheatstone <host> <port>     connect to host:port over telnet
wheatstone                   start idle (/connect host port inside)
```

In-app: `/help`, `/connect host port`, `/quit`, `/alias`, `/trigger`, `/audit`. Keys: PgUp/PgDn
scroll, Ctrl-L to tail, Ctrl-B side panel, Up/Down history, Ctrl-C quit.

## Tests

```sh
npm test
```

Runs via node's own test runner (`node --test tests/prove-*.mjs`):

- `prove-telnet-client` — option negotiation from the client side, GMCP/MSDP parse, prompt marks,
  IAC escaping, split-chunk COMPRESS2/MCCP2 decompression, and the explicit opt-out path.
- `prove-ansi-text` — SGR parsing into arnold style records, pen threading across lines.
- `prove-scrollback` — the append-only ring, paging, the pen-threading integration.
- `prove-commands` — history, alias expansion, trigger matching, input classification.
- `prove-worldstate` — GMCP/MSDP folding into one flat model, and the audit trail: two disputing
  sources for `hp` both appear in the audit view, only the latest in the status bar.
- `prove-render` — the pure view proven against a real arnold `Buffer` (not a mock): reads cells
  back, confirms ANSI became `style.fg`, confirms no raw ESC bytes leak into the grid.
- `prove-smoke` — the connect→render→input loop, both over a mock world and over a real TCP socket
  against the scripted fake server (`bin/lib/fake-mud-server.mjs`).
- `prove-telnet-transcript` — a full scripted IAC negotiation + GMCP exchange over a real socket,
  with every message's exact bytes (decoded by the same `annotate()` the demo prints) and every
  ordering constraint the implementation actually guarantees checked individually against the wire
  itself — not the app's rendered result.

## Modules (import by subpath)

| subpath | what |
| --- | --- |
| `@red-cup-engineering/wheatstone/telnet` | the client-perspective telnet codec |
| `@red-cup-engineering/wheatstone/tab-wire` | the local wire-alphabet shim (see above) |
| `@red-cup-engineering/wheatstone/world` | the pluggable carrier seam — `telnetWorld` / `localWorld` |
| `@red-cup-engineering/wheatstone/ansi-text` | SGR → arnold style parsing |
| `@red-cup-engineering/wheatstone/scrollback` | the append-only output-pane model |
| `@red-cup-engineering/wheatstone/worldstate` | GMCP/MSDP folding, status line + audit trail |
| `@red-cup-engineering/wheatstone/commands` | history, aliases, triggers, input parsing |
| `@red-cup-engineering/wheatstone/render` | the pure view over arnold's widgets |
| `@red-cup-engineering/wheatstone/app` | `Wheatstone` (composition root) + `run` |
| `@red-cup-engineering/wheatstone` | a barrel re-exporting the above |

Every subpath ships a hand-written `.d.ts` alongside its `.mjs`.

## Known gaps

- MXP is accepted as an option but rendered as plain text; no markup interpretation.
