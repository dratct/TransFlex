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
    @Environment(\.colorScheme) private var colorScheme

    /// The fill never reaches this while streaming, so it never reads as finished.
    static let maxStreamingFill = 0.92

    /// How far the seam fills while streaming, from translation length over
    /// source length. Eases toward `maxStreamingFill` instead of stopping at a
    /// cap, because a translation often runs longer than its source.
    static func fill(translatedCount: Int, sourceCount: Int) -> Double {
        guard sourceCount > 0 else { return 0 }
        let ratio = Double(translatedCount) / Double(sourceCount)
        return maxStreamingFill * (1 - exp(-1.6 * ratio))
    }

    private let sparkGap: CGFloat = 26
    private let dotSize: CGFloat = 7
    /// One pass of the light that runs along the rule while streaming.
    private let cometPeriod: Double = 1.4
    private let cometLength: CGFloat = 56
    private let pulsePeriod: Double = 1.2

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

    /// The filled rule, a light running down it, and the breathing lead dot.
    /// Before the first token (`fill == 0`) the light runs the whole rule so
    /// the seam shows the request is alive. Reduce Motion keeps only the fill.
    private func streaming(length: CGFloat, fill: Double) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            streamingFrame(
                length: length,
                fill: fill,
                comet: reduceMotion ? nil : t.truncatingRemainder(dividingBy: cometPeriod) / cometPeriod,
                pulse: reduceMotion ? 0.5 : 0.5 + 0.5 * sin(2 * .pi * t / pulsePeriod)
            )
        }
    }

    private func streamingFrame(length: CGFloat, fill: Double, comet: Double?, pulse: Double) -> some View {
        let lead = length * fill
        let vertical = direction == .vertical
        let start: Alignment = vertical ? .top : .leading
        let easing: Animation? = reduceMotion ? nil : .easeOut(duration: 0.35)
        return line(Color(nsColor: .separatorColor))
            .overlay(alignment: start) {
                // Before the first token the light runs the bare rule.
                if fill == 0, let comet { cometLight(phase: comet, span: length) }
            }
            .overlay(alignment: start) {
                // The light rides inside the fill and is clipped to it, so it
                // never shows past the lead while the fill eases forward.
                line(Color.accentText)
                    .overlay(alignment: start) {
                        if let comet { cometLight(phase: comet, span: lead) }
                    }
                    .frame(width: vertical ? 1.5 : lead, height: vertical ? lead : 1.5, alignment: start)
                    .clipped()
                    .animation(easing, value: fill)
            }
            .overlay(alignment: start) {
                if fill > 0 {
                    Circle()
                        .fill(Color.accentText)
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(0.9 + 0.2 * pulse)
                        .shadow(color: reduceMotion ? .clear : Color.accentText.opacity(0.35 + 0.35 * pulse),
                                radius: 4 + 6 * pulse)
                        .offset(x: vertical ? 0 : lead - dotSize / 2, y: vertical ? lead - dotSize / 2 : 0)
                        .animation(easing, value: fill)
                }
            }
            .mask(trailingFade.padding(-dotSize - 6))
    }

    /// One pass of the running light; its wrap back to the start is never eased.
    private func cometLight(phase: Double, span: CGFloat) -> some View {
        let vertical = direction == .vertical
        let offset = (span + cometLength) * phase - cometLength
        return LinearGradient(colors: [.clear, cometColor, .clear], startPoint: startPoint, endPoint: endPoint)
            .frame(width: vertical ? 1.5 : cometLength, height: vertical ? cometLength : 1.5)
            .offset(x: vertical ? 0 : offset, y: vertical ? offset : 0)
            .transaction { $0.animation = nil }
    }

    /// Lighter than the fill so the running light shows on it in both modes.
    private var cometColor: Color {
        colorScheme == .dark ? .white.opacity(0.85) : .brand
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
