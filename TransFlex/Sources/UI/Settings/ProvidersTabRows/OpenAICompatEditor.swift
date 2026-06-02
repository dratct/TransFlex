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

    var body: some View {
        VStack(spacing: 16) {
            Text(editing == nil ? "Add Endpoint" : "Edit Endpoint")
                .font(.system(size: 15, weight: .semibold))

            Form {
                TextField("Name", text: $displayName)
                TextField("Base URL", text: $baseURLString)
                    .font(.system(size: 12, design: .monospaced))
                SecureField(apiKeyPlaceholder, text: $apiKey)
                    .onChange(of: apiKey) { _ in didEditAPIKey = true }
                TextField("Default Model", text: $defaultModel)

                extraHeadersSection
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Fetch Models") {
                    fetchModels()
                }
                .disabled(isFetching || baseURLString.isEmpty)
                .font(.system(size: 12))

                if !fetchedModels.isEmpty {
                    Menu("Models (\(fetchedModels.count))") {
                        ForEach(fetchedModels, id: \.id) { model in
                            Button(model.name) {
                                defaultModel = model.id
                            }
                        }
                    }
                    .font(.system(size: 12))
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .font(.system(size: 12))
                Button("Save") { save() }
                    .font(.system(size: 12))
                    .disabled(displayName.isEmpty || baseURLString.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { populateFields() }
    }

    private var apiKeyPlaceholder: String {
        guard let editing, store.hasCompatAPIKey(for: editing.instanceId) else { return "API Key" }
        return "Configured — enter new key to replace"
    }

    private var extraHeadersSection: some View {
        Section("Custom Headers") {
            ForEach($extraHeaders) { $entry in
                HStack {
                    TextField("Key", text: $entry.key)
                        .frame(maxWidth: 100)
                    SecureField("Value", text: $entry.value)
                    Button {
                        extraHeaders.removeAll { $0.id == entry.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Add Header") {
                extraHeaders.append(HeaderEntry())
            }
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
