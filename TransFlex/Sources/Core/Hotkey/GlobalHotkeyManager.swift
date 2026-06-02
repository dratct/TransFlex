import Foundation
import KeyboardShortcuts
import OSLog

/// Wraps `KeyboardShortcuts` to expose a typed `HotkeyAction` API.
///
/// Persistence + user customization come for free from the underlying lib
/// (UserDefaults). Carbon `RegisterEventHotKey` is intentionally avoided to
/// keep the app notarize-friendly.
public final class GlobalHotkeyManager {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "Hotkey")

    private var handlers: [HotkeyAction: () -> Void] = [:]

    public init() {}

    /// Registers a handler for `action`. Replaces any existing handler.
    ///
    /// `KeyboardShortcuts.onKeyDown` appends listeners — calling `register`
    /// twice without disabling first would leak the previous closure and fire
    /// it on every keypress. Disable before re-register to keep rebind clean.
    public func register(_ action: HotkeyAction, handler: @escaping () -> Void) {
        let name = name(for: action)
        if handlers[action] != nil {
            KeyboardShortcuts.disable(name)
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
        KeyboardShortcuts.disable(name)
    }

    private func name(for action: HotkeyAction) -> KeyboardShortcuts.Name {
        switch action {
        case .openPopup:
            return .openPopup
        case .preset(let id):
            return .preset(id)
        }
    }
}
