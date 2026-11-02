import SwiftUI

/// One cloud provider: its logo, whether a key is saved, and the way to add,
/// change or remove it. The key itself is typed only in `ProviderKeySheet`.
@MainActor
struct CloudProviderRow: View {
    @ObservedObject var store: ProvidersStore
    let providerID: String
    let displayName: String
    let caption: String
    @State private var hasStoredKey: Bool
    @State private var isEditing = false

    init(store: ProvidersStore, providerID: String, displayName: String, caption: String) {
        self.store = store
        self.providerID = providerID
        self.displayName = displayName
        self.caption = caption
        self._hasStoredKey = State(initialValue: KeychainStore().exists("provider.\(providerID).apiKey"))
    }

    var body: some View {
        LabeledContent {
            HStack(spacing: Spacing.m) {
                Text(hasStoredKey ? "Key saved" : "Not set")
                    .foregroundStyle(hasStoredKey ? .secondary : .tertiary)
                Button(hasStoredKey ? "Edit…" : "Add Key…") { isEditing = true }
            }
        } label: {
            HStack(spacing: Spacing.m) {
                ProviderLogo(providerID: providerID, name: displayName)
                SettingsLabel(displayName, caption: caption)
            }
        }
        // The Settings window outlives this row; a key saved from Welcome or
        // the popup's first-run sheet must show up when Settings returns.
        .onAppear(perform: refreshStoredKey)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refreshStoredKey()
        }
        .sheet(isPresented: $isEditing, onDismiss: refreshStoredKey) {
            ProviderKeySheet(
                providerName: displayName,
                hasStoredKey: hasStoredKey,
                save: { try store.setCloudAPIKey($0, for: providerID) }
            )
        }
    }

    private func refreshStoredKey() {
        hasStoredKey = KeychainStore().exists("provider.\(providerID).apiKey")
    }
}

/// Add, replace or remove one provider key. Saving an empty key removes it.
@MainActor
struct ProviderKeySheet: View {
    let providerName: String
    let hasStoredKey: Bool
    let save: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(hasStoredKey ? "Replace the \(providerName) key" : "Add a \(providerName) key")
                    .font(.title3.weight(.semibold))
                Text("It is kept in your Mac’s Keychain and sent only to \(providerName).")
                    .foregroundStyle(.secondary)
            }

            SecureField("API key", text: $key, prompt: Text(hasStoredKey ? "Paste the new key" : "Paste your key"))
                .textFieldStyle(.roundedBorder)
                .onSubmit(commit)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: Spacing.m) {
                if hasStoredKey {
                    Button("Remove Key", role: .destructive) { apply("") }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save Key", action: commit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
            .controlSize(.large)
        }
        .padding(Spacing.xl)
        .frame(width: 440)
    }

    private var trimmed: String { key.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        apply(trimmed)
    }

    private func apply(_ value: String) {
        do {
            try save(value)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
