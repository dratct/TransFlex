import SwiftUI

/// The "OpenAI-compatible" section of the Providers tab.
@MainActor
struct OpenAICompatList: View {
    @ObservedObject var store: ProvidersStore
    @State private var editingInstance: OpenAICompatInstance?
    @State private var isAdding = false

    var body: some View {
        Section {
            ForEach(store.config.openAICompatInstances, id: \.instanceId) { instance in
                LabeledContent {
                    Button("Edit…") { editingInstance = instance }
                } label: {
                    HStack(spacing: Spacing.m) {
                        ProviderLogo(providerID: "openai-compatible:\(instance.instanceId)", name: instance.displayName)
                        SettingsLabel(instance.displayName, caption: hostCaption(instance.baseURL))
                    }
                }
            }
            Button("Add Endpoint…") { isAdding = true }
        } header: {
            Text("OpenAI-compatible")
        } footer: {
            if store.config.openAICompatInstances.isEmpty {
                Text("Ollama, LM Studio, OpenRouter, or any server with /v1/chat/completions.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $isAdding) {
            OpenAICompatEditor(store: store, editing: nil)
        }
        .sheet(item: $editingInstance) { instance in
            OpenAICompatEditor(store: store, editing: instance)
        }
    }

    private func hostCaption(_ url: URL) -> String {
        guard let host = url.host else { return url.absoluteString }
        return url.port.map { "\(host):\($0)" } ?? host
    }
}
