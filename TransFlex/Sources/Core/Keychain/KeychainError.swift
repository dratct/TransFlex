import Foundation

/// Typed errors surfaced by `KeychainStore`. Wraps OSStatus for diagnostics.
public enum KeychainError: Error, Equatable {
    case unhandled(OSStatus)
    case invalidData
    /// The build lacks its keychain access group entitlement (`errSecMissingEntitlement`).
    case missingEntitlement
    /// The build's own keychain is locked and the build names no password file to unlock it.
    case lockedWithoutPasswordFile
    /// The password file named by the build cannot be read.
    case passwordFileUnreadable(String)

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
        case .lockedWithoutPasswordFile:
            return "The build's keychain is locked and TRANSFLEX_KEYCHAIN_PASSWORD_FILE is not set."
        case .passwordFileUnreadable(let path):
            return "Cannot read the keychain password file at \(path)."
        }
    }
}
