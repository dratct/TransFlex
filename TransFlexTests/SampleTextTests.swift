import XCTest
@testable import TransFlex

/// `--screenshots` and `--clips` stop instead of drawing empty samples.
final class SampleTextTests: XCTestCase {
    func testTheBundledFileHasEverySample() {
        XCTAssertEqual(SampleText.missingKeys(in: SampleText.vietnamese), [])
    }

    func testAMissingOrEmptySampleIsNamed() {
        let partial: [String: String] = ["translation": "Hello", "historyShort": ""]
        XCTAssertEqual(SampleText.missingKeys(in: partial), ["historyShort", "historyTomorrow", "historyFixSource"])
        XCTAssertEqual(SampleText.missingKeys(in: [:]).count, 4)
    }
}
