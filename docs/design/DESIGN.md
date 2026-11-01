---
colors:
  accent: { light: "#0F7A5F", dark: "#0E8466" }   # AccentColor asset; shown when system accent = Multicolor
  on-accent: "#FFFFFF"                              # 5.29:1 light, 4.66:1 dark
  brand: "#21B38C"                                  # logo, app icon, Welcome illustration only
  surface: windowBackgroundColor                    # window and popup body
  content: textBackgroundColor                      # source and result panes, editors
  on-surface: labelColor
  on-surface-variant: secondaryLabelColor           # labels, metadata
  faint: tertiaryLabelColor                         # placeholders, key hints, cost
  outline: separatorColor
  danger: systemRed
  warning: systemOrange
typography:
  family: "SF Pro (system font through SwiftUI text styles)"
  fallback: ["-apple-system", "Helvetica Neue", "sans-serif"]   # HTML mockups only
  title: ".title3 — 15pt semibold"     # window and sheet titles
  reading: "14pt regular, line spacing 3"   # source and result text in the popup
  body: ".body — 13pt"                 # controls, form rows, list rows
  caption: ".caption — 11pt"           # key hints, cost, footers, metadata
spacing: [4, 8, 12, 16, 24]
rounded: [6, 10, 12]                   # control/inner · pane/card · popup window
elevation: [none, window-shadow]       # only the system window shadow; no inner shadows
motion:
  duration: [0ms, 150ms]               # frame changes: none · toast and state swap: 150ms ease-out
---

# TransFlex design

## Overview

TransFlex is a translator that lives in the menu bar. Every surface is built
to be **operated**, used many times a day. The **Popup** and the
**Output-only popup** are read at a glance and closed within seconds.
Settings and History are standard macOS utility windows. Welcome and
First-run are the only surfaces meant to persuade: they ask once for a
provider key.

The reference object is **Spotlight's result panel and System Settings**:
system materials, system type, one accent used sparingly.

The app follows light, dark and *Reduce transparency* / *Increase contrast*.
Every surface has to read correctly with an opaque background.

**Precision choice:** the popup frame comes from one function of
(mode, content). It never inherits a size from the previous open.

Static mockups of every screen in every state: [`mockups.html`](mockups.html).
Terms (Popup, Output-only popup, Draft…) are defined in [`CONTEXT.md`](../../CONTEXT.md).

## Colors

- Roles map to `NSColor` semantic colours, so dark mode and increased
  contrast come from the system. The only custom colours are `accent` and
  `brand`.
- `accent` lives in the `AccentColor` asset. A user whose system accent is
  not Multicolor sees their own colour; no view forces `.tint`.
- Accent is used for: the one prominent button of a state, focus rings,
  selection, toggles, and the result pane's 2pt leading rule.
  Never for small text: dark `accent` on `surface` is 3.6:1.
- A pane is `content` at full opacity on top of the popup material, so text
  never sits directly on blur.
- `danger` is only for destructive buttons (Delete All) and the error icon.
  `warning` is unused unless a warning state is added.

## Typography

- SwiftUI text styles only (`.title3`, `.body`, `.caption`). The popup's
  reading text is `.system(size: 14)`, the one fixed size, so translations
  stay readable at the popup's distance.
- At most three sizes per window: popup 14 / 13 / 11; Settings and History
  15 / 13 / 11.
- Numbers (cost, token counts, character counts) use `.monospacedDigit()`,
  not a monospaced font.
- Vietnamese: SF Pro carries every Vietnamese glyph, so no extra font is needed.

## Layout

- Spacing comes only from the scale: 4 (icon↔label), 8 (inside a group),
  12 (pane padding, between footer buttons), 16 (window edge), 24 (between
  sections).
- **Popup frame**
  - Popup: 60% × 60% of the visible screen, centred, minimum 520 × 360.
    At ≥ 720pt wide the source and result panes sit side by side,
    otherwise stacked, with the Original half capped at 38% of the height.
  - Output-only popup: 40% of the screen width, minimum 420pt. Height fits
    the content, clamped to 160pt … 60% of the screen, and grows downward
    with a fixed top edge. Each new Translate Selection starts from its own
    content and never from the last height.
  - ⌘I goes from the Output-only popup to the Popup frame. No transition
    keeps the other mode's layout.
- The header (preset picker, attach, settings) and the footer (cost, actions)
  are identical in both modes.

## Elevation & Depth

- One level: the system window shadow on the popup, Settings, History and
  Welcome. Panes are flat; depth comes from `content` on `surface`, plus a
  1pt `outline` border.
- The popup material is `NSVisualEffectView.popover`. With Reduce
  transparency it becomes opaque `surface`, and nothing else changes.

## Shapes

- 12pt continuous corners on the popup window; 10pt on panes, cards and
  sheets drawn by the app; 6pt on inner controls (search field, key hint chips).
- System controls keep their own shapes. No radius is invented per view.

## Components

| Component | Rule |
|---|---|
| `TranslationSheet` | One `content` sheet (radius 10, 0.5pt `outline` ring) split by a hairline: **Original** on the leading half, **Translation** on the trailing half with a 9% `accent` wash. Each half has a 34pt label row (12pt semibold, `on-surface-variant`) and its text below. Stacks vertically under 720pt wide. |
| `FooterAction` | Title + `KeyHint`. Exactly one `.borderedProminent` per state (the primary); secondary actions `.bordered`; "New" is borderless. No per-button tint. |
| `KeyHint` | 10.5pt keycaps on a faint fill, radius 4. Read by VoiceOver as part of the button label ("Command Return"). |
| `Notice` | Errors and requests never render inside the `TranslationSheet`. Three forms: **card** — replaces the sheet when there is nothing to show (missing key, permission): 52pt tinted symbol tile, 15pt title, one line of body, actions; **strip** — docked between the sheet and the footer when a partial result exists: symbol, title, the provider's reason, Continue/Retry; **banner window** — a 440pt standalone panel near the top of the screen for Translate Selection failures (nothing selected, offline, permission granted). |
| `EmptyState` | Tinted symbol tile, 15pt title, one line that says how to fill it. History empty / no results, model picker no match. |
| `ModelPicker` | Popover: search field first (focused), text models only, grouped by family, newest first, and a "Use '<typed>' as a custom model ID" row. |
| `ReadsImages` | A per-preset switch the user sets. The app does not detect image support: OpenAI and Gemini model lists do not report it (checked 2026-11-01). |
| `SettingsRow` | Label (+ optional one-line explanation in `faint`) leading, one control trailing; rows grouped in a `content` box with hairline separators. |
| `Toast` | Dark capsule with a check symbol, centred above the footer. Only "Copied". |

Popup states (footer primary in **bold**):

| State | Sheet | Footer |
|---|---|---|
| idle | Original: editor, focused, placeholder; Translation: hint text | **Translate ⌘↩** |
| streaming | Original dimmed and read-only; Translation streams with a caret | Stop esc (not prominent) |
| done | both halves; Original editable | New ⌘N · Translate again ⌘↩ · **Copy & Close ⌘C** |
| error, nothing received | replaced by a `Notice` card | Back to text esc + the card's own actions |
| error, partial received | partial text marked "incomplete" + `Notice` strip | New ⌘N · strip: Continue ⌘P · **Retry ⌘↩** |

The Output-only popup shows only the Translation half and adds Show text ⌘I.
Its failures use the banner window, never an Output-only popup with an empty
sheet. 4xx errors show the provider's reason; 5xx read "<Provider> is having
trouble. Try again in a moment." Esc always closes, whatever holds focus.

## Do's and Don'ts

- Do give each state exactly one prominent action, because the eye needs one
  place to land in a window that is open for two seconds.
- Do keep the source editable after a result. Editing and pressing ⌘⏎ is the
  common correction loop, and ⌘N would lose the text.
- Don't colour buttons by meaning (blue New, purple Copy, orange Stop).
  Coloured text on glass was unreadable on light backgrounds (audit D6, R3).
- Don't put an error inside the translation. It hides the result and reads
  like translated text; use a `Notice` (owner request, 2026-11-01).
- Don't use emoji as icons. One SF Symbol set, one weight.
- Don't put text on raw blur; put it in a `content` sheet. Legibility must not
  depend on what sits behind the window.
- Don't use a monospaced font for numbers or URLs in forms. It made rows in
  one form look like they came from different apps (audit D3, D13).
- Don't let focus land on the preset picker when the popup opens. It draws
  a ring and swallows ⌘⏎ (audit D4).
- Don't nest a scroll view inside a scrolling form (the preset prompt). Give
  the editor a fixed height and an "Expand" sheet at 80% of the window.
- Don't open a window behind another one of the app's windows. Settings and
  History come to the front and cascade by 24pt.
