import Foundation
import KeyboardShortcuts
import OSLog

/// Wraps `KeyboardShortcuts` to expose a typed `HotkeyAction` API.
///
/// Persistence + user customization come for free from the underlying lib
/// (UserDefaults). Carbon `RegisterEventHotKey` is intentionally avoided to
/// keep the app notarize-friendly.
@MainActor
public final class GlobalHotkeyManager {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "Hotkey")

    private var handlers: [HotkeyAction: () -> Void] = [:]

    public init() {}

    /// Registers a handler for `action`. Replaces any existing handler.
    ///
    /// `KeyboardShortcuts.onKeyDown` appends listeners — calling `register`
    /// twice without removing first would leak the previous closure and fire
    /// it on every keypress. `disable` is not a substitute: it keeps the
    /// closures and marks the name inactive until `enable` is called.
    public func register(_ action: HotkeyAction, handler: @escaping () -> Void) {
        let name = name(for: action)
        if handlers[action] != nil {
            KeyboardShortcuts.removeHandler(for: name)
        }
        handlers[action] = handler
        KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
            guard let self else { return }
            Self.logger.debug("Hotkey fired: \(String(describing: action), privacy: .public)")
            self.handlers[action]?()
        }
    }

    /// Removes any handler for `action`.
    public func unregister(_ action: HotkeyAction) {
        handlers.removeValue(forKey: action)
        let name = name(for: action)
        KeyboardShortcuts.removeHandler(for: name)
    }

    private func name(for action: HotkeyAction) -> KeyboardShortcuts.Name {
        switch action {
        case .openPopup:
            return .openPopup
        case .preset(let id):
            return .preset(id)
        case .presetQuickPopup(let id):
            return .presetQuickPopup(id)
        case .presetQuickReplace(let id):
            return .presetQuickReplace(id)
        }
    }
}
