import XCTest
@testable import TransFlex

final class OpenAIModelSupportTests: XCTestCase {
    func testGPT4FamilyAcceptsSampling() {
        XCTAssertTrue(OpenAIModelSupport.acceptsSampling("gpt-4o"))
        XCTAssertTrue(OpenAIModelSupport.acceptsSampling("gpt-4o-mini-2024-07-18"))
        XCTAssertTrue(OpenAIModelSupport.acceptsSampling("gpt-4.1-mini"))
        XCTAssertTrue(OpenAIModelSupport.acceptsSampling("gpt-3.5-turbo"))
        XCTAssertTrue(OpenAIModelSupport.acceptsSampling("chatgpt-4o-latest"))
    }

    func testReasoningAndUnknownModelsGetNoSampling() {
        XCTAssertFalse(OpenAIModelSupport.acceptsSampling("gpt-6-luna"))
        XCTAssertFalse(OpenAIModelSupport.acceptsSampling("gpt-5.2"))
        XCTAssertFalse(OpenAIModelSupport.acceptsSampling("o3-mini"))
        XCTAssertFalse(OpenAIModelSupport.acceptsSampling("o4-mini"))
        XCTAssertFalse(OpenAIModelSupport.acceptsSampling("some-new-model"))
    }
}
