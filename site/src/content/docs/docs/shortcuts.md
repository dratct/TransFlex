---
title: Shortcuts
description: Every keyboard shortcut in TransFlex, and how to change them.
---

## Open the Popup

<kbd>⌥</kbd> <kbd>T</kbd> opens the Popup from any app, and closes it again.

Change it in **Settings → General → Popup → Open shortcut**.

## Shortcuts of a preset

Each preset can have three shortcuts of its own. None is set until you record one in **Settings → Presets**, under **Shortcuts**:

| Shortcut | What it does |
|---|---|
| **Choose this preset** | Makes it the Popup's preset, and opens the Popup if it is hidden. |
| **Translate selection** | Copies the text you selected in the app in front and shows its translation in a small popup. |
| **Replace selection** | Translates the selected text and pastes the translation over it. The Popup does not open. |

Translate selection and Replace selection need the Accessibility permission; TransFlex asks for it the first time. See [Troubleshooting](/docs/troubleshooting/).

### Replace selection, step by step

1. Select text in any app and press the shortcut.
2. A small capsule beside the pointer says **Translating with** and the preset's name. <kbd>Esc</kbd> cancels.
3. The selected text is replaced, and the capsule says **Replaced · ⌘Z to undo**.

Your clipboard is put back as it was a moment later. If the text cannot be replaced, nothing is changed and the translation is left on the clipboard so you can paste it yourself.

## In the Popup

| Keys | Action |
|---|---|
| <kbd>⌘</kbd> <kbd>⏎</kbd> | Translate. After a result, translate the same text again. |
| <kbd>⌘</kbd> <kbd>C</kbd> | With a result showing: copy it and close the Popup. |
| <kbd>⌘</kbd> <kbd>N</kbd> | New: clear the text, the image and the result. |
| <kbd>⌘</kbd> <kbd>I</kbd> | In the small popup of Translate selection: show the source text too. |
| <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>V</kbd> | Paste an image from the clipboard. |
| <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>O</kbd> | Choose an image file. |
| <kbd>⌘</kbd> <kbd>Y</kbd> | Open History. |
| <kbd>⌘</kbd> <kbd>,</kbd> | Open Settings. |
| <kbd>Esc</kbd> | Stop a running translation. On an error card, go back to your text. Otherwise close the Popup. |

## Keep last translation

**Settings → General → Popup → Keep last translation** decides what the Popup shows when you open it again: your last text and result, or an empty Popup.

The choices are **Don't keep**, **1** to **5 minutes**, and **Always**. The default is 2 minutes, counted from when the Popup was last hidden.
