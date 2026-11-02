import SwiftUI

/// Custom colours from docs/design/DESIGN.md. Everything else uses the
/// system's semantic colours; the accent itself is the `AccentColor` asset.
extension Color {
    /// Fixed brand green for the logo, app icon glow and Welcome illustration.
    /// Never for controls: those follow the user's system accent.
    static let brand = Color(red: 0x21 / 255, green: 0xB3 / 255, blue: 0x8C / 255)

    /// The dark end of the Welcome panel. White text sits on this end only:
    /// it clears 4.5:1 here and not on `brand`.
    static let brandDeep = Color(red: 0x0B / 255, green: 0x5E / 255, blue: 0x4A / 255)

    /// Small accent-coloured text and marks (the Translation label, the
    /// column seam). Brighter than the accent in dark mode so it stays legible.
    static let accentText = Color("AccentText")
}
