import SwiftUI

/// Spacing scale from docs/design/DESIGN.md › Layout.
enum Spacing {
    /// Icon ↔ label.
    static let xs: CGFloat = 4
    /// Inside a group.
    static let s: CGFloat = 8
    /// Pane padding, between footer buttons.
    static let m: CGFloat = 12
    /// Window edge.
    static let l: CGFloat = 16
    /// Between sections.
    static let xl: CGFloat = 24
}

/// Corner radii from docs/design/DESIGN.md › Shapes.
enum Radius {
    /// Inner controls: search field, chips.
    static let control: CGFloat = 6
    /// Cards, notices, sheets drawn by the app.
    static let pane: CGFloat = 10
    /// The popup window.
    static let window: CGFloat = 12
}

/// The popup's two reading sizes. Line height is 1.6 of the font size;
/// SwiftUI adds `lineSpacing` on top of SF Pro's own ~1.2 line height.
enum ReadingType {
    static let original = Font.system(size: 15)
    static let originalLineSpacing: CGFloat = 6
    static let translation = Font.system(size: 17)
    static let translationLineSpacing: CGFloat = 7
    /// "ORIGINAL" / "TRANSLATION" column labels.
    static let columnLabel = Font.system(size: 11, weight: .semibold)
    static let columnLabelTracking: CGFloat = 0.66
}

/// The popup's column layout (DESIGN.md › Components › TranslationColumns).
enum ColumnLayout {
    static let sideMargin: CGFloat = 28
    static let gutter: CGFloat = 26
    /// Narrower than this, the columns stack.
    static let sideBySideMinWidth: CGFloat = 720
    /// Stacked, the Original takes this share of the height, whatever the state.
    static let stackedOriginalShare: CGFloat = 0.38
}

enum Motion {
    /// Toast and state swaps. Frame changes are never animated.
    static let stateSwap = Animation.easeOut(duration: 0.15)
}
