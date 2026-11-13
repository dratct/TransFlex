---
name: ui-e2e
description: >-
  Drive the real TransFlexDev app end to end and look at it: build, fire its
  global hotkeys from another app, read and screenshot the popup, Settings or
  History with cua-driver, and read the app log. Use after any change to the popup, Settings, permission or
  selection-shortcut flows, before calling the change done, and whenever the
  owner says the UI "looks broken". Unit tests and SwiftUI ImageRenderer
  snapshots do not catch these bugs; only the running app does.
---

# Real-app UI check for TransFlex

Every step runs on the owner's own desktop. Say which app you are about to
bring forward before you do it, and never type into an app other than the
target text field.

## 1. Build and launch

- `make build-fast` — rebuild, reset Debug privacy grants (ad-hoc builds only), relaunch.
- `make build-fresh` — first-launch state (defaults, presets, history wiped;
  Keychain API keys kept). Only when the flow under test is onboarding.
- Ad-hoc signing changes the signature on every build, so Accessibility is
  always off after a build. Expect the permission card on the first shortcut.
  With `Config/Local.xcconfig` (team signing) the grants survive rebuilds;
  `make build-fresh` still resets them.
- A git worktree has no `Config/Local.xcconfig`, so `make build` and
  `make build-fast` there reset the Dev app's privacy grants for the whole
  Mac. Tell the owner before running either in a worktree; to compile
  without launching or resetting, use `scripts/build.sh --no-gen`.
- This checks TransFlexDev, built by this Mac's Xcode. The released
  TransFlex is built by CI and can differ: when the change calls a newer
  macOS API or touches build settings, also follow
  `.claude/skills/build-parity/SKILL.md`.

## 2. Find the bound shortcuts

```bash
defaults read io.aiaz.transflex.dev | rg KeyboardShortcuts_
```

Each value is `{"carbonKeyCode":N,"carbonModifiers":M}`. `N` is the macOS
virtual key code (2 is D, 9 is V). `M` is a sum of: ⌘ 256, ⇧ 512,
⌥ 2048, ⌃ 4096. Names: `openPopup`, `preset.<uuid>` (select preset),
`preset-<uuid>-popup` (Translate Selection), `preset-<uuid>-replace`.
No binding → ask the owner to record one in Settings → Presets.

## 3. Drive the app with cua-driver

`cua-driver` reads the app's accessibility tree and acts on elements, and it
still captures the screen when the Mac is reached over Screen Sharing and
`screencapture` fails ("could not create image from display"). Its own skill
has the full rules; these are the calls this app needs.

```bash
S=<scratchpad>
PID=$(pgrep -x TransFlexDev)
cua-driver call list_windows "{\"session\":\"tf\",\"pid\":$PID}"
# One window: its tree (rows `[N]`), a snapshot id and a screenshot.
cua-driver call get_window_state "{\"session\":\"tf\",\"pid\":$PID,\"window_id\":W,\"query\":\"Export\",\"screenshot_out_file\":\"$S/w.png\",\"max_image_dimension\":1400}"
# Act on row [N] of that read: the token is <snapshot_id>:N.
cua-driver call click "{\"session\":\"tf\",\"pid\":$PID,\"window_id\":W,\"element_token\":\"s0000002a:11\"}"
# Keys and text go to whatever is frontmost.
D='{"kind":"desktop","display_id":"primary"}'
cua-driver call hotkey "{\"session\":\"tf\",\"target\":$D,\"keys\":[\"cmd\",\"shift\",\"d\"]}"
cua-driver call press_key "{\"session\":\"tf\",\"target\":$D,\"key\":\"escape\"}"
cua-driver call type_text "{\"session\":\"tf\",\"target\":$D,\"text\":\"hello\"}"
# Whole screen, for the popup's position or the menu-bar item.
cua-driver call get_desktop_state "{\"session\":\"tf\",\"screenshot_out_file\":\"$S/full.png\",\"max_image_dimension\":1400}"
cua-driver call end_session '{"session":"tf"}'
```

- Before the first capture, and before each batch of keys, ask whether the
  screen is locked; the Mac relocks fast:

  ```bash
  swift -e 'import CoreGraphics; import Foundation; print((CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] ?? 0)'
  ```

  `1` means locked: a capture then shows only the wallpaper, with no menu
  bar, and `screencapture` fails with "could not create image from rect".
  That is not a missing window. Ask the owner to unlock, and check again
  before saying the screen cannot be seen.
- A session label that was ended rejects every later call ("session has
  ended"): start it again with `start_session`, or use a new label.
- To judge a small detail (a menu item's image, a focus ring), capture at
  full size with `"max_image_dimension":0`, then crop the region with
  `sips -c <height> <width> --cropOffset <y> <x> in.png --out crop.png`
  and read the crop. A capture scaled to 1400px hides a 16pt glyph.
- macOS 27 hides a status menu item's image unless the item asks to keep it
  (`MenuItemImages.keepVisible`). Seeing the images in TransFlexDev does not
  show them in a CI-built TransFlex: check that app's menu too.
- The popup is a non-activating panel: selection shortcuts copy from
  whatever app is frontmost, so bring that app forward and select real text
  there before firing the shortcut.
- The menu-bar item has no window. Click it by pixel from a
  `get_desktop_state` capture, then pick an item with ↓ and Return (order:
  Open Popup, History, Settings…, Quit); a second pixel click often lands on
  the wrong item.
- A save panel is a sheet on its window: ⌘⇧G opens Go to Folder. Never save a
  file during a check; to see the failure alert, aim at `/System/Library`.
- `make open-debug` does not restart a running app. Rebuild with
  `make build-fast`, and take the new pid.
- No `cua-driver`, or a permission it reports missing: stop and tell the
  owner. Its permission prompts are theirs to approve.

## 4. Look

Read the PNG from `screenshot_out_file`, and prefer the tree for text: an
exact label or alert message is in `tree_markdown`. Check at least: nothing
clipped or scrolling that should fit,
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

## 6. Full checklist (before calling a UI change done)

Run the whole list after a change that touches the popup, Settings, History or
a shortcut flow; DESIGN.md › Popup states is what each state must look like.

1. **Open twice.** Open the popup, close it with Esc, open it again: the
   second open looks the same as the first (size, focus in the editor, no
   ring on the preset picker), and the Draft follows Keep last translation.
2. **Quick translate, short → short → medium → long → short.** Translation-only
   popup from a selection. Each opens at the size its source predicts: one
   sentence at 160pt, twice in a row with no jump on the second; a paragraph
   at its own height, growing at most a line or two while it streams; a long
   text at 60% of the screen height and no wider than 660pt, scrolling with the
   newest line in view; a short one again back at 160pt. All share one top
   edge and one horizontal centre.
3. **⌘I, edit, translate again.** From the translation-only popup press ⌘I,
   edit the Original, ⌘↩: one request per press, the seam fills while it
   streams and stays at the same x in every state.
4. **Settings mid-way.** While the popup shows a result press ⌘,: Settings
   opens in front; closing it leaves the popup visible and typing goes to it.
5. **History with entries.** ⌘Y: History opens in front, grouped by day,
   the newest entry already selected and its header (date, Delete…,
   Translate again, Copy) fully visible below the toolbar; rows read
   "preset · time · cost" and the subtitle "Today: $…" once a priced model
   translated today. In the search field ↓ moves into the list and ⌘F back.
   Delete… asks before deleting. Translate again opens the full popup with
   that text and preset and adds a new entry. A search with no match shows
   "No results for …" and leaves Export…/Delete All… as they were. With
   Settings open, History cascades 24pt down and right.
6. **Replace Selection.** In TextEdit: the capsule appears beside the pointer,
   "Replaced · ⌘Z to undo" fades; Esc during a run cancels it and the text is
   unchanged; afterwards Esc works in other apps again. A failing preset shows
   the banner ending "Nothing was changed.". TextEdit keeps focus throughout.
7. **Model picker.** Search, ↑↓, a typed custom ID; no speech, image or
   embedding models.
8. **Light, dark, Reduce Transparency** for the popup and one Settings tab.
9. **Pinned popup.** Pin with the header button and with ⌘P: the pin fills
   and ✕ appears. Click into TextEdit and type: the popup stays, the text
   goes to TextEdit, Esc there does not close the popup. Drag the popup to a
   corner, then ⌘I: the top-left corner stays. Translate Selection from
   TextEdit: the banner "The popup is pinned", the pinned text and the
   clipboard unchanged. Replace Selection from TextEdit: the text is
   replaced and the popup untouched — repeat right after clicking the popup,
   when it holds the keyboard. ⌘, then close Settings: still pinned, same
   place. ✕, ⌘Y and unpin-then-click-away each close it; the next open is
   unpinned at the usual place. Dragging while a long translation streams
   does not make it jump.

Compare each screenshot with the matching `docs/design/mockups.html` figure
and with the previous run's screenshot of the same step.

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
