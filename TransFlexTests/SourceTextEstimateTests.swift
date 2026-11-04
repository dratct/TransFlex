import XCTest
@testable import TransFlex

final class SourceTextEstimateTests: XCTestCase {
    private let sentence = "The history of computing spans centuries, from mechanical calculators to modern processors."

    func testEmptyOrBlankSourceTakesNoHeight() {
        XCTAssertEqual(SourceTextEstimate.height(of: "", width: 400), 0)
        XCTAssertEqual(SourceTextEstimate.height(of: "  \n ", width: 400), 0)
    }

    func testOneLineIsTheLineHeightPlusTenPercent() {
        // SF 17 sets a 20pt line; line spacing only goes between lines.
        XCTAssertEqual(SourceTextEstimate.height(of: "Hello", width: 400), 22)
    }

    func testMoreTextIsTaller() {
        let one = SourceTextEstimate.height(of: "Hello", width: 400)
        let two = SourceTextEstimate.height(of: "Hello\nWorld", width: 400)
        let paragraphs = SourceTextEstimate.height(
            of: Array(repeating: sentence, count: 10).joined(separator: "\n\n"), width: 400
        )
        XCTAssertLessThan(one, two)
        XCTAssertLessThan(two, paragraphs)
    }

    func testNarrowerColumnIsTaller() {
        let text = Array(repeating: sentence, count: 4).joined(separator: " ")
        XCTAssertGreaterThan(
            SourceTextEstimate.height(of: text, width: 300),
            SourceTextEstimate.height(of: text, width: 600)
        )
    }
}
