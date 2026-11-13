# Source text is checked for secrets before it is sent

Status: accepted — 2026-11-13

## Context

A selection or a pasted text can hold an API key the user did not mean to
translate, and Translate Selection and Replace Selection send it without the
user reading it first. A three-role review (daily user, maintainer,
dissenter) argued the flows, and the owner settled the open points.

## Decision

- A General setting, **Check for secrets before sending**, on by default for
  new and existing users. Its caption says it covers known key formats in
  text only.
- A new scanner in `Core/Security` reports the kind of the first secret it
  finds. It knows only formats with a fixed shape: AI provider keys, GitHub,
  AWS, Slack and Stripe tokens, PEM private key blocks, and URLs that carry
  both a user and a password. No `password=` heuristics, no entropy test, no
  new dependency. The log redactor (`String.redactingSecrets()`) stays as it
  is and is not the scanner.
- The check runs in the callers, before a translation starts, not inside
  `TranslationService`. It is skipped for an endpoint whose host is
  `localhost`, `127.0.0.1` or `::1`.
- A hit sends nothing to the provider. The Popup, and the Output-only popup
  for Translate Selection, show a Secret found card: the kind, the value
  masked to its first four and last four characters, **Back to text** as the
  primary action and **Send anyway** as a secondary one. ⌘↩ and Return do not
  send from this card; Send anyway has ⌘⇧↩.
- Replace Selection shows its banner with **Send anyway**, which translates
  and pastes as usual, and without Retry.
- Send anyway covers that exact text until it changes, the preset changes or
  the popup hides.
- A translation sent with Send anyway is not saved to History.
- A Draft the check would stop, and that was not sent with Send anyway, is
  not kept when the popup hides, whatever Keep last translation says. That
  holds while the card shows and after the user went back to the text.
- Wording says "Not sent to <Provider>", never "Nothing was sent": a
  selection shortcut copied the text to read it, and although the app puts
  the previous clipboard back, a clipboard manager may have recorded it.
- The Replace Selection banner for a hit has Send anyway and a close button
  only; the selection it waits on is dropped when the banner closes. The
  banner waits with no time limit, so Send anyway pastes only when the same
  text is still selected: where the field cannot be compared (a browser), the
  selection is copied again and must match. Otherwise, or when the app the
  text came from is not known, it sends no ⌘V and leaves the translation on
  the clipboard.
- The full value is never shown, logged, announced or stored.

## Consequences

- Images are not scanned.
- Closing the popup on a text the user was editing to remove the secret
  loses that text.
- Preset instructions are not scanned.
- A local proxy that forwards to a cloud provider is not checked, and a
  model on another machine of the local network is.
- Someone who translates developer documentation meets the card on every
  example key in a known format.
- A keyboard-only user can only dismiss the Replace banner; its buttons have
  no keys.
- Replace Selection has to keep the copied selection while its banner waits
  for Send anyway.

## Rejected

- Blocking with no way through: one false positive leaves only turning the
  setting off.
- Masking the secret and sending the rest: it changes the text being
  translated without saying so, and Replace Selection would paste the mask.
- Replace Selection failing into the Popup for review: it takes the user out
  of the app they are editing, the reason Replace Selection exists.
- Leaving Replace Selection unchecked: it is the flow where the text is read
  least.
- A banner only for Translate Selection: it hides after four seconds.
- Saving a sent-anyway translation with the source masked: the translated
  text usually carries the secret too.
- A per-endpoint switch and "don't ask again for this value": put off until
  someone needs them.
