import SwiftUI

@MainActor
struct OpenAICompatEditor: View {
    @ObservedObject var store: ProvidersStore
    @Environment(\.dismiss) private var dismiss

    let editing: OpenAICompatInstance?

    @State private var displayName = ""
    @State private var baseURLString = ""
    @State private var apiKey = ""
    @State private var didEditAPIKey = false
    @State private var defaultModel = ""
    @State private var extraHeaders: [HeaderEntry] = []
    @State private var errorMessage: String?
    @State private var fetchedModels: [Model] = []
    @State private var isFetching = false

    @State private var confirmsRemoval = false

    /// Add Endpoint and Load Models stay off until these hold.
    static func isValid(name: String, baseURL: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validURL(baseURL) != nil
    }

    static func validURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.host != nil,
              (try? ProviderRegistry.validateBaseURL(url)) != nil
        else { return nil }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.m) {
                ProviderLogo(providerID: "openai-compatible", name: displayName.isEmpty ? "API" : displayName)
                VStack(alignment: .leading, spacing: 2) {
                    Text(editing == nil ? "Add an OpenAI-compatible endpoint" : "Edit endpoint")
                        .font(.title3.weight(.semibold))
                    Text("Ollama, LM Studio, OpenRouter, or any /v1/chat/completions server.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding([.horizontal, .top], Spacing.xl)

            Form {
                Section {
                    TextField("Name", text: $displayName, prompt: Text("Local Ollama"))
                    TextField("Base URL", text: $baseURLString, prompt: Text(verbatim: "http://localhost:11434"))
                    SecureField(text: $apiKey, prompt: Text(apiKeyPlaceholder)) {
                        SettingsLabel("API key", caption: "Optional")
                    }
                    .onChange(of: apiKey) { _ in didEditAPIKey = true }
                    defaultModelRow
                }
                extraHeadersSection
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, Spacing.xl)
            }

            HStack(spacing: Spacing.m) {
                Button(isFetching ? "Loading…" : "Load Models", action: fetchModels)
                    .disabled(isFetching || Self.validURL(baseURLString) == nil)
                if editing != nil {
                    Button("Remove Endpoint", role: .destructive) { confirmsRemoval = true }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(editing == nil ? "Add Endpoint" : "Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!Self.isValid(name: displayName, baseURL: baseURLString))
            }
            .controlSize(.large)
            .padding([.horizontal, .bottom], Spacing.xl)
        }
        .frame(width: 520)
        .onAppear { populateFields() }
        .confirmationDialog(
            "Remove “\(editing?.displayName ?? "")”?",
            isPresented: $confirmsRemoval
        ) {
            Button("Remove Endpoint", role: .destructive, action: remove)
        } message: {
            Text("Presets that use it will need another provider.")
        }
    }

    @ViewBuilder
    private var defaultModelRow: some View {
        if fetchedModels.isEmpty {
            TextField("Default model", text: $defaultModel, prompt: Text("Load models first, or type an ID"))
        } else {
            LabeledContent("Default model") {
                ModelPicker(modelID: $defaultModel, models: fetchedModels, providerName: displayName.isEmpty ? "endpoint" : displayName)
            }
        }
    }

    private var apiKeyPlaceholder: String {
        if let editing, store.hasCompatAPIKey(for: editing.instanceId) {
            return "Saved — type a new key to replace it"
        }
        return "Not needed for local servers"
    }

    private var extraHeadersSection: some View {
        Section {
            ForEach($extraHeaders) { $entry in
                HStack {
                    TextField("Header", text: $entry.key, prompt: Text("X-Header"))
                        .labelsHidden()
                        .frame(maxWidth: 140)
                    SecureField("Value", text: $entry.value, prompt: Text("Value"))
                        .labelsHidden()
                    Button {
                        extraHeaders.removeAll { $0.id == entry.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove header")
                }
            }
            Button("Add Header") {
                extraHeaders.append(HeaderEntry())
            }
        } header: {
            Text("Custom headers") + Text(" · optional").foregroundColor(.secondary)
        }
    }

    private func remove() {
        guard let editing else { return }
        do {
            try store.deleteCompatInstance(editing.instanceId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func populateFields() {
        guard let editing else { return }
        displayName = editing.displayName
        baseURLString = editing.baseURL.absoluteString
        defaultModel = editing.defaultModel ?? ""
        extraHeaders = editing.extraHeaderNames.map {
            HeaderEntry(
                key: $0,
                value: store.compatExtraHeaderValue(for: editing.instanceId, headerName: $0)
            )
        }
    }

    private func save() {
        guard let url = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Invalid URL."
            return
        }
        do {
            try ProviderRegistry.validateBaseURL(url)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty."
            return
        }

        let headers: [String: String]
        do {
            headers = try validatedHeaders()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let instanceId = editing?.instanceId ?? UUID().uuidString
        let instance = OpenAICompatInstance(
            instanceId: instanceId,
            displayName: trimmedName,
            baseURL: url,
            defaultModel: defaultModel.isEmpty ? nil : defaultModel,
            extraHeaders: headers
        )

        do {
            if editing != nil {
                try store.updateCompatInstance(instance, apiKey: didEditAPIKey ? apiKey : nil)
            } else {
                try store.addCompatInstance(instance, apiKey: apiKey)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchModels() {
        guard let url = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        do {
            try ProviderRegistry.validateBaseURL(url)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let headers: [String: String]
        do {
            headers = try validatedHeaders()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        isFetching = true
        fetchedModels = []

        let tempInstance = OpenAICompatInstance(
            instanceId: "_fetch",
            displayName: "_fetch",
            baseURL: url,
            extraHeaders: headers
        )
        let resolvedAPIKey: String
        if !apiKey.isEmpty {
            resolvedAPIKey = apiKey
        } else if let editing, store.hasCompatAPIKey(for: editing.instanceId) {
            resolvedAPIKey = store.compatAPIKey(for: editing.instanceId)
        } else {
            resolvedAPIKey = ""
        }
        let provider = OpenAICompatibleProvider(instance: tempInstance)

        Task {
            do {
                fetchedModels = try await provider.availableModels(apiKey: resolvedAPIKey)
            } catch {
                errorMessage = "Failed to fetch models: \(error.localizedDescription)"
            }
            isFetching = false
        }
    }

    private func validatedHeaders() throws -> [String: String] {
        var headers: [String: String] = [:]
        var seen: Set<String> = []
        for entry in extraHeaders {
            let name = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            guard name.range(of: #"[^A-Za-z0-9!#$%&'*+.^_`|~-]"#, options: .regularExpression) == nil else {
                throw ProviderError.invalidConfiguration("Header name '\(name)' contains invalid characters")
            }
            let normalized = name.lowercased()
            guard seen.insert(normalized).inserted else {
                throw ProviderError.invalidConfiguration("Duplicate header '\(name)'")
            }
            headers[name] = entry.value
        }
        return headers
    }
}

private struct HeaderEntry: Identifiable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}
