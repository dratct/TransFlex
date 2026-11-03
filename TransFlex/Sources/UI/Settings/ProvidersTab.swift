import SwiftUI

@MainActor
struct ProvidersTab: View {
    @ObservedObject var store: ProvidersStore

    private let cloudProviders: [(id: String, name: String, caption: String)] = [
        ("openai", "OpenAI", "GPT models"),
        ("anthropic", "Anthropic", "Claude models"),
        ("gemini", "Gemini", "Google AI Studio key"),
    ]

    var body: some View {
        SettingsForm {
            Section {
                ForEach(cloudProviders, id: \.id) { provider in
                    CloudProviderRow(
                        store: store,
                        providerID: provider.id,
                        displayName: provider.name,
                        caption: provider.caption
                    )
                }
            } header: {
                Text("Cloud providers")
            } footer: {
                Text("Keys live in your Mac’s Keychain and go only to their provider.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            OpenAICompatList(store: store)
        }
    }
}
