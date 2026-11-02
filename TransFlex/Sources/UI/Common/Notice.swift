import SwiftUI

/// Errors and requests, always outside the translation text.
/// `.card` replaces the popup sheet when there is nothing to show;
/// `.strip` docks between the sheet and the footer when a partial result exists.
struct Notice<Actions: View>: View {
    enum Style { case card, strip }
    enum Tone {
        case info, warning, error
        var color: Color {
            switch self {
            case .info: return .accentColor
            case .warning: return .orange
            case .error: return .red
            }
        }
    }

    let style: Style
    let tone: Tone
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder var actions: () -> Actions

    init(
        _ style: Style,
        tone: Tone,
        symbol: String,
        title: String,
        message: String,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.style = style
        self.tone = tone
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actions = actions
    }

    var body: some View {
        switch style {
        case .card: card
        case .strip: strip
        }
    }

    private var card: some View {
        VStack(spacing: Spacing.s) {
            SymbolTile(symbol: symbol, color: tone.color, size: 52)
                .padding(.bottom, Spacing.xs)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            HStack(spacing: Spacing.m) { actions() }
                .padding(.top, Spacing.s)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ContentBox())
    }

    private var strip: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tone.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Spacing.s) { actions() }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(ContentBox())
    }
}

/// Tinted rounded square holding an SF Symbol: notices and empty states.
struct SymbolTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 52

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(color.opacity(0.14))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(color)
            )
            .accessibilityHidden(true)
    }
}

/// The `content` surface: a flat box on `surface` with a hairline outline.
struct ContentBox: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.pane, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.pane, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
}
