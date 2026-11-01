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

**Clear previous translation** — the General setting that decides whether the
Popup opens empty or with its last Draft and result, by how long it has been
hidden (always, after 1–5 minutes, never).

## Rules

- When the Popup is opened after a Translate Selection, its Draft comes back
  only if Clear previous translation would keep it, timed from when the Popup
  itself was last hidden. A Translate Selection in between does not reset or
  extend that time.
- The Output-only popup always starts from the new selection; it never shows
  an earlier Draft.
- In the Popup the source text stays editable in every state except while a
  translation streams; the last result stays beside it until ⌘⏎ translates
  again.
- Copy (⌘C or the button) copies the result and closes the popup; the button
  says so ("Copy & Close").
