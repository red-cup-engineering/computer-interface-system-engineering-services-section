// render.d.ts — hand-written types for src/render.mjs.

import type { Buffer as ABuffer } from "@red-cup-engineering/arnold/buffer";
import type { Rect } from "@red-cup-engineering/arnold/layout";
import type { Scrollback } from "./scrollback.mjs";
import type { WorldState } from "./worldstate.mjs";
import type { StatusEvent } from "./world.mjs";

export interface ViewState {
  scrollback: Scrollback;
  world: WorldState;
  input: { value: string; cursor: number };
  status: StatusEvent;
  showPanel: boolean;
  showAudit: boolean;
  prompt: string;
  target?: string;
}

export function view(state: ViewState): (buf: ABuffer, rect: Rect) => void;
