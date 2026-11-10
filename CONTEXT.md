# TransFlex — terms and rules

## Terms

**Popup** — the floating translator panel opened with the Open Popup shortcut;
it shows the source editor and the result.
_Avoid_: main window, translator window.

**Output-only popup** — the same panel showing only the result of a
Translate Selection shortcut, the partial result of a translation that
failed midway, or the card for a failure the user must act on (Accessibility
permission, missing or rejected key). Its other failures (nothing selected,
offline, provider error before any text arrived) show in the banner window
instead, unless a Replace Selection is still running: its capsule keeps the
HUD, so the failure shows in the Output-only popup. ⌘I (Show Input) turns it into the Popup.
_Avoid_: quick popup, mini popup.

**Translate Selection** — a per-preset shortcut that copies the selection in
the frontmost app and opens the Output-only popup with its translation.
_Avoid_: quick translate.

**Replace Selection** — a per-preset shortcut that translates the selection
and pastes the result over it; the popup appears only on failure.

**Draft** — what the user typed or attached in the Popup and has not cleared.
_Avoid_: input state, session.

**Keep last translation** — the General setting that decides whether the
Popup opens empty or with its last Draft and result, by how long it has been
hidden (don't keep, 1–5 minutes, always).
_Avoid_: Clear previous translation, reset policy.

## Rules

- When the Popup is opened after a Translate Selection, its Draft comes back
  only if Keep last translation would keep it, timed from when the Popup
  itself was last hidden. A Translate Selection in between does not reset or
  extend that time.
- The Output-only popup always starts from the new selection; it never shows
  an earlier Draft.
- In the Popup the source text stays editable in every state except while a
  translation streams; the last result stays beside it until ⌘⏎ translates
  again.
- Replace Selection shows its progress without taking focus from the app
  being edited: a capsule beside the pointer while it translates and after it
  pastes; a failure opens a notice that says nothing was changed. If the
  Popup is open when it fails, the failure shows in the Popup instead and Esc
  is not held.
- Replace Selection counts as done only when the focused field's text changed
  after the paste. If the field reads the same before and after (a read-only
  field, a page that blocks paste), it fails and leaves the translation on the
  clipboard for the user to paste. Only a focused field whose Accessibility
  text contains the selection is checked; anything else counts as pasted.
- Replace Selection pastes only where the text was copied from. If the user
  moved to another app, field or selection while it translated, it brings
  that app, field and selection back first; if it cannot, it sends no ⌘V,
  fails, and leaves the translation on the clipboard.
- While a Replace Selection translates, Esc anywhere cancels it; the app holds
  Esc system-wide only for that run and, after a failure, while its banner is
  showing, where Esc closes the banner. The banner never hides by itself.
- Stop keeps the text received so far as the result, marked "stopped"; Copy
  and Translate again work on it as on a finished result. A stopped result is
  not saved to History.
- Switching preset keeps the result on screen, finished or partial, until ⌘↩
  translates again with the new preset.
- Copy (⌘C or the button) copies the result and closes the popup; the button
  says so ("Copy & Close").
- A finished translation reaches the clipboard only through Copy, unless the
  General setting **Copy result automatically** (off by default) is on.
- A key combination belongs to one action at most. Recording a combination
  another action already uses is refused, and the recorder names that action.
- Saving the first provider key, when it is for Anthropic or Gemini, moves
  the built-in presets the user has not edited (name and instructions
  unchanged) to that provider: a preset on a fast model gets the provider's
  fast model, one on a strong model its strong model. A new preset starts on
  a provider that has a key.
- Pasting an image with ⌘⇧V attaches it and translates at once; an image
  dropped or chosen from a file waits for ⌘↩.
- After a partial result the popup offers Retry, which translates the whole
  source again; it never sends the partial result as new source.
- Settings and History are ordinary windows: they stay open when the user
  switches to another app, until the user closes them.
