import Foundation

enum WelcomeStep: Int, CaseIterable {
    case intro
    case provider
    case shortcut
    case done

    var next: WelcomeStep? { Self(rawValue: rawValue + 1) }
    var previous: WelcomeStep? { Self(rawValue: rawValue - 1) }

    var stepLabel: String { "Step \(rawValue + 1) of \(Self.allCases.count)" }

    var primaryTitle: String {
        switch self {
        case .intro: return "Get Started"
        case .provider, .shortcut: return "Continue"
        case .done: return "Open Translator"
        }
    }

    var showsBack: Bool { self != .intro }

    /// Only the key can be left for later; every other step has nothing to skip.
    var showsSkip: Bool { self == .provider }

    /// The last step's title and the line under it; after Skip for now it says where the
    /// key goes instead of claiming everything is ready.
    static func doneHeading(keySkipped: Bool) -> (title: String, lead: String) {
        keySkipped
            ? ("Almost set", "Add a key any time in Settings › Providers.")
            : ("You're all set", "\(AppIdentity.current.displayName) lives in the menu bar.")
    }
}
