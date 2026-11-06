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

    func testEstimateKnowsDefaultPresetModels() throws {
        for preset in DefaultPresets.builtins {
            XCTAssertNotNil(
                CostTable.estimate(model: preset.modelID, input: 1000, output: 1000, hadImage: false),
                "no price for \(preset.modelID)"
            )
        }
        let luna = try XCTUnwrap(CostTable.estimate(model: "gpt-6-luna", input: 1000, output: 1000, hadImage: false))
        XCTAssertEqual(luna, 0.0001 + 0.0005, accuracy: 1e-9)
    }

    func testImageSurchargeApplied() throws {
        let withImage = try XCTUnwrap(CostTable.estimate(model: "gpt-4o-mini", input: 0, output: 0, hadImage: true))
        XCTAssertEqual(withImage, 0.0007, accuracy: 1e-9)
    }
}
