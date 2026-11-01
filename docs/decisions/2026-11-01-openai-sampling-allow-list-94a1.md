# OpenAI: sampling only on models that accept it

Status: accepted — 2026-11-01

## Context

`OpenAIProvider` sent every preset's `temperature` (and `top_p` when set) to
`v1/chat/completions`. Reasoning models reject a non-default value:
`gpt-6-luna` answers 400 `Unsupported value: 'temperature' does not support
0.3 with this model. Only the default (1) value is supported.` The popup
showed only "Provider issue. Try again.", because every status other than
401, 403 and 429 became `LLMError.server` and the body was dropped.

## Decision

- Follow the Anthropic rule (`2026-10-19-anthropic-effort-and-sampling-290c`):
  `OpenAIModelSupport` sends `temperature`/`top_p` only to IDs starting with
  `gpt-3.5`, `gpt-4` or `chatgpt-4o`. Any other ID (o-series, GPT-5 and later,
  unknown) gets neither.
- `OpenAICompatibleProvider` keeps sending sampling: its endpoints serve
  arbitrary local or proxied models, which mostly accept it.
- A 4xx `LLMError.server` shows the provider's `error.message` in the popup
  (cut to 300 characters); 5xx keeps "Provider issue. Try again."

## Consequences

- The prefix list is hand-maintained; a future sampling-capable family needs
  an entry, otherwise its preset temperature is silently ignored.
- `max_tokens` is still sent as is. Reasoning models may require
  `max_completion_tokens`; not verified, and no shipped preset sets it.

## Rejected

- Retrying without sampling after a 400: an extra failed request on every call
  to a current model.
- Matching reasoning models by name (`o`, `gpt-5`, …): a new family would fail
  until listed, where the allow-list only loses tuning.
