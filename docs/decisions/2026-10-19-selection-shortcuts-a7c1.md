# Selection shortcuts: synthesized ⌘C/⌘V and the Accessibility permission

Status: accepted — 2026-10-19

## Context

Each preset gains two global shortcuts that act on text selected in another
app: translate it and show only the result, or translate it and replace it in
place. Reading the selection has two options on macOS:

- `kAXSelectedTextAttribute` through the Accessibility API. Chrome, Electron
  apps and many custom text views do not expose it.
- Posting ⌘C and reading the clipboard. Every standard text field supports it.

Both need the Accessibility permission. Writing the result back has the same
split, and only ⌘V works across apps.

## Decision

- `SelectionCapture` posts ⌘C/⌘V with `CGEvent`, flags set to Command only. It
  first waits up to 300 ms for the hotkey's modifiers to be released, so a
  still-held ⌥ does not turn ⌘C into ⌥⌘C.
- Before posting, it snapshots every clipboard item and type, and restores them
  after the copy, or after the paste unless something else wrote in between.
- No clipboard change within 500 ms means nothing was selected.
- Replace waits for the complete translation before pasting; a partial or
  empty result never replaces the selection. The selection's leading and
  trailing whitespace is kept around the translated text.
- The permission is checked silently when a shortcut fires. Without it the
  popup shows a permission card whose button calls the system prompt (that
  call is what lists the app under Accessibility) and opens that settings
  pane (named *Device Control and Data Access* from macOS 27; the card uses
  whichever name the running macOS shows). The popup hides while System Settings is in front; the app checks
  the grant every second for up to 5 minutes and brings the popup back to
  confirm. Any other failure opens the output-only popup with the error
  instead of failing silently.
- The two shortcut names are `preset-<uuid>-popup` and `preset-<uuid>-replace`
  in the KeyboardShortcuts store, with no initial binding. KeyboardShortcuts 3.x
  rejects dots in names; the older `preset.<uuid>` keeps its key so existing
  bindings survive, at the cost of a debug-only runtime warning.

## Consequences

- The app now needs the Accessibility permission for these shortcuts; the
  rest of the app works without it. Ad-hoc signed builds lose the grant after
  every rebuild, because TCC ties it to the code signature.
- Apps that ignore synthesized keystrokes, or secure input fields, cannot be
  read; the user sees the "No text selected" error.
- *Translate Selection* ends with the result on the clipboard, like every
  popup translation; only *Replace Selection* leaves the clipboard as it was.
- For up to ~0.5 s the clipboard holds the selection or the translation;
  clipboard managers may record those entries.
