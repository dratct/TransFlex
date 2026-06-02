import Foundation

/// Typed errors surfaced by `KeychainStore`. Wraps OSStatus for diagnostics.
public enum KeychainError: Error, Equatable {
    case unhandled(OSStatus)
    case invalidData
}

extension KeychainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
            return "Keychain error \(status): \(message)"
        case .invalidData:
            return "Keychain item could not be decoded as UTF-8 string."
        }
    }
}
