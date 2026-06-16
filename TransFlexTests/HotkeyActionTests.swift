import XCTest
import KeyboardShortcuts
@testable import TransFlex

final class HotkeyActionTests: XCTestCase {
    func testOpenPopupNameStable() {
        XCTAssertEqual(KeyboardShortcuts.Name.openPopup.rawValue, "openPopup")
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
