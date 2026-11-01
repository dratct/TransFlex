# History stores each translation's cost when it is made

Status: accepted — 2026-11-01

## Context

History shows what each translation cost and a daily total. `history_entry`
keeps only `token_count`, the sum of input and output tokens, and
`CostTable` prices input and output separately for a short, hand-kept list
of models. A price recomputed when History is opened would be wrong (no
input/output split) and would move whenever the price table changes.

## Decision

- Migration `v2` adds `input_tokens INTEGER`, `output_tokens INTEGER` and
  `cost_usd REAL` to `history_entry`, all nullable.
- The recorder writes the same estimate the popup shows, from
  `CostTable.estimate`, at the time of the translation. A model with no price
  stores `NULL` cost; History shows "price unknown" and leaves it out of the
  daily total.
- Rows saved before `v2` keep `NULL` in the new columns.

## Consequences

- Costs in History never change after the fact, even when prices do.
- The daily total covers priced models only; History says so when some
  entries are unpriced.
- The JSON export gains `inputTokens`, `outputTokens` and `costUSD`.

## Rejected

- Recomputing from `token_count` on display: no input/output split, and old
  entries would follow today's prices.
