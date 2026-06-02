import Foundation

/// Centralized request-header chokepoint. Applies user-supplied `extra`
/// headers first, then auth headers — Keychain-resolved auth ALWAYS wins.
/// `extra` is filtered against an auth deny-list (case-insensitive) so a
/// misconfigured (or hostile-imported) settings entry cannot override
/// `Authorization` / `x-api-key` / `x-goog-api-key` / `anthropic-version`.
/// The contract lives in one place so future adapters cannot regress it.
public enum HeaderApplicator {
    /// Header names callers must never override via `extraHeaders`.
    static let denyList: Set<String> = [
        "authorization",
        "x-api-key",
        "x-goog-api-key",
        "anthropic-version",
    ]

    /// Apply headers to `request`. Multiple `extra` groups are applied in
    /// order (instance-level then config-level for compat providers); auth
    /// pairs are applied last so they cannot be overwritten.
    public static func apply(
        to request: inout URLRequest,
        auth: [(String, String)],
        extraGroups: [[String: String]]
    ) {
        for group in extraGroups {
            for (key, value) in group where !denyList.contains(key.lowercased()) {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        for (key, value) in auth {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}
