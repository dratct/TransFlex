# Anthropic: per-preset effort, sampling only on models that accept it

Status: accepted — 2026-10-19

## Context

Current Claude models reject parameters that older ones required:

- `temperature` / `top_p` return 400 on Opus 4.7+, Opus 5/5.5, Sonnet 5, Fable;
  Sonnet 5.5 rejects non-default values. Haiku 4.5 and the 4.6-and-earlier
  family still accept them.
- `output_config.effort` controls thinking depth and spend on the 4.6+ family
  and the 5.x models, but errors on Haiku 4.5 and Sonnet 4.5. Opus 4.5 took it
  only behind the `effort-2025-11-24` beta header, so it is left out.
- Opus 5.5 always thinks; its effort defaults to `medium`, Sonnet 5.5's to
  `high` — slower and costlier than translation needs.

## Decision

- `AnthropicProvider` sends `temperature`/`top_p` only for model families on a
  known sampling-capable list (`AnthropicModelSupport`); IDs are reduced to
  their family first, so dated, Bedrock and Vertex forms match. Claude 4.x
  rejects both together, so a preset's explicit `top_p` replaces `temperature`.
- An ID in neither list gets neither sampling nor effort: a missing parameter
  only changes quality, a rejected one fails the request.
- With no preset `max_tokens`, the provider sends 16000 instead of 4096,
  because thinking on current models shares that budget with the answer.
- `Preset` gains an optional `effort` field (`low`…`max`). Presets saved before
  it decode with `nil`. The editor shows the picker only for the `anthropic`
  provider and models that accept effort.
- When `effort` is `nil`, the provider sends `low` to models that accept effort.
  A level the model does not accept is clamped down to the highest one it does.

## Consequences

- The capability lists are hand-maintained: a new model that drops sampling or
  adds effort needs an entry, otherwise requests fail with 400 or skip effort.
- Translation on Opus/Sonnet 5.5 defaults to fast, cheap answers; a preset that
  needs deeper reasoning must raise `effort` explicitly.

## Rejected

- Always omitting sampling for Claude: silently ignores the preset's
  temperature on Haiku 4.5 and older models.
- Sending, then retrying without sampling on 400: an extra failed request on
  every call to a current model.
- Effort only through the existing Extra Body JSON: workable but error-prone
  for users; kept as an escape hatch, not the main path.
