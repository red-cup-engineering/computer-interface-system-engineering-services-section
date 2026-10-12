# @red-cup-engineering/openai-agent-tui

The terminal consumer for a persistent OpenAI-compatible conversation. It composes:

- `@red-cup-engineering/wheatstone` for the interactive terminal and local-world carrier;
- `@red-cup-engineering/computer-inference-engine` for provider admission, credentials, rate policy, and recorded exchanges.

It does not implement a second terminal engine or a second OpenAI client. Each reply remains in
the conversation, is rendered into Wheatstone's scrollback, and leaves its provider/model/exchange
trace in the carrier's `Agent.State` packet.

```sh
openai-agent-tui --provider openrouter
openai-agent-tui --provider ollama-local --model qwen3:1.7b
```

`--system`, `--session`, `--max-output-tokens`, and `--resource-root` correspond to the
conversation identity, output bound, and existing inference-engine resource root.
