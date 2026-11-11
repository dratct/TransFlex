---
title: Troubleshooting
description: Fixes for the shortcut, permissions, keys and failed translations.
---

## The shortcut does nothing

- Check that TransFlex is running: its icon is in the menu bar.
- Another app may be using the same keys. Record a different shortcut in **Settings → General → Popup → Open shortcut**.

## "One permission needed"

Translate selection and Replace selection need permission to copy your selection and paste the result.

1. Click **Open System Settings** on the card.
2. Turn on **TransFlex** in the list. The list is under **Privacy & Security**, named **Accessibility** (on macOS 27, **Device Control and Data Access**).
3. Go back; the card confirms with **Permission granted**. Select your text and press the shortcut again.

## "No text selected"

The app in front did not hand over a selection. Select the text again and retry. Some places never allow it, such as password fields. Use the Popup there: copy the text yourself and press <kbd>⌥</kbd> <kbd>T</kbd>.

## "Couldn't replace the selection"

Replace selection changed nothing. The message says why:

- You switched app, or the selection changed, while it was translating.
- The app did not accept the paste, for example in a read-only field.

In both cases the translation is on the clipboard: select the text and press <kbd>⌘</kbd> <kbd>V</kbd>.

## Errors while translating

| Message | What to do |
|---|---|
| **API key invalid. Update in Settings.** | Replace the key in **Settings → Providers**. |
| **Add an OpenAI key** (or another provider) | The preset uses a provider with no key yet. Add the key, or switch the preset to a provider you have. |
| **Rate limited** | The provider is limiting your requests. Wait and retry. |
| **The provider rejected the request: …** | Read the provider's reason after the colon. Often the model name is wrong or your account cannot use it. |
| **Provider issue. Try again.** | The provider had an error. Press <kbd>⌘</kbd> <kbd>⏎</kbd> to retry. |
| **No internet connection.** | Check the connection. A request that gets no answer for 60 seconds also ends this way. |

If a translation stops part-way, the Popup keeps what arrived. **Continue** (<kbd>⌘</kbd> <kbd>P</kbd>) carries on from there; **Retry** starts over.

## A local server will not connect

- The **Base URL** should end in `/v1` for most servers: `http://localhost:11434/v1` for Ollama.
- `http://` works only for `localhost`. A server on another machine needs `https://`.
- Click **Load Models** in the endpoint's sheet to test the address.

## The preset cannot read images

Turn on **Reads images** for the preset in **Settings → Presets**, and choose a model that accepts images. See [Images](/docs/images/).

## Still stuck

[Open an issue](https://github.com/dratct/TransFlex/issues) and say what you did, what you expected, and what happened. TransFlex is in active development, and reports help.
