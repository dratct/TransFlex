import SwiftUI

@MainActor
struct CloudProviderRow: View {
    @ObservedObject var store: ProvidersStore
    let providerID: String
    let displayName: String
    let icon: String
    @State private var apiKey = ""
    @State private var hasStoredKey: Bool
    @State private var saveError: String?

    init(store: ProvidersStore, providerID: String, displayName: String, icon: String) {
        self.store = store
        self.providerID = providerID
        self.displayName = displayName
        self.icon = icon
        let key = "provider.\(providerID).apiKey"
        self._hasStoredKey = State(initialValue: KeychainStore().exists(key))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                // Asset-catalog brand icon (template-rendered SVG); tints with
                // `.foregroundStyle`. Resizable so the SVG scales to a fixed box.
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)

                Text(displayName)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 80, alignment: .leading)

                SecureField(hasStoredKey ? "Configured — enter new key to replace" : "API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit {
                        saveKey()
                    }

                HStack(spacing: 8) {
                    if !apiKey.isEmpty {
                        Button(action: { apiKey = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Cancel")

                        Button("Save") {
                            saveKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        if hasStoredKey {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 14))

                                Button(action: deleteKey) {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 13))
                                }
                                .buttonStyle(.plain)
                                .help("Clear API Key")
                            }
                        }
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, 4)

            if let saveError {
                Text(saveError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.leading, 114)
            }
        }
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try store.setCloudAPIKey(trimmed, for: providerID)
            hasStoredKey = true
            apiKey = ""
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func deleteKey() {
        do {
            try store.setCloudAPIKey("", for: providerID)
            hasStoredKey = false
            apiKey = ""
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}
