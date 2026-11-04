import CoreGraphics

/// The popup's frame, from the mode, the screen and, for Translate Selection,
/// the size its source predicts (DESIGN.md › Layout). Nothing carries over
/// from the last open.
enum PopupFrame {
    enum Mode { case popup, outputOnly }

    static let popupRatio: CGFloat = 0.6
    static let popupMinSize = CGSize(width: 520, height: 360)
    static let outputOnlyWidthRatio: CGFloat = 0.4
    static let outputOnlyMinWidth: CGFloat = 420
    static let outputOnlyMinHeight: CGFloat = 160
    static let outputOnlyMaxHeightRatio: CGFloat = 0.6
    /// About 80 characters a line at the translation size: wider lines read badly.
    static let outputOnlyMaxWidth: CGFloat = 660
    private static let widthStep: CGFloat = 20
    /// Header, column label and footer around the Translation scroll view,
    /// measured in the running app as panel height minus the scroll view's.
    static let outputOnlyChrome: CGFloat = 128

    static func initial(_ mode: Mode, in visible: CGRect) -> CGRect {
        switch mode {
        case .popup:
            let width = min(max(visible.width * popupRatio, popupMinSize.width), visible.width)
            let height = min(max(visible.height * popupRatio, popupMinSize.height), visible.height)
            return CGRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height)
        case .outputOnly:
            return outputOnlyFrame(width: outputOnlyBaseWidth(in: visible), contentHeight: 0, in: visible)
        }
    }

    /// The output-only frame its source predicts: tall enough for
    /// `chromeHeight` plus `textHeight(columnWidth)`, widened toward
    /// `outputOnlyMaxWidth` only while that still overflows the height cap.
    static func predicted(
        textHeight: (CGFloat) -> CGFloat,
        chromeHeight: CGFloat,
        in visible: CGRect
    ) -> CGRect {
        let maxHeight = visible.height * outputOnlyMaxHeightRatio
        let maxWidth = min(outputOnlyMaxWidth, visible.width)
        func contentHeight(_ width: CGFloat) -> CGFloat {
            chromeHeight + textHeight(width - 2 * ColumnLayout.sideMargin)
        }
        // When even the widest frame overflows, skip measuring every width between.
        var width = contentHeight(maxWidth) > maxHeight ? maxWidth : outputOnlyBaseWidth(in: visible)
        while contentHeight(width) > maxHeight, width < maxWidth {
            width = min(width + widthStep, maxWidth)
        }
        return outputOnlyFrame(width: width, contentHeight: contentHeight(width), in: visible)
    }

    private static func outputOnlyBaseWidth(in visible: CGRect) -> CGFloat {
        min(max(visible.width * outputOnlyWidthRatio, outputOnlyMinWidth), outputOnlyMaxWidth, visible.width)
    }

    /// The top edge sits where a fully grown popup would be centred, so
    /// growing with the result never moves it.
    private static func outputOnlyFrame(width: CGFloat, contentHeight: CGFloat, in visible: CGRect) -> CGRect {
        let maxHeight = visible.height * outputOnlyMaxHeightRatio
        let height = min(max(contentHeight, outputOnlyMinHeight), maxHeight)
        let top = visible.midY + maxHeight / 2
        return CGRect(x: visible.midX - width / 2, y: top - height, width: width, height: height)
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
