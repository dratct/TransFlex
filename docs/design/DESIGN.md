---
colors:
  accent: { light: "#0F7A5F", dark: "#0E8466" }   # AccentColor asset; shown when system accent = Multicolor
  accent-text: { light: "#0F7A5F", dark: "#3DD6AC" }  # small accent text (the Translation label); 9.1:1 on dark
  on-accent: "#FFFFFF"                              # 5.29:1 light, 4.66:1 dark
  brand: "#21B38C"                                  # logo, app icon, Welcome illustration only
  brand-deep: "#0B5E4A"                             # Welcome brand panel behind white text; 7.7:1
  surface: windowBackgroundColor                    # window and popup body
  content: textBackgroundColor                      # cards, notices, form groups
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
  reading: "15pt original / 17pt translation, line height 1.6"   # popup columns
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
  contrast come from the system. The only custom colours are `accent`,
  `brand` and `brand-deep`.
- `accent` lives in the `AccentColor` asset. A user whose system accent is
  not Multicolor sees their own colour; no view forces `.tint`.
- Accent is used for: the one prominent button of a state, focus rings,
  selection, toggles, and the result pane's 2pt leading rule.
  Never for small text: dark `accent` on `surface` is 3.6:1.
- The popup material is near-opaque (94% light, 93% dark) because text sits
  on it directly; with Reduce transparency it is fully opaque `surface`.
- `danger` is only for destructive buttons (Delete All) and the error icon.
  `warning` is unused unless a warning state is added.

## Typography

- SwiftUI text styles (`.title3`, `.body`, `.caption`) everywhere except the
  popup's two reading sizes: Original 15pt and Translation 17pt, so the
  translation leads by size alone, with no box around it.
- Settings and History use three sizes (15 / 13 / 11). The popup uses four
  (17 / 15 / 13 / 11) on purpose: the two reading sizes carry the hierarchy
  that boxes used to.
- Numbers (cost, token counts, character counts) use `.monospacedDigit()`,
  not a monospaced font.
- Vietnamese: SF Pro carries every Vietnamese glyph, so no extra font is needed.

## Layout

- Spacing comes only from the scale: 4 (icon↔label), 8 (inside a group),
  12 (pane padding, between footer buttons), 16 (window edge), 24 (between
  sections).
- **Popup frame**
  - Popup: 60% × 60% of the visible screen, centred, minimum 520 × 360.
    At ≥ 720pt wide the Original and Translation columns sit side by side,
    otherwise stacked, with the Original half capped at 38% of the height.
  - Output-only popup: opens at the size its source text predicts. The
    source is measured in the Translation font at the column width, plus
    10% for the translation. Height fits that estimate, clamped to
    160pt … 60% of the screen. Width is 40% of the screen, minimum 420pt,
    never past 660pt: about 80 characters a line at the translation size,
    the longest line that still reads easily. When the estimate still
    overflows, the width widens toward 660pt until it fits. A translation
    longer than the estimate grows downward with a fixed top edge; the
    popup never shrinks while open. Each new Translate
    Selection starts from its own content and never from the last size.
  - ⌘I goes from the Output-only popup to the Popup frame. No transition
    keeps the other mode's layout.
- The header (preset picker, History, Settings — no attach button) and the footer (cost, actions)
  are identical in both modes.

## Elevation & Depth

- One level: the system window shadow on the popup, Settings, History and
  Welcome. Panes are flat; depth comes from `content` on `surface`, plus a
  1pt `outline` border.
- The popup material is `NSVisualEffectView.popover`. With Reduce
  transparency it becomes opaque `surface`, and nothing else changes.

## Shapes

- 12pt continuous corners on the popup window; 10pt on cards, notices and
  sheets drawn by the app; 6pt on inner controls (search field); key hint chips are capsules.
- System controls keep their own shapes. No radius is invented per view.

## Components

| Component | Rule |
|---|---|
| `TranslationColumns` | Airy columns (chosen 2026-11-01): no inner box. **Original** (15pt, `on-surface-variant`) on the leading side, **Translation** (17pt, `on-surface`) on the trailing side, 28pt side margins, 26pt gutter, divided by the `ColumnSeam`. Labels are 11pt semibold uppercase with 0.06em tracking: `faint` for Original, `accent-text` for Translation. Under 720pt wide they stack with a horizontal `ColumnSeam`. |
| `ColumnSeam` | The rule between the columns (chosen 2026-11-02): 1pt `hair-2`, fading out at both ends, broken at its midpoint by a 10pt ✦ spark in `accent-text`. While a translation streams the spark hides and the rule fills with `accent-text` from the start, led by a 7pt dot whose glow breathes (1.2 s); a short light runs down the filled part every 1.4 s, and down the whole rule before the first token arrives, so the seam never stands still. The fill follows translation length over source length in characters, eased toward 92% (`0.92 × (1 − e^(−1.6 × ratio))`) so it keeps moving when the translation outgrows its source and never reads as finished. Done, Stop or an error returns it to the neutral rule with the spark. Under Reduce Motion there is no running light, no breathing and no easing: only the fill and the dot. Stacked, it runs left to right. |
| `FooterAction` | Title + `KeyHint`. Exactly one `.borderedProminent` per state (the primary); secondary actions `.bordered`; "New" is borderless. System button styles only, at `.controlSize(.large)` in the popup footer, `Notice` actions and sheet action rows: macOS 26 and later draw these as capsules (grey fill for secondary, accent fill for primary), macOS 13–15 as classic push buttons. Buttons inside `SettingsRow` stay at the regular size. No custom `ButtonStyle`, no `.glass`/`.glassProminent`, no `.tint`: the accent comes from the AccentColor asset. |
| `KeyHint` | 10.5pt keycaps in capsules on a faint fill (white at 22% inside the primary button). Read by VoiceOver as part of the button label ("Command Return"). |
| `Notice` | Errors and requests never render inside the `TranslationColumns`. Three forms: **card** — replaces the sheet when there is nothing to show (missing key, permission): 52pt tinted symbol tile, 15pt title, one line of body, actions; **strip** — docked between the sheet and the footer when a partial result exists: symbol, title, the provider's reason, Continue/Retry; **banner window** — a 440pt standalone panel near the top of the screen for Translate Selection failures (nothing selected, offline, permission granted). |
| `HistoryEntry` | Sidebar row: the text, then "preset · time · cost" in `.secondary` (the model when the preset was deleted). Detail: "Today at 4:29 PM" with Delete… and Translate again on the same row, then "model · duration · tokens · cost" at full width so the cost is never truncated; below, the entry as `TranslationColumns` with 24pt side margins to line up with the header (stacked under 720pt; Translation alone when there is no original text, an image without a caption), each column with a copy icon beside its label that shows a checkmark for 1.5 s. The window opens at 1000×560 so the columns start side by side; a sidebar dragged past 280pt stacks them. Delete… asks first; Translate again opens the full popup with the entry's text and preset; it is disabled with the reason as its tooltip when the preset was deleted or now uses another model ("This preset now uses gpt-5.2, not gpt-4o."), and hidden for any translation that had an image, caption or not. The window subtitle holds "Today: $X · N unpriced", hidden when nothing today has a price. |
| `EmptyState` | Tinted symbol tile, 15pt title, one line that says how to fill it. History empty / no results, model picker no match. |
| `ModelPicker` | Popover: search field first (focused), text models only, grouped by family, newest first, and a "Use '<typed>' as a custom model ID" row. |
| `ReadsImages` | A per-preset switch the user sets. The app does not detect image support: OpenAI and Gemini model lists do not report it (checked 2026-11-01). |
| `SettingsRow` | Label (+ optional one-line explanation in `faint`) leading, one control trailing; rows grouped in a `content` box with hairline separators. |
| `ReplaceCapsule` | Replace Selection feedback: a non-activating capsule beside the mouse pointer (the selection's position is not reliably known). Spinner + preset name + "esc to cancel" while translating; check + "Replaced · ⌘Z to undo" for 1.5 s; a failure hands over to the `Notice` banner window, which says nothing was changed. When the focused field did not change after ⌘V, or the copied-from field could not be brought back before pasting, the banner says the translation is on the clipboard instead. Never takes key focus. |
| `ProviderLogo` | The provider's own mark from `Assets.xcassets` (`ProviderOpenAI`, `ProviderAnthropic`, `ProviderGemini`) in a 28pt tile; OpenAI-compatible endpoints use initials. Used in Providers, the Provider row of a preset, and Welcome. |
| `Toast` | Dark capsule with a check symbol, centred above the footer. Only "Copied". |
| `Welcome` | 800×500, two panes. Left, 290pt: the brand panel, `brand-deep` from the top to just past the text (white text reads at 7.7:1), lightening to `brand` at the bottom, behind a small drawing of the popup; it never changes between steps. Right: "Step N of 4" (12pt, `.tertiary`), a 20pt semibold title and a `.secondary` lead, the step, then a footer with 4 progress bars on the leading side and the buttons trailing. Steps: Intro (Get Started) → Provider (Back · Skip for now · Continue) → Shortcut (Back · Continue) → Done (Back · Open Translator). Back and Skip are text buttons; the primary is the one filled button and takes Return. Continue on Provider saves the key first and stays with the error if it cannot. Shortcut and Done show the shortcut as 22pt keycaps. |
| `ProviderSetupForm` | Shared by Welcome's Provider step and the popup's First-run sheet: three cards (`ProviderLogo`, name, one line in `.tertiary`; the chosen one ringed 2pt in the accent), "<Provider> API key" and a secure field, the error in red under it, then "Where do I get a key? ↗" to the provider's key page. Changing card clears the typed key. First-run: "Skip for now" · **Save & Start**. |

Popup states (footer primary in **bold**):

| State | Sheet | Footer |
|---|---|---|
| idle | Original: editor, focused, 17pt placeholder “Type or paste text”, and at the foot of the column one 12pt `faint` tip “Images work too — drop one here, press ⌘⇧V, or choose a file” (one light keycap, no icon; “choose a file” opens the file picker; shown only when the preset reads images); Translation: empty | **Translate ⌘↩** |
| streaming | Original dimmed and read-only; Translation streams with a caret; the `ColumnSeam` fills | Stop esc (not prominent) |
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
- Don't tint the button group or use the glass styles. With `.tint` the
  secondary button also turns accent-coloured and fades in dark mode, and
  tinted glass makes primary and secondary look alike (rendered on macOS 27,
  2026-11-02).
- Don't put an error inside the translation. It hides the result and reads
  like translated text; use a `Notice` (owner request, 2026-11-01).
- Don't use emoji as icons. One SF Symbol set, one weight.
- Don't lower the popup material's opacity below 92%. Text sits on it with no
  box, so legibility depends on it.
- Don't use a monospaced font for numbers or URLs in forms. It made rows in
  one form look like they came from different apps (audit D3, D13).
- Don't let focus land on the preset picker when the popup opens. It draws
  a ring and swallows ⌘⏎ (audit D4).
- Don't nest a scroll view inside a scrolling form (the preset prompt). Give
  the editor a fixed height and an "Expand" sheet at 80% of the window.
- Don't write a cost any other way than `CostFormat`: "96 tokens · $0.0004"
  (input plus output tokens), "price unknown" when the model has no price.
  The popup and History once showed "0.0004 USD · 56 tok" and "495 tokens"
  for the same translation.
- Don't put read-only text in a toolbar item: macOS draws it as a button
  capsule. History's daily total is the window subtitle.
- Don't open a window behind another one of the app's windows. Settings and
  History come to the front and cascade by 24pt.
