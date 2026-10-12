# @red-cup-engineering/daleske

A raster terminal-interface engine. Daleske owns RGBA framebuffers, changed-tile diffs, Kitty and
Sixel encoders, terminal capability classification, blits, and `PixelScreen`. Its lifecycle and
input are supplied by `@red-cup-engineering/terminal-user-interface-engine`.

It has no domain model. Systems supply framebuffers for Daleske to encode and display. The EAVT
settled-section raster projection and its interactive demonstration live in
`@red-cup-engineering/eavt-terminal-projectors/raster`.

## Public modules

| subpath | capability |
| --- | --- |
| `@red-cup-engineering/daleske/framebuffer` | RGBA framebuffer and tile diff |
| `@red-cup-engineering/daleske/kitty` | Kitty graphics encoding |
| `@red-cup-engineering/daleske/sixel` | Sixel encoding |
| `@red-cup-engineering/daleske/capability` | raster capability classification |
| `@red-cup-engineering/daleske/blit` | changed tiles to graphics bytes |
| `@red-cup-engineering/daleske/screen` | `PixelScreen` lifecycle adapter |
