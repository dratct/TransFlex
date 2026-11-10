import Foundation
import OSLog

/// Validates and persists a provider API key into the macOS Keychain at the
/// canonical `provider.{id}.apiKey` slot. Centralizes the save logic shared
/// between the welcome wizard and the popup-level fallback wizard so the
/// keychain schema cannot drift between callers.
@MainActor
struct ProviderKeySaver {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "ProviderKeySaver")

    enum SaveError: LocalizedError {
        case emptyKey
        case keychainFailure(Error)

        var errorDescription: String? {
            switch self {
            case .emptyKey:
                return "API key is empty."
            case .keychainFailure:
                return "Could not save API key. Check Keychain access and try again."
            }
        }
    }

    let keychain: KeychainStore
    /// The app's one store; `nil` moves no presets.
    let presetStore: PresetStore?

    init(keychain: KeychainStore = KeychainStore(), presetStore: PresetStore?) {
        self.keychain = keychain
        self.presetStore = presetStore
    }

    /// The first key for any keyed provider also moves the unedited
    /// built-ins onto that provider (CONTEXT.md › Rules).
    func save(_ rawKey: String, for providerID: String) throws {
        let trimmed = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SaveError.emptyKey }
        let isFirstKey = !DefaultPresets.keyedProviders.contains { keychain.exists("provider.\($0).apiKey") }
        do {
            try keychain.set(trimmed, forKey: "provider.\(providerID).apiKey")
        } catch {
            throw SaveError.keychainFailure(error)
        }
        guard isFirstKey else { return }
        do {
            try presetStore?.moveUneditedBuiltins(to: providerID)
        } catch {
            // The key is saved; the presets stay where they were and can be
            // changed by hand.
            Self.logger.error("moving built-in presets failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
