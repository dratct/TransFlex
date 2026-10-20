import CoreGraphics

/// Frame math for the output-only popup: fixed width, starts short and grows
/// downward with the streamed result until it reaches the cap, then scrolls.
enum QuickPopupSizing {
    static let widthRatio: CGFloat = 0.4
    static let maxHeightRatio: CGFloat = 0.6
    static let initialHeight: CGFloat = 200

    /// Starting frame. The top edge sits where a fully grown popup would be
    /// vertically centered, so growing never needs to move it.
    static func initialFrame(in visible: CGRect) -> CGRect {
        let width = visible.width * widthRatio
        let maxHeight = visible.height * maxHeightRatio
        let height = min(initialHeight, maxHeight)
        let top = visible.midY + maxHeight / 2
        return CGRect(x: visible.midX - width / 2, y: top - height, width: width, height: height)
    }

    /// Grown frame when the output overflows its visible area, or `nil` when
    /// no change is needed. Never shrinks, so the panel does not bounce.
    static func grownFrame(
        current: CGRect,
        outputContentHeight: CGFloat,
        outputVisibleHeight: CGFloat,
        in visible: CGRect
    ) -> CGRect? {
        let overflow = outputContentHeight - outputVisibleHeight
        guard overflow > 1 else { return nil }
        let maxHeight = visible.height * maxHeightRatio
        let height = min(current.height + overflow, maxHeight)
        guard height > current.height + 0.5 else { return nil }
        let originY = max(current.maxY - height, visible.minY)
        return CGRect(x: current.minX, y: originY, width: current.width, height: height)
    }
}
