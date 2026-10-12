import type { World } from "@red-cup-engineering/wheatstone/world";
import type { Wheatstone, WheatstoneOpts } from "@red-cup-engineering/wheatstone/app";

export interface OpenAiAgentTuiOptions extends WheatstoneOpts {
  provider: string;
  model?: string;
  system?: string;
  agent?: string;
  maximumOutputTokens?: number;
  resourceRoot?: string;
  request?: typeof fetch;
  world?: World;
}

export function openAiAgentWorld(options: OpenAiAgentTuiOptions): World;
export function runOpenAiAgentTui(options: OpenAiAgentTuiOptions): Wheatstone;
