import Foundation

/// Codable hotkey representation. Persisted independent of
/// `KeyboardShortcuts.Shortcut` so library upgrades don't invalidate
/// stored bindings.
public struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    /// `NSEvent.ModifierFlags.rawValue`.
    public let modifiers: UInt
    /// Virtual key code (kVK_*).
    public let keyCode: UInt16

    public init(modifiers: UInt, keyCode: UInt16) {
        self.modifiers = modifiers
        self.keyCode = keyCode
    }
}
