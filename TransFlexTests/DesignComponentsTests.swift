import XCTest
@testable import TransFlex

final class DesignComponentsTests: XCTestCase {
    func test_seamFill_growsWithTheTranslation() {
        let fills = [10, 30, 60, 100].map { ColumnSeam.fill(translatedCount: $0, sourceCount: 100) }
        XCTAssertEqual(fills, fills.sorted())
        XCTAssertEqual(Set(fills).count, fills.count)
    }

    func test_seamFill_keepsMovingWhenTheTranslationOutgrowsItsSource() {
        // Vietnamese often runs longer than its English source; the seam must
        // not park at a cap for the rest of the stream.
        let atSource = ColumnSeam.fill(translatedCount: 100, sourceCount: 100)
        let longer = ColumnSeam.fill(translatedCount: 150, sourceCount: 100)
        XCTAssertGreaterThan(longer - atSource, 0.05)
    }

    func test_seamFill_neverReadsAsFinishedWhileStreaming() {
        XCTAssertLessThan(ColumnSeam.fill(translatedCount: 300, sourceCount: 100), ColumnSeam.maxStreamingFill)
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
