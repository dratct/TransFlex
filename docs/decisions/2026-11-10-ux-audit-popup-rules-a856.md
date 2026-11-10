# Clipboard, partial results and failure surfaces after the UX audit

Status: accepted — 2026-11-10

## Context

A UX audit (2026-11-10) found behaviour that lost the user's data or
contradicted DESIGN.md: every finished translation overwrote the clipboard
with no setting to stop it; Continue ⌘P replaced the source with the partial
translation; Stop discarded the text already received; Translate Selection
failures opened the Output-only popup with an empty error card, while
DESIGN.md drew a banner; the Replace failure banner could only be closed with
the mouse; Settings hid itself whenever another app became active, so a key
could not be copied from a browser into the Add Key sheet.

## Decision

- The clipboard changes only through Copy, unless the General setting
  "Copy result automatically" (off by default) is on.
- Continue ⌘P is removed. After a partial result the popup offers Retry, which
  translates the whole source again.
- Stop keeps the text received so far as a result marked "stopped".
- Translate Selection failures use the banner window when nothing was
  received and the user has nothing to fix in the app (nothing selected,
  offline, provider error). The permission card and the missing- or
  rejected-key card stay in the Output-only popup, and so does a partial
  result. CONTEXT.md's Output-only popup entry is narrowed to match. This
  banner hides itself after about four seconds (paused while the pointer is
  on it) and does not hold Esc: it is frequent and carries nothing to keep.
- Esc stays held system-wide after a Replace Selection failure while its
  banner is showing, and closes the banner; the banner never hides by itself.
  This extends 2026-11-01-replace-selection-holds-escape. Opening any
  TransFlex window hides the banner and releases Esc first, so the window's
  own Esc keeps working.
- Settings no longer auto-dismisses; it behaves like History.
- A key combination belongs to one action; a duplicate recording is refused.
- Saving the first provider key, when it is for Anthropic or Gemini, moves
  unedited built-in presets to that provider's fast or strong model.

## Consequences

- Users who relied on the automatic copy must turn the setting on.
- Esc can stay captured for as long as a failure banner is left open; every
  path that closes the banner must release it.
- Settings can stay behind other apps' windows until the user closes it.

## Rejected

- Auto-copy kept on by default: new users would still lose their clipboard.
- Continue as "translate the rest": a provider-specific prompt with uncertain
  seams, for a rare case Retry already covers.
- Auto-hiding the Replace banner: it carries "the translation is on the
  clipboard", which is easy to miss.
- Reading the clipboard when the popup opens, and a Translate Clipboard
  shortcut: easy to send text the user did not mean to translate.
