import XCTest
@testable import TransFlex

/// C-8: a Translate Selection failure shows a banner instead of the popup,
/// except for cards that need the popup (permission, rejected key, setup).
final class SelectionFailureTests: XCTestCase {
    private func banner(_ error: Error) -> SelectionBanner? {
        if case .banner(let banner) = SelectionFailure.route(for: error, providerName: "Gemini") { return banner }
        return nil
    }

    func testNoSelectionShowsNothingSelectedBanner() {
        XCTAssertEqual(
            banner(SelectionCapture.Failure.noSelection),
            SelectionBanner(title: "Nothing selected", message: "Select some text first.", canRetry: false)
        )
    }

    func testOfflineShowsOfflineBanner() {
        XCTAssertEqual(
            banner(LLMError.offline),
            SelectionBanner(title: "You're offline", message: "Check your connection and try again.", canRetry: true)
        )
    }

    func testOtherNetworkErrorNamesProvider() {
        XCTAssertEqual(
            banner(LLMError.network("timed out")),
            SelectionBanner(title: "Couldn't reach Gemini", message: "Try again in a moment.", canRetry: true)
        )
    }

    func testServerErrorSaysProviderHasTrouble() {
        let trouble = SelectionBanner(title: "Gemini is having trouble", message: "Try again in a moment.", canRetry: true)
        for error: LLMError in [
            .server(status: 503, body: ""), .rateLimit(retryAfterSeconds: nil),
            .decode("x"), .invalidResponse("x"),
        ] {
            XCTAssertEqual(banner(error), trouble, "\(error)")
        }
    }

    func testRefusedRequestGivesTheProviderReason() {
        let body = #"{"error":{"message":"Model not found"}}"#
        XCTAssertEqual(
            banner(LLMError.server(status: 404, body: body)),
            SelectionBanner(title: "Gemini refused the request", message: "Model not found", canRetry: true)
        )
        XCTAssertEqual(
            banner(LLMError.providerMessage("Prompt blocked")),
            SelectionBanner(title: "Gemini refused the request", message: "Prompt blocked", canRetry: true)
        )
    }

    func testPermissionStillOpensPopupCard() {
        XCTAssertEqual(SelectionFailure.route(for: SelectionCapture.Failure.accessibilityNotGranted, providerName: "Gemini"), .popupCard)
    }

    func testRejectedKeyStillOpensPopupCard() {
        XCTAssertEqual(SelectionFailure.route(for: LLMError.auth, providerName: "Gemini"), .popupCard)
    }

    func testTranslationErrorStillOpensPopupCard() {
        let error = TranslationError.modelMissing(providerID: "gemini", modelID: "x")
        XCTAssertEqual(SelectionFailure.route(for: error, providerName: "Gemini"), .popupCard)
    }

    func testCancelledShowsNothing() {
        XCTAssertEqual(SelectionFailure.route(for: LLMError.cancelled, providerName: "Gemini"), .ignore)
        XCTAssertEqual(SelectionFailure.route(for: CancellationError(), providerName: "Gemini"), .ignore)
    }

    func testUnknownErrorSaysCouldntTranslate() {
        struct Odd: LocalizedError { var errorDescription: String? { "Something odd." } }
        XCTAssertEqual(
            banner(Odd()),
            SelectionBanner(title: "Couldn't translate", message: "Something odd.", canRetry: true)
        )
    }
}
