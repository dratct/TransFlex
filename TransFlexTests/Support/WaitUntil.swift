import XCTest

/// Waits for work the test started on another task to reach `condition`,
/// checking every 5 ms. Returns as soon as it holds; fails the test with
/// `message` when `timeout` runs out.
@MainActor
func waitUntil(
    timeout: TimeInterval = 5,
    _ condition: () -> Bool,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertTrue(condition(), message, file: file, line: line)
}
