import Foundation

/// Typed errors surfaced by `KeychainStore`. Wraps OSStatus for diagnostics.
public enum KeychainError: Error, Equatable {
    case unhandled(OSStatus)
    case invalidData
    /// The build lacks its keychain access group entitlement (`errSecMissingEntitlement`).
    case missingEntitlement

    init(status: OSStatus) {
        self = status == errSecMissingEntitlement ? .missingEntitlement : .unhandled(status)
    }
}

extension KeychainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
            return "Keychain error \(status): \(message)"
        case .invalidData:
            return "Keychain item could not be decoded as UTF-8 string."
        case .missingEntitlement:
            return "This build is not entitled to its keychain access group. Team-signed builds need a provisioning profile that allows keychain-access-groups."
        }
    }
}
