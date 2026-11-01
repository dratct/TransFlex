import XCTest
@testable import TransFlex

final class ErrorMessageHelperTests: XCTestCase {
    func testRejectedRequestShowsProviderReason() {
        let body = """
        {"error": {"message": "Unsupported value: 'temperature' does not support 0.3 with this model. Only the default (1) value is supported.", "type": "invalid_request_error", "param": "temperature", "code": "unsupported_value"}}
        """
        let message = ErrorMessageHelper.friendly(LLMError.server(status: 400, body: body))

        XCTAssertTrue(message.contains("Only the default (1) value is supported"), message)
    }

    func testRejectedRequestWithoutJSONFallsBackToStatus() {
        let message = ErrorMessageHelper.friendly(LLMError.server(status: 404, body: "<html>not found</html>"))

        XCTAssertTrue(message.contains("404"), message)
    }

    func testServerFailureKeepsRetryHint() {
        XCTAssertEqual(
            ErrorMessageHelper.friendly(LLMError.server(status: 503, body: "{}")),
            "Provider issue. Try again."
        )
    }
}
