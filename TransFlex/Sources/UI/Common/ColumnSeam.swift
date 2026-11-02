import SwiftUI

/// The rule between the popup's Original and Translation columns: a fading
/// hairline broken by a spark. While a translation streams it fills with the
/// accent, led by a dot. Decorative; VoiceOver skips it.
struct ColumnSeam: View {
    enum Direction { case vertical, horizontal }

    var direction: Direction = .vertical
    /// nil at rest (spark shown); 0...1 while streaming.
    var fill: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far the seam fills while streaming: translation length over source
    /// length, held below 90% so it never reads as finished before the stream ends.
    static func fill(translatedCount: Int, sourceCount: Int) -> Double {
        guard sourceCount > 0 else { return 0 }
        return min(Double(translatedCount) / Double(sourceCount), 0.9)
    }

    private let sparkGap: CGFloat = 26
    private let dotSize: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            let length = direction == .vertical ? geo.size.height : geo.size.width
            ZStack(alignment: direction == .vertical ? .top : .leading) {
                if let fill {
                    streaming(length: length, fill: fill)
                } else {
                    resting(length: length)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(width: direction == .vertical ? 1 : nil, height: direction == .horizontal ? 1 : nil)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: fill)
        .accessibilityHidden(true)
    }

    // The spark and the dot are overlays so they never widen the 1pt rule.
    private func resting(length: CGFloat) -> some View {
        line(Color(nsColor: .separatorColor))
            .mask(fadeMask(gapAround: 0.5, gap: sparkGap / max(length, 1)))
            .overlay {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentText)
                    .fixedSize()
            }
    }

    private func streaming(length: CGFloat, fill: Double) -> some View {
        let lead = length * fill
        let vertical = direction == .vertical
        let start: Alignment = vertical ? .top : .leading
        return line(Color(nsColor: .separatorColor))
            .overlay(alignment: start) {
                line(Color.accentText)
                    .frame(width: vertical ? 1.5 : lead, height: vertical ? lead : 1.5)
            }
            .overlay(alignment: start) {
                Circle()
                    .fill(Color.accentText)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: reduceMotion ? .clear : Color.accentText.opacity(0.55), radius: 7)
                    .offset(x: vertical ? 0 : lead - dotSize / 2, y: vertical ? lead - dotSize / 2 : 0)
            }
            .mask(trailingFade.padding(-dotSize))
    }

    private func line(_ color: Color) -> some View {
        Rectangle().fill(color)
    }

    private var startPoint: UnitPoint { direction == .vertical ? .top : .leading }
    private var endPoint: UnitPoint { direction == .vertical ? .bottom : .trailing }

    /// Fades both ends and cuts a gap around `gapAround` for the spark.
    private func fadeMask(gapAround center: Double, gap: Double) -> some View {
        let half = gap / 2
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.16),
                .init(color: .black, location: max(0.16, center - half - 0.02)),
                .init(color: .clear, location: center - half),
                .init(color: .clear, location: center + half),
                .init(color: .black, location: min(0.84, center + half + 0.02)),
                .init(color: .black, location: 0.84),
                .init(color: .clear, location: 1),
            ],
            startPoint: startPoint, endPoint: endPoint
        )
    }

    private var trailingFade: some View {
        LinearGradient(
            stops: [.init(color: .black, location: 0.84), .init(color: .clear, location: 1)],
            startPoint: startPoint, endPoint: endPoint
        )
    }
}
