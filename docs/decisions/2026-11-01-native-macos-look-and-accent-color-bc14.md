# Native macOS look on macOS 13+, emerald as the app accent colour

Status: accepted — 2026-11-01

## Context

The popup, Settings, Welcome and History windows each set their own fonts,
radii and colours, and every window forces the emerald brand colour with
`.tint(.brandAccent)`. Built with Xcode 26 or later, standard controls,
toolbars, sidebars and grouped forms take on Liquid Glass by themselves on
macOS 26+, and there is no opt-out once built with the macOS 27 SDK. The
glass APIs (`glassEffect`, `.buttonStyle(.glass)`, `NSGlassEffectView`)
require macOS 26; the app supports macOS 13. Apple's HIG keeps glass for the
control layer, not text-heavy content, and users can tint glass down or turn
transparency off.

## Decision

- Keep the macOS 13.0 deployment target. Use system materials, system text
  styles, system semantic colours and standard controls (`Form` with
  `.formStyle(.grouped)` in Settings). No glass API, so no `if #available`
  branch for the look.
- Emerald moves into an `AccentColor` asset. It shows when the user's system
  accent is Multicolor; any other system accent replaces it, as in Apple's
  own apps. No view forces `.tint(.brandAccent)`.
- A fixed emerald stays only on identity elements: app icon, logo, Welcome.

## Consequences

- On macOS 26+ the app picks up the system's glass on standard controls
  without code of its own; the custom popup body keeps a material.
- Users with a non-Multicolor accent see their colour on buttons and focus.
- Glass-styled popup controls can be added later behind `#available` without
  reworking the tokens.

Rejected: raising the target to macOS 26 to use glass directly (drops
macOS 13–25 users); glass for the popup body (against the HIG's legibility
rule for text-heavy surfaces).
