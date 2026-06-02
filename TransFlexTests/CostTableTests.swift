import XCTest
@testable import TransFlex

final class CostTableTests: XCTestCase {
    func testKnownModelEstimate() throws {
        let cost = try XCTUnwrap(CostTable.estimate(model: "gpt-4o-mini", input: 1000, output: 500, hadImage: false))
        XCTAssertEqual(cost, 0.00015 + 0.0003, accuracy: 1e-9)
    }

    func testUnknownModelReturnsNil() {
        XCTAssertNil(CostTable.estimate(model: "ollama-llama3", input: 100, output: 100, hadImage: false))
    }

    func testImageSurchargeApplied() throws {
        let withImage = try XCTUnwrap(CostTable.estimate(model: "gpt-4o-mini", input: 0, output: 0, hadImage: true))
        XCTAssertEqual(withImage, 0.0007, accuracy: 1e-9)
    }
}
