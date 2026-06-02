import Foundation

/// User-configurable rule for clearing popup state when it is re-opened.
///
/// Encoded in `UserDefaults` as a single Int via `rawMinutes`:
///   - `-1` → `.never` (preserve previous session indefinitely)
///   -  `0` → `.always` (every reopen starts fresh)
///   - `>0` → `.afterMinutes(n)` (clear if hidden ≥ n minutes)
enum PopupResetPolicy: Equatable {
    case always
    case afterMinutes(Int)
    case never

    static let storageKey = "popup.reset.policy.minutes"
    static let `default`: PopupResetPolicy = .afterMinutes(2)

    /// Discrete options surfaced in the Settings picker.
    static let presetOptions: [PopupResetPolicy] = [
        .always,
        .afterMinutes(1),
        .afterMinutes(2),
        .afterMinutes(3),
        .afterMinutes(4),
        .afterMinutes(5),
        .never,
    ]

    var rawMinutes: Int {
        switch self {
        case .always: return 0
        case .afterMinutes(let n): return max(1, n)
        case .never: return -1
        }
    }

    init(rawMinutes: Int) {
        switch rawMinutes {
        case ..<0: self = .never
        case 0: self = .always
        default: self = .afterMinutes(rawMinutes)
        }
    }

    var displayName: String {
        switch self {
        case .always: return "Always clear"
        case .afterMinutes(let n): return "After \(n) minute\(n == 1 ? "" : "s")"
        case .never: return "Never"
        }
    }

    /// Decide whether to wipe the popup based on how long it has been hidden.
    /// `lastHiddenAt == nil` means first show after launch — always reset so
    /// the user does not inherit ghost state from a hypothetical prior run.
    func shouldReset(lastHiddenAt: Date?, now: Date = Date()) -> Bool {
        guard let lastHiddenAt else { return self != .never }
        switch self {
        case .always: return true
        case .never: return false
        case .afterMinutes(let n):
            return now.timeIntervalSince(lastHiddenAt) >= TimeInterval(n) * 60
        }
    }
}

@MainActor
enum PopupResetPolicyStore {
    static func load() -> PopupResetPolicy {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: PopupResetPolicy.storageKey) != nil else {
            return PopupResetPolicy.default
        }
        return PopupResetPolicy(rawMinutes: defaults.integer(forKey: PopupResetPolicy.storageKey))
    }

    static func save(_ policy: PopupResetPolicy) {
        UserDefaults.standard.set(policy.rawMinutes, forKey: PopupResetPolicy.storageKey)
    }
}
