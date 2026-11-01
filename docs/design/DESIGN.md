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
    otherwise stacked, with the source pane capped at 40% of the height.
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
| `ContentPane` | `content` fill, 1pt `outline`, radius 10, padding 12. Same for source and result; the result adds a 2pt `accent` leading rule. |
| `FooterAction` | Title + `KeyHint`. Exactly one `.borderedProminent` per state (the primary); the others `.bordered`. No per-button tint. |
| `KeyHint` | Caption, `faint`, chips at radius 6. Hidden in the button's accessibility label, read as "Command Return". |
| `ErrorBanner` | Inside the result pane: SF Symbol `exclamationmark.triangle.fill` in `danger`, a one-line title, the provider's reason (≤ 300 chars), and an action button when one fixes it (Open Settings). |
| `EmptyState` | Centred SF Symbol (32pt, `faint`), a title in `.body` semibold, one line in `on-surface-variant`, an optional action. Used by History and the model picker. |
| `ModelPicker` | A button showing the current model; opens a popover with a search field (focused), the list filtered to text models, grouped by family, newest first, and a "Use '<typed id>'" row. |
| `Toast` | Bottom-trailing capsule, `.caption`, 150ms fade. Only "Copied" uses it. |

Popup states (footer primary in **bold**):

| State | Source pane | Result pane | Footer |
|---|---|---|---|
| idle | editor, focused, placeholder | placeholder, left-aligned, `faint` | **Translate ⌘⏎** |
| streaming | editor read-only | typing dots → streaming text | **Stop esc** |
| done | editor, editable | result | New ⌘N · Re-translate ⌘⏎ · **Copy & Close ⌘C** |
| error | editor, editable | partial text + `ErrorBanner` | New ⌘N · Continue ⌘P (if partial) · **Retry ⌘⏎** |
| permission | — (Output-only) | permission card | **Open System Settings ⌘⏎** / **Done ⌘⏎** |

The Output-only popup has no source pane and adds Show Input ⌘I to the
footer. An error raised before anything was sent (no selection) has
**Close esc** as its primary instead of Retry. Esc always closes the popup, whatever holds focus.

## Do's and Don'ts

- Do give each state exactly one prominent action, because the eye needs one
  place to land in a window that is open for two seconds.
- Do keep the source editable after a result. Editing and pressing ⌘⏎ is the
  common correction loop, and ⌘N would lose the text.
- Don't colour buttons by meaning (blue New, purple Copy, orange Stop).
  Coloured text on glass was unreadable on light backgrounds (audit D6, R3).
- Don't put text on raw blur; put it in a `content` pane. Legibility must not
  depend on what sits behind the window.
- Don't use a monospaced font for numbers or URLs in forms. It made rows in
  one form look like they came from different apps (audit D3, D13).
- Don't let focus land on the preset picker when the popup opens. It draws
  a ring and swallows ⌘⏎ (audit D4).
- Don't nest a scroll view inside a scrolling form (the preset prompt). Give
  the editor a fixed height and an "Expand" sheet at 80% of the window.
- Don't open a window behind another one of the app's windows. Settings and
  History come to the front and cascade by 24pt.
