import SwiftUI

/// The preset's provider has no key yet: say so and offer the way to add it.
/// Nothing was sent, and the user's text stays behind the card.
struct MissingKeyNotice: View {
    let providerID: String
    let presetName: String?

    var body: some View {
        let provider = ProviderRegistry.shared.displayName(for: providerID)
        Notice(
            .card,
            tone: .warning,
            symbol: "key",
            title: "Add \(article(provider)) \(provider) key",
            message: presetName.map { "“\($0)” uses \(provider). Add a key in Settings; your text stays here." }
                ?? "Add a key in Settings; your text stays here."
        ) {
            FooterAction("Open Settings", keys: ["⌘", ","], prominence: .primary) {
                AppCommands.openSettings(tab: .providers)
            }
        }
    }

    private func article(_ word: String) -> String {
        guard let first = word.lowercased().first else { return "a" }
        return "aeio".contains(first) ? "an" : "a"
    }
}
