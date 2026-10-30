import Foundation
import Security

/// Generic-password Keychain wrapper. Single service id; key per item.
///
/// The backend comes from the build (see `KeychainBackend`). Data protection items are written
/// with `kSecAttrAccessibleAfterFirstUnlock` so background launches can read them; the
/// file-based keychain ignores that attribute.
public final class KeychainStore {
    public static var defaultService: String { AppIdentity.current.keychainService }
    public static var defaultBackend: KeychainBackend { AppIdentity.current.keychainBackend }

    private let service: String
    private let backend: KeychainBackend

    public init(
        service: String = KeychainStore.defaultService,
        backend: KeychainBackend = KeychainStore.defaultBackend
    ) {
        self.service = service
        self.backend = backend
    }

    // MARK: - String API

    /// Stores `value` for `key`. `nil` deletes the entry.
    public func set(_ value: String?, forKey key: String) throws {
        guard let value else {
            try delete(key)
            return
        }
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try setData(data, forKey: key)
    }

    /// Returns string value for `key`, or `nil` if not present.
    public func get(_ key: String) throws -> String? {
        guard let data = try getData(key) else { return nil }
        guard let str = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return str
    }

    // MARK: - Data API

    public func setData(_ data: Data, forKey key: String) throws {
        // Add-first then update-on-duplicate avoids the race where two writers
        // see "not found", both fall back to add, and the second hits
        // errSecDuplicateItem. Accessibility is set on add only — passing it to
        // SecItemUpdate is not portable across macOS versions.
        let addStatus = SecItemAdd(addQuery(account: key, data: data) as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateAttrs: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(
                baseQuery(account: key) as CFDictionary,
                updateAttrs as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainError(status: updateStatus)
            }
        default:
            throw KeychainError(status: addStatus)
        }
    }

    /// Returns `true` if an item exists under `key` without decrypting the
    /// secret payload. macOS only surfaces an authentication prompt when a
    /// caller asks for `kSecValueData`; restricting the query to attributes
    /// lets first-run gating probe the keychain silently.
    public func exists(_ key: String) -> Bool {
        var query = baseQuery(account: key)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess
    }

    public func getData(_ key: String) throws -> Data? {
        var query = baseQuery(account: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    /// Deletes the entry. Missing key is not an error.
    public func delete(_ key: String) throws {
        let status = SecItemDelete(baseQuery(account: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    /// Test helper: removes every item under `service`.
    public func deleteAll() throws {
        let query = serviceQuery()
        // The file-based keychain deletes one match per call, so repeat until none is left.
        var status = SecItemDelete(query as CFDictionary)
        while status == errSecSuccess {
            status = SecItemDelete(query as CFDictionary)
        }
        guard status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    // MARK: - Queries

    func addQuery(account: String, data: Data) -> [String: Any] {
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        if backend == .dataProtection {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        }
        return query
    }

    private func baseQuery(account: String) -> [String: Any] {
        var query = serviceQuery()
        query[kSecAttrAccount as String] = account
        return query
    }

    private func serviceQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if backend == .dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

}
