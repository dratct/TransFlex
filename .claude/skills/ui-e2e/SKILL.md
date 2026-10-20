---
name: ui-e2e
description: >-
  Drive the real TransFlexDev app end to end and look at it: build, fire its
  global hotkeys from another app, screenshot the popup or Settings, and read
  the app log. Use after any change to the popup, Settings, permission or
  selection-shortcut flows, before calling the change done, and whenever the
  owner says the UI "looks broken". Unit tests and SwiftUI ImageRenderer
  snapshots do not catch these bugs; only the running app does.
---

# Real-app UI check for TransFlex

Every step runs on the owner's own desktop. Say which app you are about to
bring forward before you do it, and never type into an app other than the
target text field.

## 1. Build and launch

- `make build-fast` — rebuild, reset Debug privacy grants, relaunch.
- `make build-fresh` — first-launch state (defaults, presets, history wiped;
  Keychain API keys kept). Only when the flow under test is onboarding.
- Ad-hoc signing changes the signature on every build, so Accessibility is
  always off after a build. Expect the permission card on the first shortcut.

## 2. Find the bound shortcuts

```bash
defaults read io.aiaz.transflex.dev | rg KeyboardShortcuts_
```

Each value is `{"carbonKeyCode":N,"carbonModifiers":M}`. `N` is the virtual
key code `osascript … key code N` takes. `M` is a sum of: ⌘ 256, ⇧ 512,
⌥ 2048, ⌃ 4096. Names: `openPopup`, `preset.<uuid>` (select preset),
`preset-<uuid>-popup` (Translate Selection), `preset-<uuid>-replace`.
No binding → ask the owner to record one in Settings → Presets.

## 3. Fire a shortcut from another app

The popup is a non-activating panel: selection shortcuts copy from whatever
app is frontmost, so put a real selection there first.

```bash
osascript -e 'tell application "Safari" to activate' -e 'delay 0.6' \
  -e 'tell application "System Events" to key code 2 using {command down, shift down}'
sleep 1.5
```

Keys sent afterwards (Esc = `key code 53`, ⌘⏎ = `key code 36 using {command down}`)
reach the popup while it is key.

## 4. Look

```bash
S=<scratchpad>
screencapture -x "$S/full.png"              # whole screen, downscaled
screencapture -x -R x,y,w,h "$S/crop.png"   # region in points, native detail
```

Read the PNG. Check at least: nothing clipped or scrolling that should fit,
every button legible (not grey-on-glass), no stray focus ring, copy matches
what macOS actually shows (macOS 27 names Accessibility "Device Control and
Data Access"; the pane lists the app as `TransFlexDev`).

## 5. When a value looks wrong, log it

Add a temporary `Self.logger.info("TMP… \(x, privacy: .public)")`, rebuild,
reproduce, then:

```bash
/usr/bin/log show --last 20s --info \
  --predicate 'process == "TransFlexDev" AND eventMessage CONTAINS "TMP"' --style compact
```

Remove every `TMP` log line before finishing (`rg -n TMP TransFlex/Sources`).

## Known traps

- SwiftUI preference keys set inside the popup's `ScrollView` never reach
  `onPreferenceChange`; measure with `GeometryReader` + `onAppear`/`onChange`.
- `ImageRenderer` draws AppKit-backed views (blur background, `ScrollView`)
  as a ⛔ placeholder; render only pure-SwiftUI pieces that way.
- The popup hides whenever another app activates (`WindowAutoDismisser`),
  including System Settings opened from the popup itself.
- Turning on the Accessibility switch needs the owner's password or Touch ID:
  stop and ask them; never try to script System Settings toggles.

## Report

Per flow: what you fired, the screenshot path, pass or the exact defect seen.
A flow you could not drive (needs the owner's auth, no binding) is reported
as not run, never as passed.
