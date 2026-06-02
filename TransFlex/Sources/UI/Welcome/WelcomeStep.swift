import Foundation

enum WelcomeStep: Int, CaseIterable {
    case intro
    case hotkey
    case provider
    case finish

    var next: WelcomeStep? { Self(rawValue: rawValue + 1) }
    var previous: WelcomeStep? { Self(rawValue: rawValue - 1) }

    var primaryCTA: String {
        switch self {
        case .intro: return "Get Started"
        case .hotkey, .provider: return "Continue"
        case .finish: return "Open Translator"
        }
    }

    var subtitle: String {
        switch self {
        case .intro: return "Welcome"
        case .hotkey: return "Step 1 of 3 — Hotkey"
        case .provider: return "Step 2 of 3 — Provider"
        case .finish: return "All done"
        }
    }
}
