import SwiftUI
import KeyboardShortcuts

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
    @State private var promptSheetSize = CGSize(width: 640, height: 480)
    @State private var isFallbackList = false

    private static let modelCache = ModelCatalogCache()


    init(presetStore: PresetStore, providersStore: ProvidersStore, preset: Preset) {
        self.presetStore = presetStore
        self.providersStore = providersStore
        self.preset = preset
        self._draft = State(initialValue: preset)
    }

    var body: some View {
        SettingsForm {
            Section {
                TextField("Name", text: $draft.name, prompt: Text("Preset name"))
                Picker("Provider", selection: Binding(
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
                LabeledContent {
                    modelControl
                } label: {
                    HStack(spacing: Spacing.s) {
                        Text("Model")
                        if isFetchingModels { ProgressView().controlSize(.small) }
                    }
                }
                Toggle(isOn: $draft.supportsVision) {
                    SettingsLabel(
                        "Reads images",
                        caption: "Turn on if this model accepts images. Lets you attach screenshots in the popup."
                    )
                }
                .toggleStyle(.switch)
            }

            Section {
                // A fixed height: the form scrolls, the prompt does not grow
                // a second scroller inside it; Expand opens it large.
                TextEditor(text: $draft.systemPrompt)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(height: 120)
            } header: {
                HStack {
                    Text("Instructions")
                    Spacer()
                    Text("\(draft.systemPrompt.count.formatted()) characters")
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                    Button("Expand") { openPromptSheet() }
                        .buttonStyle(.link)
                }
            }

            Section("Shortcuts") {
                SettingsRow("Choose this preset", caption: "Makes it the popup’s preset.") {
                    KeyboardShortcuts.Recorder(for: .preset(draft.id))
                        .shortcutValidation(ShortcutConflicts.validator(for: .preset(draft.id)) { presetStore.presets })
                }
                SettingsRow("Translate selection", caption: "Shows the translation in a small popup.") {
                    KeyboardShortcuts.Recorder(for: .presetQuickPopup(draft.id))
                        .shortcutValidation(ShortcutConflicts.validator(for: .presetQuickPopup(draft.id)) { presetStore.presets })
                }
                SettingsRow("Replace selection", caption: "Pastes the translation over the selected text.") {
                    KeyboardShortcuts.Recorder(for: .presetQuickReplace(draft.id))
                        .shortcutValidation(ShortcutConflicts.validator(for: .presetQuickReplace(draft.id)) { presetStore.presets })
                }
            }

            Section("Tuning") {
                SettingsRow("Temperature") {
                    HStack(spacing: Spacing.s) {
                        Slider(value: $draft.temperature, in: 0...1)
                            .frame(width: 200)
                        valueLabel(String(format: "%.2f", draft.temperature))
                    }
                }
                SettingsRow("Top P") {
                    HStack(spacing: Spacing.s) {
                        Slider(
                            value: Binding(get: { draft.topP ?? 1.0 }, set: { draft.topP = $0 }),
                            in: 0...1
                        )
                        .frame(width: 200)
                        valueLabel(draft.topP.map { String(format: "%.2f", $0) } ?? "Default")
                        if draft.topP != nil {
                            Button {
                                draft.topP = nil
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .buttonStyle(.borderless)
                            .help("Use the provider’s default")
                            .accessibilityLabel("Use the provider’s default")
                        }
                    }
                }
                SettingsRow("Max tokens", caption: "Leave empty for the provider’s default.") {
                    TextField(
                        "Max tokens",
                        text: Binding(
                            get: { draft.maxTokens.map { String($0) } ?? "" },
                            set: { draft.maxTokens = Int($0.filter(\.isNumber)) }
                        ),
                        prompt: Text("Default")
                    )
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                }
                if !effortLevels.isEmpty {
                    Picker("Effort", selection: $draft.effort) {
                        Text("Default (\(AnthropicModelSupport.defaultEffort))").tag(String?.none)
                        ForEach(effortLevels, id: \.self) { level in
                            Text(level).tag(String?.some(level))
                        }
                    }
                }
            }

            Section {
                TextEditor(text: Binding(
                    get: { draft.extraBody ?? "" },
                    set: { draft.extraBody = $0.isEmpty ? nil : $0 }
                ))
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(height: 72)
                .overlay(alignment: .topLeading) {
                    if (draft.extraBody ?? "").isEmpty {
                        Text(#"{ "reasoning_effort": "low" }"#)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
            } header: {
                Text("Extra request fields")
            } footer: {
                Text(isExtraBodyValid
                     ? "JSON merged into the request body, for provider-specific options."
                     : "This is not valid JSON, so it is not sent.")
                    .font(.caption)
                    .foregroundStyle(isExtraBodyValid ? Color(nsColor: .tertiaryLabelColor) : .red)
            }

            if let error = errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .onChange(of: draft.providerID) { newID in
            loadModels(for: newID)
        }
        .onChange(of: draft.modelID) { newModel in
            // Show the level actually sent instead of a blank picker.
            if let effort = draft.effort, !effortLevels.isEmpty, !effortLevels.contains(effort) {
                draft.effort = AnthropicModelSupport.resolvedEffort(effort, for: newModel)
            }
        }
        .onAppear {
            loadModels(for: draft.providerID)
        }
        .onChange(of: draft) { updated in
            saveDraft(updated)
        }
        .sheet(isPresented: $isPromptExpanded) {
            PromptFullScreenEditor(
                title: draft.name.isEmpty ? "Instructions" : draft.name,
                text: $draft.systemPrompt,
                isReadOnly: false,
                isPresented: $isPromptExpanded
            )
            .frame(width: promptSheetSize.width, height: promptSheetSize.height)
        }
    }

    /// The Expand sheet takes 80% of the Settings window (DESIGN.md › Do's and Don'ts).
    private func openPromptSheet() {
        if let window = NSApp.keyWindow {
            promptSheetSize = CGSize(width: window.frame.width * 0.8, height: window.frame.height * 0.8)
        }
        isPromptExpanded = true
    }

    private func valueLabel(_ text: String) -> some View {
        Text(text)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 52, alignment: .trailing)
    }

    // MARK: - Model row

    private var modelControl: some View {
        HStack(spacing: 6) {
            ModelPicker(
                modelID: $draft.modelID,
                models: availableModels,
                providerName: providerLabel(for: draft.providerID),
                isBuiltInList: isFallbackList
            )
            refreshButton
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

    private var effortLevels: [String] {
        guard draft.providerID == "anthropic" else { return [] }
        return AnthropicModelSupport.effortLevels(draft.modelID)
    }

    private var isExtraBodyValid: Bool {
        guard let text = draft.extraBody, !text.isEmpty else { return true }
        return (try? JSONSerialization.jsonObject(with: Data(text.utf8))) != nil
    }

    // MARK: - Provider helpers

    private func providerLabel(for id: String) -> String {
        ProviderRegistry.shared.displayName(for: id)
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
                Text("\(text.count.formatted()) characters")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(14)
                .background(Color(nsColor: .textBackgroundColor))
                .disabled(isReadOnly)
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}
