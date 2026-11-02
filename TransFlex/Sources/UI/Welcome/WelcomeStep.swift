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
}
