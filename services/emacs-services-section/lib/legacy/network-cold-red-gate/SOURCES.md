# cold-red-gate source capture

Captured 2026-07-29 over the configured SSH transport from the `emsenn`
account on `cold-red-gate` (`45.76.19.133`). Both paths were part of the
`/home/emsenn/561-group` checkout, whose remote was
`git@github.com:emsenn/561-group.git`.

| Captured path | Collection path | Excluded generated material |
| --- | --- | --- |
| `apps/gnoponemacs` | `gnoponemacs/` | ELN cache, ELPA package store, `var/`, Node dependencies, quickstart cache, compiled `.elc` files |
| `lib/computing-with-emacs` | `computing-with-emacs/` | Node dependencies and `dist/` build output |

This is a source snapshot, not a deployment export. It preserves the files
needed to study and recover the Emacs-facing work without carrying host-local
runtime caches.
