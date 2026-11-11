---
title: Presets
description: A preset picks the provider, the model and the instructions for one kind of translation.
---

A preset is one way of translating: which provider and model to use, and what to tell the model. Switch presets in the Popup's menu, or give each its own shortcuts.

## The built-in presets

| Preset | Model |
|---|---|
| Natural EN ↔ VI | OpenAI `gpt-4o-mini` |
| Technical Doc EN ↔ VI | OpenAI `gpt-4o` |
| Any → English (Natural) | OpenAI `gpt-4o-mini` |

They are ordinary presets: edit them or delete them as you like.

## Edit or add a preset

Open **Settings → Presets**. Pick a preset on the left, or add one with **+**. Changes are saved as you make them. **−** deletes the selected preset at once, without asking.

- **Name**: what the Popup's menu shows.
- **Provider**: OpenAI, Anthropic, Gemini, or an OpenAI-compatible endpoint you added. Changing the provider clears the model.
- **Model**: with a key saved, the list comes from the provider. You can also type any model ID.
- **Reads images**: turn on if the model accepts images. See [Images](/docs/images/).
- **Instructions**: what the model is told to do.
- **Shortcuts**: see [Shortcuts](/docs/shortcuts/).
- **Tuning**: Temperature, Top P and Max tokens. Leave them alone unless you know you need them.
- **Extra request fields**: JSON merged into the request, for provider-specific options.

## Languages

There is no language menu. The preset's **Instructions** decide what the text is translated into, so a new language pair is a new preset.

For example, for Japanese:

```text
You are a professional translator. Translate the user's text into natural Japanese.
If the text is already Japanese, translate it into English.
Reply with the translation only.
```
