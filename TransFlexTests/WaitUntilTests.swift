import XCTest

/// A slow CI machine can take well over a second to reach a state the test
/// waits for; the wait must outlast that without slowing a fast run.
@MainActor
final class WaitUntilTests: XCTestCase {
    func testWaitsPastOneSecond() async throws {
        var ready = false
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 1_500_000_000)
            ready = true
        }
        try await waitUntil({ ready }, "ready after 1.5 s")
    }

    func testReturnsAsSoonAsTrue() async throws {
        let start = Date()
        try await waitUntil({ true })
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.1)
    }

    func testFailsWithMessageAfterTimeout() async throws {
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { $0.compactDescription.contains("never true") }
        XCTExpectFailure("the condition never holds", options: options)
        try await waitUntil(timeout: 0.05, { false }, "never true")
    }
}
