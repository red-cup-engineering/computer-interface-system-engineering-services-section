# @red-cup-engineering/eavt-terminal-projectors

Domain projections from an EAVT settled section into terminal cell frames and raster framebuffers.

This package owns the EAVT-specific interpretation: affirmed, denied, contradicted, and pending
predications become visible rows or bands. It owns neither terminal lifecycle nor rendering:
`@red-cup-engineering/arnold` composes and renders cell scenes, while
`@red-cup-engineering/daleske` encodes and blits raster frames.

```js
import { projectFiber } from "@red-cup-engineering/eavt-terminal-projectors/cell";
import { project } from "@red-cup-engineering/eavt-terminal-projectors/raster";
```
