import XCTest
@testable import TransFlex

final class DesignComponentsTests: XCTestCase {
    func test_seamFill_followsTranslationOverSourceLength() {
        XCTAssertEqual(ColumnSeam.fill(translatedCount: 30, sourceCount: 100), 0.3, accuracy: 0.0001)
    }

    func test_seamFill_staysBelowNinetyPercentWhileStreaming() {
        // A translation longer than its source must not read as finished.
        XCTAssertEqual(ColumnSeam.fill(translatedCount: 250, sourceCount: 100), 0.9, accuracy: 0.0001)
    }

    func test_seamFill_isEmptyWithoutSourceText() {
        // Image input has no source characters to measure against.
        XCTAssertEqual(ColumnSeam.fill(translatedCount: 40, sourceCount: 0), 0)
    }

    func test_keyHint_spokenLabelNamesEachKey() {
        XCTAssertEqual(KeyHint.spokenLabel(for: ["⌘", "↩"]), "Command Return")
        XCTAssertEqual(KeyHint.spokenLabel(for: ["⌘", "⇧", "V"]), "Command Shift V")
        XCTAssertEqual(KeyHint.spokenLabel(for: ["esc"]), "Escape")
    }
}
