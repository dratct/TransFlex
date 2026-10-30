import XCTest
import KeyboardShortcuts
@testable import TransFlex

final class HotkeyActionTests: XCTestCase {
    func testOpenPopupNameStable() {
        XCTAssertEqual(KeyboardShortcuts.Name.openPopup.rawValue, "openPopup")
    }
    
    func testDefaultPopupShortcutDiffersBetweenDebugAndRelease() {
        // Debug and Release can run side by side; distinct defaults keep them from sharing a hotkey.
        XCTAssertEqual(
            KeyboardShortcuts.Name.defaultPopupShortcut(debugBuild: true),
            KeyboardShortcuts.Shortcut(.q, modifiers: [.option])
        )
        XCTAssertEqual(
            KeyboardShortcuts.Name.defaultPopupShortcut(debugBuild: false),
            KeyboardShortcuts.Shortcut(.t, modifiers: [.option])
        )
    }

    func testPresetNameEmbedsUUID() {
        let id = UUID()
        let name = KeyboardShortcuts.Name.preset(id)
        XCTAssertTrue(name.rawValue.contains(id.uuidString))
    }

    func testHotkeyActionEquality() {
        let id = UUID()
        XCTAssertEqual(HotkeyAction.openPopup, HotkeyAction.openPopup)
        XCTAssertEqual(HotkeyAction.preset(id), HotkeyAction.preset(id))
        XCTAssertNotEqual(HotkeyAction.preset(id), HotkeyAction.preset(UUID()))
    }
}

final class PresetQuickHotkeyNameTests: XCTestCase {
    func testQuickNamesAreDistinctPerPresetAndEmbedUUID() {
        let id = UUID()
        let names = KeyboardShortcuts.Name.allPresetNames(id).map(\.rawValue)
        XCTAssertEqual(Set(names).count, 3)
        XCTAssertTrue(names.allSatisfy { $0.contains(id.uuidString) })
        XCTAssertNotEqual(
            KeyboardShortcuts.Name.presetQuickPopup(id),
            KeyboardShortcuts.Name.presetQuickPopup(UUID())
        )
    }
}
