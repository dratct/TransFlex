---
title: History
description: Every translation is kept on your Mac. Search it, delete it, or export it.
---

TransFlex keeps every finished translation on your Mac, whether it came from the Popup, Translate selection or Replace selection. Translations you stopped, or that failed, are not kept.

Open it with **History** in the menu-bar menu, or <kbd>⌘</kbd> <kbd>Y</kbd> in the Popup.

## What you can do

- **Search**: <kbd>⌘</kbd> <kbd>F</kbd>. It looks in both the original and the translation.
- **Copy** the original or the translation of an entry.
- **Translate again**: sends the text back to the Popup with the same preset.
- **Delete…** removes one entry. **Delete All…** removes everything. Neither can be undone.
- **Export…** saves the whole history as JSON or Markdown.

The window's subtitle shows what today's translations cost.

## What is stored

Each entry holds the original text, the translation, the preset, provider and model, the tokens used and the estimated cost. Images are not stored.

History stays until you delete it; nothing is removed automatically, and there is no setting that turns it off.

The file is `~/Library/Application Support/TransFlex/history.sqlite`. It is excluded from Time Machine backups.
