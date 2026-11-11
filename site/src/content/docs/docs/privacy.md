---
title: Privacy
description: What TransFlex sends, where, and what it keeps on your Mac.
---

TransFlex has no account, no server of its own, and no telemetry or analytics.

## What leaves your Mac

| Goes to | What | When |
|---|---|---|
| The provider of the preset you use (OpenAI, Anthropic, Google, or the server you added) | Your text or image, the preset's instructions, and your key | When you translate |
| The same provider | A request for its list of models, with your key | When Settings shows the model list |
| GitHub | A request for the update feed, and the update itself | When checking for updates |

Nothing else. What a provider does with your text is covered by that provider's own terms.

With a model running on your own Mac, such as Ollama, your text does not leave the Mac at all; see [Providers](/docs/providers/).

## What stays on your Mac

- **API keys**: in the macOS Keychain.
- **History**: `~/Library/Application Support/TransFlex/history.sqlite`. See [History](/docs/history/).
- **Presets and endpoint settings**: files in the same folder. Keys are never written there.

## The clipboard

- A result is copied when you press **Copy & Close**, or every time if you turned on **Copy result automatically**.
- **Translate selection** copies your selection to read it, then puts your previous clipboard back. Its result follows the rule above.
- **Replace selection** copies your selection, pastes the translation, and puts your previous clipboard back about half a second later. If the paste fails, the translation stays on the clipboard.

A clipboard manager may record these short-lived entries.

## The Accessibility permission

Only Translate selection and Replace selection use it, to press <kbd>⌘</kbd> <kbd>C</kbd> and <kbd>⌘</kbd> <kbd>V</kbd> for you in the app in front. The Popup works without it.

## Check it yourself

TransFlex is open source. The code is on [GitHub](https://github.com/dratct/TransFlex).
