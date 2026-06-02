import SwiftUI

@MainActor
struct ProvidersTab: View {
    @ObservedObject var store: ProvidersStore

    // Brand icons sourced from LobeHub Icons (MIT) and bundled in
    // Assets.xcassets as template SVGs — they tint via `.foregroundStyle()`.
    private let cloudProviders: [(id: String, name: String, icon: String)] = [
        ("openai", "OpenAI", "ProviderOpenAI"),
        ("anthropic", "Anthropic", "ProviderAnthropic"),
        ("gemini", "Gemini", "ProviderGemini"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cloudSection
                Divider()
                OpenAICompatList(store: store)
            }
            .padding(20)
        }
    }

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cloud Providers")
                .font(.system(size: 13, weight: .semibold))

            ForEach(cloudProviders, id: \.id) { provider in
                CloudProviderRow(
                    store: store,
                    providerID: provider.id,
                    displayName: provider.name,
                    icon: provider.icon
                )
            }
        }
    }
}
