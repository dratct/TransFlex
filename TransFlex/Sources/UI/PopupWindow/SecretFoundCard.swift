import SwiftUI

/// The Secret check stopped a text before it was sent. The card names the
/// kind and shows the masked value; the footer carries Back to text and
/// Send anyway.
struct SecretFoundCard: View {
    let match: SecretMatch
    let providerID: String

    var body: some View {
        Notice(
            .card,
            tone: .warning,
            symbol: "exclamationmark.shield",
            title: "\(match.kind) found",
            message: Self.message(for: match, provider: ProviderRegistry.shared.displayName(for: providerID))
        ) {
            EmptyView()
        }
    }

    static func message(for match: SecretMatch, provider: String) -> String {
        let rest = "Not sent to \(provider). Turn this check off in Settings › General."
        return match.masked.isEmpty ? rest : "\(match.masked) · \(rest)"
    }
}
