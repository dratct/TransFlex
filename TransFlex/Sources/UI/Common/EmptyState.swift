import SwiftUI

/// "Nothing here yet" with the one line that says how to fill it.
/// Custom rather than `ContentUnavailableView`, which needs macOS 14.
struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.s) {
            SymbolTile(symbol: symbol, color: .accentColor, size: 44)
                .padding(.bottom, Spacing.xs)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
