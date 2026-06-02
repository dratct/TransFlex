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
    @State private var debounceTask: Task<Void, Never>?

    init(store: ProvidersStore, providerID: String, displayName: String, icon: String) {
        self.store = store
        self.providerID = providerID
        self.displayName = displayName
        self.icon = icon
        let key = "provider.\(providerID).apiKey"
        self._hasStoredKey = State(initialValue: KeychainStore().exists(key))
    }

    var body: some View {
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
                .onChange(of: apiKey) { newValue in
                    scheduleSave(newValue)
                }

            if hasStoredKey {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
            } else {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 4)

        if let saveError {
            Text(saveError)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .padding(.leading, 114)
        }
    }

    private func scheduleSave(_ newValue: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                try store.setCloudAPIKey(newValue, for: providerID)
                hasStoredKey = !newValue.isEmpty || KeychainStore().exists("provider.\(providerID).apiKey")
                saveError = nil
            } catch {
                hasStoredKey = KeychainStore().exists("provider.\(providerID).apiKey")
                saveError = error.localizedDescription
            }
        }
    }
}
