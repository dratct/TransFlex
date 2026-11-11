---
title: TransFlex is now a native Mac app
description: TransFlex has been rewritten in Swift as a menu-bar app for macOS. It is free and open source.
date: 2026-11-11
authors: truongtc
excerpt: TransFlex has been rewritten in Swift as a menu-bar app for macOS. It is free, MIT-licensed, and the earlier cross-platform version is discontinued.
---

TransFlex started as a cross-platform app. It is now a native Mac app, written in Swift, that lives in the menu bar. This post says what changed and why.

## Why native

A translator is a tool you open for a few seconds, many times a day. That only works when it behaves like part of the system: one shortcut from any app, a window that appears where you are working, and Esc to make it go away. Building it with the Mac's own tools made those things straightforward, so that is where the work went.

## What it does

- **A popup on <kbd>⌥</kbd> <kbd>T</kbd>.** Type or paste, press <kbd>⌘</kbd> <kbd>⏎</kbd>, and the translation streams in. The result is copied for you.
- **Translate Selection and Replace Selection.** Give a preset its own shortcuts to translate the text you selected in another app, or to swap it for its translation in place.
- **Presets.** Each preset picks a provider, a model and the instructions. Three come built in; you can edit them or write your own.
- **Your provider.** OpenAI, Anthropic, Gemini, or any OpenAI-compatible server, including one on your own Mac.
- **Images.** Drop or paste a picture into the popup to translate the text in it.
- **History.** Every translation is kept on your Mac, searchable, and exportable.

The [docs](/docs/install/) cover each of these.

## Free and open source

TransFlex for Mac is free and MIT-licensed. There is no account and no paid tier; you pay your AI provider for what you use. The source is on [GitHub](https://github.com/dratct/TransFlex).

The earlier cross-platform version is discontinued, and there is no Windows or Linux version of the new app.

## Get it

[Download TransFlex for Mac](https://github.com/dratct/TransFlex/releases/latest/download/TransFlex-macos.zip). It needs macOS 13 or later and runs on Apple silicon and Intel.

If it saves you time, you can [support its development](/support/).
