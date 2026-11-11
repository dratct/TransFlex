---
title: Providers
description: Use OpenAI, Anthropic, Gemini, or any OpenAI-compatible server, including one on your own Mac.
---

TransFlex has no translation service of its own. It sends your text to the provider you choose, with your key, and you pay that provider for what you use.

## OpenAI, Anthropic, Gemini

In **Settings → Providers**, click **Add Key…** next to the provider, paste the key, and click **Save Key**. **Edit…** replaces or removes a saved key.

Keys are kept in the macOS Keychain and are sent only to their provider.

## OpenAI-compatible servers

Anything that speaks OpenAI's chat API works: Ollama, LM Studio, OpenRouter and others.

1. In **Settings → Providers**, under **OpenAI-compatible**, click **Add Endpoint…**.
2. Fill in **Name** and **Base URL**. The base URL is the address that `/chat/completions` is added to, so it normally ends in `/v1`.
3. **API key** is optional; a local server usually needs none.
4. Click **Load Models** to check the address, then **Add Endpoint**.
5. In **Settings → Presets**, set a preset's **Provider** to the new endpoint and pick a model.

A plain `http://` address is accepted only for this Mac (`localhost`). Any other server must use `https://`.

### Ollama on your Mac

With [Ollama](https://ollama.com) running and a model pulled:

- **Name**: `Local Ollama`
- **Base URL**: `http://localhost:11434/v1`
- **API key**: leave empty

Text translated this way never leaves your Mac.

## Cost

After each translation the Popup shows the tokens used and an estimated cost, such as `96 tokens · $0.0004`. The estimate comes from a price list built into the app. For a model that is not on the list, the Popup and History say **price unknown**.

The number is an estimate. Your provider's bill is the real one.
