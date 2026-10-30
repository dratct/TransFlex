import Foundation

/// Which macOS keychain holds the app's secrets, fixed per build through Info.plist.
public enum KeychainBackend: Equatable {
    /// The file-based login keychain. Works for ad-hoc builds, but its per-item ACL records the
    /// app's code hash, so macOS asks for the login password again after every rebuild.
    case file
    /// The data protection keychain. Needs a team-signed build whose provisioning profile
    /// authorises the `keychain-access-groups` entitlement; ad-hoc builds get `-34018`.
    case dataProtection
}
