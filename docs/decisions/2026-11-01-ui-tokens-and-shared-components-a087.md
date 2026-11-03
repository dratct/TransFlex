# UI tokens and a small set of shared components

Status: accepted — 2026-11-01

## Context

Font sizes, corner radii, spacing and colours are written inline in every
view; only Settings shares primitives (`SettingsKit`). The design reference
in `docs/design/DESIGN.md` needs a single place in code that follows it, and
the popup's state-dependent layouts drift between opens.

## Decision

- One Swift token file holds spacing, corner radii, text styles and semantic
  colours, with the values `DESIGN.md` lists. Views use tokens or system
  styles, not literal point sizes or ad-hoc colours.
- A few shared components cover what repeats across windows: a content card,
  a footer action button with its key hint, an error banner and an empty
  state, and a searchable model picker (a popover with a search field, the
  list filtered to text models, grouped by family and sorted, and free entry
  of a model ID). Other standard controls (`Button`, `Form`, `Picker`, `TextField`) are used
  as they are, not wrapped.
- Regressions are caught by unit tests on popup state and frame on every open,
  plus a written ui-e2e flow checklist run before a UI PR.

## Consequences

- A new screen gets the shared look by using the components.
- A token value change happens in `DESIGN.md` and the token file together.
- Rejected: rules only with no token file (nothing stops drift); wrapping
  every control (heavy, duplicates the system); XCUITest (new target, needs
  Accessibility, flaky in CI).
