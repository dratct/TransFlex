import AppKit

@MainActor
final class DockVisibilityController {
    enum Owner: Hashable {
        case settings
        case welcome
        case history
    }

    static let shared = DockVisibilityController { policy in
        NSApp.setActivationPolicy(policy)
    }

    private let setActivationPolicy: (NSApplication.ActivationPolicy) -> Void
    private var visibleOwners = Set<Owner>()

    init(setActivationPolicy: @escaping (NSApplication.ActivationPolicy) -> Void) {
        self.setActivationPolicy = setActivationPolicy
    }

    func showDockIcon(for owner: Owner) {
        let inserted = visibleOwners.insert(owner).inserted
        guard inserted, visibleOwners.count == 1 else { return }
        setActivationPolicy(.regular)
    }

    func hideDockIcon(for owner: Owner) {
        guard visibleOwners.remove(owner) != nil, visibleOwners.isEmpty else { return }
        setActivationPolicy(.accessory)
    }
}
