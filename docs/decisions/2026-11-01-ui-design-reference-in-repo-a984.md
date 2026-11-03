# UI design reference lives in the repository

Status: accepted — 2026-11-01

## Context

Each screen sets its own font sizes, corner radii and colours; only Settings
shares primitives (`SettingsKit`). The popup, Settings, Welcome and History
windows drift apart, and contributors have no reference for how a new state
should look. The reference could live in a hosted design tool or next to the
code.

## Decision

- The design reference lives in `docs/design/`: `DESIGN.md` holds the tokens
  (colour, type, spacing, radius, materials) and the rules for each screen and
  state; static HTML mockups beside it show every screen in every state.
- `DESIGN.md` is the source the Swift tokens and shared components follow.
  A change to the look changes `DESIGN.md` and the Swift code in the same PR.
- No hosted design artifact (claude.ai, Figma) is the source of truth.

## Consequences

- The reference ships with the open-source repo and is reviewed in PRs.
- Mockups are plain HTML: opening one needs a browser, and there is no shared
  canvas for commenting.
