# TransFlex — terms and rules

## Terms

**Popup** — the floating translator panel opened with the Open Popup shortcut;
it shows the source editor and the result.
_Avoid_: main window, translator window.

**Output-only popup** — the same panel showing only the result of a
Translate Selection shortcut, or the error or permission card that shortcut
raised. ⌘I (Show Input) turns it into the Popup.
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
  pastes; a failure opens a notice that says nothing was changed.
- While a Replace Selection translates, Esc anywhere cancels it; the app holds
  Esc system-wide only for that run.
- Copy (⌘C or the button) copies the result and closes the popup; the button
  says so ("Copy & Close").
