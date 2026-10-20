import SwiftUI
import AppKit

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
                heroHeader
                cloudSection
                Divider()
                OpenAICompatList(store: store)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissFocus()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissFocus()
        }
        .onAppear {
            dismissFocusAsync()
        }
    }

    private var heroHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.brandAccent.gradient)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "server.rack")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Providers")
                    .font(.system(size: 16, weight: .semibold))
                Text("API keys and custom endpoints")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
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

    private func dismissFocus() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private func dismissFocusAsync() {
        DispatchQueue.main.async {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }
}
