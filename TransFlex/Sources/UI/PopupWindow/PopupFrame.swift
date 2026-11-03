import CoreGraphics

/// The popup's frame, from the mode and the screen alone (DESIGN.md › Layout).
/// Every open starts from `initial`; nothing carries over from the last open.
enum PopupFrame {
    enum Mode { case popup, outputOnly }

    static let popupRatio: CGFloat = 0.6
    static let popupMinSize = CGSize(width: 520, height: 360)
    static let outputOnlyWidthRatio: CGFloat = 0.4
    static let outputOnlyMinWidth: CGFloat = 420
    static let outputOnlyMinHeight: CGFloat = 160
    static let outputOnlyMaxHeightRatio: CGFloat = 0.6

    static func initial(_ mode: Mode, in visible: CGRect) -> CGRect {
        switch mode {
        case .popup:
            let width = min(max(visible.width * popupRatio, popupMinSize.width), visible.width)
            let height = min(max(visible.height * popupRatio, popupMinSize.height), visible.height)
            return CGRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height)
        case .outputOnly:
            // Starts short; the top edge sits where a fully grown popup would be
            // centred, so growing with the result never moves it.
            let width = min(max(visible.width * outputOnlyWidthRatio, outputOnlyMinWidth), visible.width)
            let maxHeight = visible.height * outputOnlyMaxHeightRatio
            let height = min(outputOnlyMinHeight, maxHeight)
            let top = visible.midY + maxHeight / 2
            return CGRect(x: visible.midX - width / 2, y: top - height, width: width, height: height)
        }
    }

    /// The output-only frame grown downward when the result overflows, or
    /// `nil` when no change is needed. Never shrinks, so the panel does not bounce.
    static func grown(
        current: CGRect,
        outputContentHeight: CGFloat,
        outputVisibleHeight: CGFloat,
        in visible: CGRect
    ) -> CGRect? {
        let overflow = outputContentHeight - outputVisibleHeight
        guard overflow > 1 else { return nil }
        let maxHeight = visible.height * outputOnlyMaxHeightRatio
        let height = min(current.height + overflow, maxHeight)
        guard height > current.height + 0.5 else { return nil }
        let originY = max(current.maxY - height, visible.minY)
        return CGRect(x: current.minX, y: originY, width: current.width, height: height)
    }
}
