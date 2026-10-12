# shell

The first **userspace interface app** for the 561-group computer: the **settling shell / REPL** — the way you actually *use* this computer.
It is NOT part of `computer/` proper; it is a program that runs **on** the kernel + tools.
It is a **thin driver** — all logic lives in `@561-group/computer`'s tools (`substrate`, `distribution/governance`, `process-runtime/allocation`, `principal`); the shell only **reads / appends / settles / projects** EAVT rows over a trace root.

## The loop is read → SETTLE → project → loop (not read-eval-print)

A Unix REPL is read → eval → print.
This computer's `eval` is **aperiodic settling** — fold the trace to a Knaster–Tarski fixed point — so its natural shell is **read → settle → project → loop**:

- a **command is a PREDICATION** appended to the trace (`believe alice located-in kitchen`);
- the world **SETTLES** (`substrate.settle` to a fixed point, folding under a converse map);
- the **output** is the projected settled **section**, with **⊤ SHOWN** (contested facts displayed, *both* witnesses) and **⊥ shown as pending**;
- the **prompt** shows your current standing folded **live** (`alice t >`) — recomputed every loop, a continuous-auth fold, *not* a session-bit.

The medium is **rows / charges / settled sections**, not text.
The verbs compose computer's tools like coreutils over the trace; the "pipe" is the **fold/settle**.

## Run it

```
node scripts/shell.mjs [trace.jsonl] [--as <principal>] [--half-life <n>]
```

`trace.jsonl` is the append-only EAVT world (default `./world.jsonl`).
`--as` starts the session acting AS a principal — but grants **no bit**: standing is always the continuous fold.
`--half-life` sets the decay window the continuous-auth fold reads.

## Verbs

| verb | maps to | does |
|---|---|---|
| `believe <s> <p> <o>` | append + `substrate.settle` | append a predication, then settle + project. `<p>` vs `not-<p>` rises to **⊤** (both witnesses), never an overwrite |
| `settle` / `section <s>` | `substrate.settle` + `section` | fold the subject, project affirmed / ⊤ / pending |
| `relate <p> <o>` / `of <s> <p>` | `substrate.relate` / `relateFrom` | the relational reads |
| `login <principal> [nonce]` | `principal.present` + `authenticated` | a **challenge-response PLAY** — the surviving strategy is authenticated (no bit) |
| `who` | `principal.authenticated` | your current standing, **folded fresh** (continuous-auth) |
| `whois <principal>` | `principal.whois` | fold the identity cell; a recognition dispute is **⊤, HELD**, both witnesses |
| `recognize <principal> [not] <as>` | `principal.recognize` / `dispute` | web-of-trust identity evidence |
| `may <action> [principal] [--regime <r>]` | `principal.may` → `governAction` | the authority fold → **FOUR** (t/f/⊤/⊥), never a boolean. `--regime contrarian` lets contested authority surface as ⊤; `consensus-by-withdrawal` yields ⊥ |
| `can <action> [principal]` | `principal.can` | the object-capability limb — FOUR, ⊤ when granted+revoked |
| `grant` / `revoke <principal> <action>` | `principal.grant` / `revoke` | capability-as-charge; grant + revoke → **⊤** (held), never dropped |
| `affirm` / `withhold <principal> <action>` | `principal.recognizesAuthority` / `withholdsAuthority` | recognition-graph authority evidence the `may` fold reads |
| `trace [subject]` | `readTrace` | dump the raw rows — evidence is linear |

## The law it honors

Paraconsistent (⊤ HELD, surfaced, never resolved to a winner — `believe` and `may` both show it); append-only (a command appends; nothing overwrites; the trace keeps every witness); continuous-fold not session-bit (`who` / the prompt re-fold standing every loop and decay toward ⊥); capability not credential (`may`/`can` are FOUR over held charges via `governAction`).
If you reach for a password-checks-out boolean or an overwrite, you dropped into the shadow.

## A note on the `principal` import

`computer/principal` landed but its package exports are **not yet registered**, so `import "@561-group/computer/principal"` does not resolve here yet.
The shell reaches it by **relative path through one seam**, [`scripts/principal.mjs`](scripts/principal.mjs); when computer registers the export (intended: `"./principal"` → `principal/scripts/principal-barrel.mjs`, `"./principal/tool"` → `principal/scripts/principal.mjs`), that one file becomes a re-export by name and nothing else in the shell changes.

## Tests

```
node tests/shell.test.mjs
```

They prove: appending a predication then settling **shows** the new fact; a contradicting predication shows **⊤** (both witnesses), not an overwrite; acting beyond a principal's capability surfaces the governed **FOUR** result (f denied / ⊥ no-basis / ⊤ contested), never a boolean; identity folds and a recognition dispute is held as ⊤; authentication is a continuous fold that decays to ⊥ (no session-bit).
