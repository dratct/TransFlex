import XCTest
@testable import TransFlex

/// DESIGN.md › Popup header: which buttons it shows, pinned or not.
final class PopupHeaderTests: XCTestCase {
    func testUnpinnedHeaderHasNoClose() {
        let items = PopupHeader.items(isPinned: false)

        XCTAssertEqual(items.map(\.action), [.history, .settings, .pin])
        let pin = items[2]
        XCTAssertEqual(pin.title, "Pin")
        XCTAssertEqual(pin.symbol, "pin")
        XCTAssertEqual(pin.keys, ["⌘", "P"])
    }

    func testPinnedHeaderAddsClose() {
        let items = PopupHeader.items(isPinned: true)

        XCTAssertEqual(items.map(\.action), [.history, .settings, .pin, .close])
        let pin = items[2]
        XCTAssertEqual(pin.title, "Unpin", "VoiceOver names what the button does now")
        XCTAssertEqual(pin.symbol, "pin.fill")
        XCTAssertEqual(pin.keys, ["⌘", "P"])
        let close = items[3]
        XCTAssertEqual(close.title, "Close")
        // Esc sometimes stops a stream or goes back to the text instead.
        XCTAssertEqual(close.keys, [])
    }

    func testHistoryAndSettingsKeepTheirKeys() {
        let items = PopupHeader.items(isPinned: false)

        XCTAssertEqual(items[0].keys, ["⌘", "Y"])
        XCTAssertEqual(items[1].keys, ["⌘", ","])
    }
}
