import Foundation

/// Which macOS keychain holds the app's secrets, fixed per build through Info.plist.
public enum KeychainBackend: Equatable {
    /// The file-based login keychain. Works for ad-hoc builds, but its per-item ACL records the
    /// app's code hash, so macOS asks for the login password again after every rebuild.
    case file
    /// The data protection keychain. Needs a team-signed build whose provisioning profile
    /// authorises the `keychain-access-groups` entitlement; ad-hoc builds get `-34018`.
    case dataProtection
    /// A file keychain of its own at `path`, opened with its own password, never added to the
    /// user's search list. Items in it carry no code-hash partition, so a rebuilt app signed by
    /// the same certificate reads them without a prompt. Used by local Debug builds only.
    case fileAt(path: String, passwordFile: String? = nil)
}
