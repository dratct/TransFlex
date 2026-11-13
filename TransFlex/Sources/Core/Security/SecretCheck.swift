import Foundation

/// The Secret check (CONTEXT.md): whether a text may go to a provider as it
/// is. One value is shared by every path that sends source text.
public struct SecretCheck: Sendable {
    /// General setting "Check for secrets before sending".
    public static let settingKey = "checkForSecretsBeforeSending"

    public let isOn: @Sendable () -> Bool
    /// The provider runs on this Mac, so the text does not leave it.
    public let isOnThisMac: @Sendable (_ providerID: String) -> Bool

    public init(
        isOn: @escaping @Sendable () -> Bool,
        isOnThisMac: @escaping @Sendable (_ providerID: String) -> Bool
    ) {
        self.isOn = isOn
        self.isOnThisMac = isOnThisMac
    }

    /// What stops `text` from being sent to `providerID`, or `nil` when it
    /// may go.
    public func match(in text: String, providerID: String) -> SecretMatch? {
        guard isOn(), !isOnThisMac(providerID) else { return nil }
        return SecretScanner.firstMatch(in: text)
    }

    /// On unless the user turned it off: a key that was never written counts
    /// as on, for new installs and for users who update.
    public static func isOn(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: settingKey) == nil || defaults.bool(forKey: settingKey)
    }

    public static func live(defaults: UserDefaults) -> SecretCheck {
        // UserDefaults is thread-safe; it is not marked Sendable.
        nonisolated(unsafe) let defaults = defaults
        return SecretCheck(
            isOn: { isOn(in: defaults) },
            isOnThisMac: { ProviderRegistry.shared.isOnThisMac(providerID: $0) }
        )
    }
}
