# Replace Selection: visible progress, and Esc held while it runs

Status: accepted — 2026-11-01

## Context

Replace Selection translated the selection and pasted over it with no sign of
progress: nothing showed while it ran, an empty result only beeped, and only
a failure opened the popup. The app being edited has to keep key focus,
because the result goes back with a synthesized ⌘V, so TransFlex cannot
receive ordinary key presses during the run.

## Decision

- A non-activating capsule beside the mouse pointer shows "Translating with
  <preset>" and then "Replaced · ⌘Z to undo" for 1.5 s. It sits beside the
  pointer because many apps (Chrome, Electron) do not expose the selection's
  position. A failure, including an empty result, opens the notice banner
  window, which states that nothing was changed.
- For the duration of the run only, Esc is registered as a global shortcut
  that cancels it; it is unregistered when the run succeeds, fails or is
  cancelled. Clicking the capsule also cancels.

## Consequences

- During a run (typically a few seconds) Esc does nothing in the app being
  edited.
- If the unregister step were skipped on some path, Esc would stay captured
  system-wide; every exit path must release it, and tests cover each one.

## Rejected

- A banner at the top for every run: heavier than needed when it succeeds.
- Menu bar icon only: easy to miss, and a failure needs room to explain.
- Cancel by click only: slower when the wrong text was selected.
