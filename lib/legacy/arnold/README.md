# @561-group/arnold

> A generic, composable **TUI framework** over pure node (builtins only, no heavy deps). arnold lights up a **settled section** in the terminal — the terminal analogue of [`shp`](../../../computer/semantic-hypertext-packet) (the HTML projector at `computer`/L8).
> It sits ABOVE [`@561-group/computer`](../../../computer) (the EAVT substrate); `computer` never depends on it.

```sh
npm test            # 122 assertions across 6 proofs
npm run demo        # render a settled section interactively (q to quit)
```

## What it is

A clean, composable terminal-UI toolkit, plus the one boundary that makes it part of this computer: a **projector** from a settled paraconsistent section to a renderable terminal frame.

- A **screen / cell buffer** with a **diffed render** — only the cells that actually changed reach the terminal, so re-projecting a fresh frame every read stays cheap.
- **Box / flex layout** — pure Rect arithmetic (fixed + grow tracks, gaps, inset, center).
- **Core widgets** — text (wrap/align), list (selectable + scrolling), table (aligned columns), input (an editable line + a pure edit reducer), status line.
- **Raw-mode keyboard input + an event loop** — a pure key decoder (`parseKey`) wired to a raw stdin, with a chunk splitter so an arrow press stays one key while typed text streams.
- **ANSI styling** — the only module that knows the escape grammar; styles are data, so the diff reasons about the pen structurally.

The display loop is the kernel note's rhythm — **read → settle → project → loop** — with `project` being the view + the diff.

## The projector seam (and its promotion boundary)

The CRITICAL boundary is [`src/projector.mjs`](src/projector.mjs): a **pure** function

```js
project(settledSection) -> terminal frame
```

mapping a `@561-group/computer` settled section `{ affirmed, denied, contradicted }` (the output of `section(fold(...))
`) to a frame of styled rows.
It depends on **nothing** in arnold's framework — no buffer, no widgets, no I/O — so it is written to be **PROMOTED** later into `computer/` as the terminal projector, exactly the way `shp` lives in `computer/` as the HTML projector.
Until then it lives here, app-side; arnold's widgets merely DRAW the frame it returns.

### THE LAW — the four values render honestly

The projector mirrors the paraconsistent-web acceptance test: it shows the four values and **never silently picks a winner**.

| value | glyph | rendered as |
|---|---|---|
| t — affirmed | `t` | asserted |
| f — denied | `f` | denied-NOT-absent (a counter-statement: `NOT …`), never silently dropped |
| ⊤ — contradicted | `⊤` | **CONTESTED**: BOTH sides shown (`… ✗⊢ NOT …`) with BOTH witnesses surfaced |
| ⊥ — pending | `⊥` | pending / unknown (`… ?`), known-absent, not dropped |

A `⊤` cell leads the frame (most salient) and carries both faces' witnesses so any row can be asked "why?".
`section()` omits `⊥` (it carries no evidence); `projectFiber(folded)` recovers `⊥` straight from the fold's charge bits when a caller wants pending cells shown.

## Modules (import by subpath)

| subpath | what |
| --- | --- |
| `@561-group/arnold/projector` | **the seam** — `project(section)` / `projectFiber(folded)` → frame |
| `@561-group/arnold/buffer` | the cell grid + `diff(prev, next)` (the changed-cell list) |
| `@561-group/arnold/render` | the diff → minimal escape stream |
| `@561-group/arnold/layout` | `rect` / `flex` / `stack` / `inset` / `center` |
| `@561-group/arnold/widgets` | box, text, list, table, input, statusLine |
| `@561-group/arnold/input` | `parseKey` (pure) + `Keyboard` (raw-mode event loop) |
| `@561-group/arnold/ansi` | the escape-code alphabet + `sgr` styling |
| `@561-group/arnold/app` | `Screen` (terminal lifecycle + diffed paint) + `run` |
| `@561-group/arnold` | a barrel re-exporting the above |

## Demo

[`scripts/arnold.mjs`](scripts/arnold.mjs) builds a small append-only EAVT trace that includes a genuine contradiction (a claim AND its converse), settles it with `@561-group/computer`'s substrate, projects the settled section to a frame, and renders it interactively.
Keys: `↑`/`↓` move, `w` toggles the witness ("why?") panel, `t` cycles the subject, `q` quits.
The status line shows the four-value census (`t: f: ⊤: ⊥:`).

## Tests

```sh
npm test
```

- `prove-buffer` — drawing + the diff reports exactly the changed cells.
- `prove-render` — the diffed render emits a minimal escape stream (positions/pen only when needed).
- `prove-layout` — flex divides space; tracks sum exactly to the container.
- `prove-input` — the pure key decoder + chunk splitter.
- `prove-widgets` — box/text/list/table/input/status draw correctly.
- `prove-projector` — **THE LAW**: ⊤ shown contested (both sides + both witnesses), proven against a REAL settled section folded by `@561-group/computer`.

## Boundary

arnold is **userspace** (an app-making tool, like `qwzspace` is for web games), not part of `computer` proper.
The widgets / layout / input are the app-side framework; the section → frame projection is the projector.
Keeping that seam clean is what lets it be promoted into `computer/` later, the way `shp` is the HTML projector.
