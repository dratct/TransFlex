import AppKit
import XCTest
@testable import TransFlex

/// Keycaps read in the order macOS menus draw modifiers: ⌃ ⌥ ⇧ ⌘, then the key.
final class ShortcutKeysTests: XCTestCase {
    func testModifiersComeInMenuOrderThenTheKey() {
        XCTAssertEqual(ShortcutKeys.symbols(modifiers: [.command, .shift, .option, .control], key: "V"),
                       ["⌃", "⌥", "⇧", "⌘", "V"])
    }

    func testOptionV() {
        XCTAssertEqual(ShortcutKeys.symbols(modifiers: [.option], key: "V"), ["⌥", "V"])
    }

    func testUnrelatedFlagsAreIgnored() {
        XCTAssertEqual(ShortcutKeys.symbols(modifiers: [.capsLock, .command], key: "T"), ["⌘", "T"])
    }
}
