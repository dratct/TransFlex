import SwiftUI

@MainActor
struct PresetEditor: View {
    @ObservedObject var presetStore: PresetStore
    @ObservedObject var providersStore: ProvidersStore
    let preset: Preset

    @State private var draft: Preset
    @State private var availableModels: [Model] = []
    @State private var isFetchingModels = false
    @State private var errorMessage: String?
    @State private var isPromptExpanded = false
    @State private var isAdvancedExpanded = false
    @State private var isFallbackList = false

    private static let modelCache = ModelCatalogCache()


    init(presetStore: PresetStore, providersStore: ProvidersStore, preset: Preset) {
        self.presetStore = presetStore
        self.providersStore = providersStore
        self.preset = preset
        self._draft = State(initialValue: preset)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroHeader

                SettingsSection("Identity") {
                    formRow(label: "Name") {
                        TextField("Preset name", text: $draft.name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 320)
                    }
                }

                SettingsSection("Backend") {
                    formRow(label: "Provider") {
                        Picker("", selection: Binding(
                            get: { draft.providerID },
                            set: { newValue in
                                draft.providerID = newValue
                                draft.modelID = ""
                            }
                        )) {
                            ForEach(allProviderIDs(), id: \.self) { id in
                                Text(providerLabel(for: id)).tag(id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 260, alignment: .trailing)
                    }

                    rowDivider

                    formRow(label: "Model", trailingExtra: modelLoadingIndicator) {
                        modelControl
                    }
                }

                systemPromptSection

                SettingsSection("Behavior") {
                    formRow(label: "Temperature", trailingExtra: temperatureValue) {
                        Slider(value: $draft.temperature, in: 0...1)
                            .controlSize(.small)
                            .frame(maxWidth: 220, alignment: .trailing)
                    }

                    rowDivider

                    formRow(label: "Top P", trailingExtra: topPDisplay) {
                        HStack(spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: { draft.topP ?? 1.0 },
                                    set: { draft.topP = $0 }
                                ),
                                in: 0...1
                            )
                            if draft.topP != nil {
                                Button {
                                    draft.topP = nil
                                } label: {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("Reset to provider default")
                            }
                        }
                        .controlSize(.small)
                        .frame(maxWidth: 220, alignment: .trailing)
                    }

                    rowDivider

                    formRow(label: "Max Tokens") {
                        TextField(
                            "Default",
                            text: Binding(
                                get: { draft.maxTokens.map { String($0) } ?? "" },
                                set: { newValue in
                                    let digits = newValue.filter { $0.isNumber }
                                    draft.maxTokens = Int(digits)
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100, alignment: .trailing)
                    }

                    rowDivider

                    formRow(label: "Supports Vision") {
                        Toggle("", isOn: $draft.supportsVision)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.small)
                    }
                }

                advancedSection

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: draft.providerID) { newID in
            loadModels(for: newID)
        }
        .onAppear {
            loadModels(for: draft.providerID)
        }
        .onChange(of: draft) { updated in
            saveDraft(updated)
        }
        .sheet(isPresented: $isPromptExpanded) {
            PromptFullScreenEditor(
                title: draft.name.isEmpty ? "System Prompt" : draft.name,
                text: $draft.systemPrompt,
                isReadOnly: false,
                isPresented: $isPromptExpanded
            )
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.brandAccent.gradient)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "text.badge.star")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.name.isEmpty ? "Untitled Preset" : draft.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(providerLabel(for: draft.providerID))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Form primitives

    private func formRow<Control: View>(
        label: String,
        trailingExtra: AnyView? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 12))
            
            Spacer(minLength: 16)
            
            control()
            
            if let trailingExtra {
                trailingExtra
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var rowDivider: some View {
        Divider()
            .opacity(0.5)
            .padding(.leading, 14)
    }

    // MARK: - Model row

    @ViewBuilder
    private var modelControl: some View {
        if availableModels.isEmpty {
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    TextField("Model ID", text: $draft.modelID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: 290, alignment: .trailing)
                    refreshButton
                }
                fallbackCaption
            }
        } else {
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Picker("", selection: $draft.modelID) {
                        Text("Custom…").tag("")
                        ForEach(availableModels, id: \.id) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 230, alignment: .trailing)
                    refreshButton
                }

                if draft.modelID.isEmpty || availableModels.allSatisfy({ $0.id != draft.modelID }) {
                    TextField("Custom model ID", text: $draft.modelID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: 320, alignment: .trailing)
                }

                fallbackCaption
            }
        }
    }

    private var refreshButton: some View {
        Button {
            loadModels(for: draft.providerID, forceRefresh: true)
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(.borderless)
        .disabled(isFetchingModels)
        .help("Refresh model list from the provider")
    }

    @ViewBuilder
    private var fallbackCaption: some View {
        if isFallbackList {
            Text("Showing built-in list — add an API key in the Providers tab to load the full catalog.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
    }

    private var modelLoadingIndicator: AnyView? {
        guard isFetchingModels else { return nil }
        return AnyView(
            ProgressView()
                .controlSize(.small)
        )
    }

    // MARK: - System prompt

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SYSTEM PROMPT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                    .padding(.leading, 4)

                Spacer()

                Text("\(draft.systemPrompt.count) chars")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Button {
                    isPromptExpanded = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help("Edit prompt in larger window")
            }

            VStack(spacing: 0) {
                TextEditor(text: $draft.systemPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
                    )
                    .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Temperature

    private var temperatureValue: AnyView? {
        AnyView(
            Text(String(format: "%.2f", draft.temperature))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        )
    }

    private var topPDisplay: AnyView? {
        guard draft.topP != nil else { return nil }
        return AnyView(
            Text(String(format: "%.2f", draft.topP ?? 1.0))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        )
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $isAdvancedExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text("Extra parameters merged into the API request body (JSON). Use for provider-specific features like thinking mode.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !isExtraBodyValid {
                        Text("⚠ Invalid JSON")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 14)

                TextEditor(
                    text: Binding(
                        get: { draft.extraBody ?? "" },
                        set: { draft.extraBody = $0.isEmpty ? nil : $0 }
                    )
                )
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
                )
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 10)
        } label: {
            Text("ADVANCED")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
        }
        .padding(.horizontal, 4)
    }

    private var isExtraBodyValid: Bool {
        guard let text = draft.extraBody, !text.isEmpty else { return true }
        return (try? JSONSerialization.jsonObject(with: Data(text.utf8))) != nil
    }

    // MARK: - Provider helpers

    private func providerLabel(for id: String) -> String {
        switch id {
        case "openai": return "OpenAI"
        case "anthropic": return "Anthropic"
        case "gemini": return "Gemini"
        default:
            if id.hasPrefix("openai-compatible:") {
                let instanceId = String(id.dropFirst("openai-compatible:".count))
                if let displayName = ProviderRegistry.shared.compatInstance(instanceId)?.displayName,
                   !displayName.isEmpty {
                    return displayName
                }
                return "Custom Endpoint"
            }
            return id
        }
    }

    private func allProviderIDs() -> [String] {
        let cloud = ["openai", "anthropic", "gemini"]
        let compat = ProviderRegistry.shared.allProviderIDs.filter { $0.hasPrefix("openai-compatible:") }
        return cloud + compat
    }

    private func resolveAPIKey(for providerID: String) -> String {
        if providerID.hasPrefix("openai-compatible:") {
            let instanceId = String(providerID.dropFirst("openai-compatible:".count))
            return providersStore.compatAPIKey(for: instanceId)
        }
        return providersStore.cloudAPIKey(for: providerID)
    }

    private func loadModels(for providerID: String, forceRefresh: Bool = false) {
        if !forceRefresh {
            availableModels = []
            isFallbackList = false
        }
        isFetchingModels = true
        errorMessage = nil

        Task {
            let apiKey = resolveAPIKey(for: providerID)

            if forceRefresh {
                await Self.modelCache.invalidate(providerID)
            } else if let cached = await Self.modelCache.cached(for: providerID) {
                guard providerID == draft.providerID else { return }
                availableModels = cached
                isFallbackList = false
                isFetchingModels = false
                return
            }

            do {
                let provider = try ProviderRegistry.shared.provider(for: providerID)
                let models = try await provider.availableModels(apiKey: apiKey)
                guard providerID == draft.providerID else { return }
                availableModels = models
                let fetched = models.contains { $0.source == .fetched }
                isFallbackList = !fetched
                if fetched {
                    await Self.modelCache.put(models, for: providerID)
                }
            } catch {
                guard providerID == draft.providerID else { return }
                errorMessage = "Could not load models: \(error.localizedDescription)"
                isFallbackList = true
            }
            isFetchingModels = false
        }
    }

    private func saveDraft(_ updated: Preset) {
        do {
            try presetStore.update(updated)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }


}

@MainActor
private struct PromptFullScreenEditor: View {
    let title: String
    @Binding var text: String
    let isReadOnly: Bool
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                if isReadOnly {
                    Text("Read-only")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                Text("\(text.count) chars")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(14)
                .background(Color(nsColor: .textBackgroundColor))
                .disabled(isReadOnly)
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}
