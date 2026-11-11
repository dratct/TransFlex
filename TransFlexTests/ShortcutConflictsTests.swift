import KeyboardShortcuts
import XCTest
@testable import TransFlex

/// A key combination belongs to one action; recording it for another is refused
/// with the name of the action that has it.
final class ShortcutConflictsTests: XCTestCase {
    private let preset = Preset(name: "Natural EN ↔ VI", providerID: "openai", modelID: "gpt-4o", systemPrompt: "Translate.")
    private let optionT = KeyboardShortcuts.Shortcut(.t, modifiers: [.option])
    private let optionR = KeyboardShortcuts.Shortcut(.r, modifiers: [.option])

    func testOwnerOfUsedCombination() {
        let bindings: [HotkeyAction: KeyboardShortcuts.Shortcut] = [
            .openPopup: optionT,
            .presetQuickReplace(preset.id): optionR,
        ]
        XCTAssertEqual(
            ShortcutConflicts.owner(of: optionR, excluding: .presetQuickPopup(preset.id), in: bindings),
            .presetQuickReplace(preset.id)
        )
    }

    func testNoOwnerWhenFree() {
        let bindings: [HotkeyAction: KeyboardShortcuts.Shortcut] = [.openPopup: optionT]
        XCTAssertNil(ShortcutConflicts.owner(of: optionR, excluding: .preset(preset.id), in: bindings))
    }

    func testExcludesSelf() {
        let bindings: [HotkeyAction: KeyboardShortcuts.Shortcut] = [.openPopup: optionT]
        XCTAssertNil(ShortcutConflicts.owner(of: optionT, excluding: .openPopup, in: bindings))
    }

    func testLabelForOpenPopup() {
        XCTAssertEqual(ShortcutConflicts.label(for: .openPopup, presets: [preset]), "Open shortcut")
    }

    func testLabelNamesThePresetAndItsShortcut() {
        XCTAssertEqual(
            ShortcutConflicts.label(for: .presetQuickReplace(preset.id), presets: [preset]),
            "Natural EN ↔ VI › Replace selection"
        )
        XCTAssertEqual(
            ShortcutConflicts.label(for: .preset(preset.id), presets: [preset]),
            "Natural EN ↔ VI › Choose this preset"
        )
    }

    func testRefusalNamesTheOwner() {
        let bindings: [HotkeyAction: KeyboardShortcuts.Shortcut] = [.openPopup: optionT]
        XCTAssertEqual(
            ShortcutConflicts.validate(optionT, for: .preset(preset.id), bindings: bindings, presets: [preset]),
            .disallow(reason: "Already used by Open shortcut.")
        )
        XCTAssertEqual(
            ShortcutConflicts.validate(optionR, for: .preset(preset.id), bindings: bindings, presets: [preset]),
            .allow
        )
    }
}
