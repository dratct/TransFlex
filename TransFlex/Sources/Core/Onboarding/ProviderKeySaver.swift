import Foundation

/// Validates and persists a provider API key into the macOS Keychain at the
/// canonical `provider.{id}.apiKey` slot. Centralizes the save logic shared
/// between the welcome wizard and the popup-level fallback wizard so the
/// keychain schema cannot drift between callers.
@MainActor
struct ProviderKeySaver {
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

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    func save(_ rawKey: String, for providerID: String) throws {
        let trimmed = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SaveError.emptyKey }
        do {
            try keychain.set(trimmed, forKey: "provider.\(providerID).apiKey")
        } catch {
            throw SaveError.keychainFailure(error)
        }
    }
}
