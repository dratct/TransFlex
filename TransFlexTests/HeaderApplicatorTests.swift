import XCTest
@testable import TransFlex

final class HeaderApplicatorTests: XCTestCase {
    func testAuthAppliedAfterExtraSoExtraCannotOverride() {
        var req = URLRequest(url: URL(string: "https://example.com")!)
        HeaderApplicator.apply(
            to: &req,
            auth: [("Authorization", "Bearer real-key")],
            extraGroups: [["X-Trace": "abc"]]
        )
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer real-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Trace"), "abc")
    }

    func testExtraDenyListDropsAuthorizationOverride() {
        var req = URLRequest(url: URL(string: "https://example.com")!)
        HeaderApplicator.apply(
            to: &req,
            auth: [("Authorization", "Bearer real")],
            extraGroups: [["Authorization": "Bearer attacker"]]
        )
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer real")
    }

    func testExtraDenyListIsCaseInsensitive() {
        var req = URLRequest(url: URL(string: "https://example.com")!)
        HeaderApplicator.apply(
            to: &req,
            auth: [("x-api-key", "real")],
            extraGroups: [["X-API-Key": "attacker"]]
        )
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "real")
    }

    func testAnthropicVersionCannotBeOverridden() {
        var req = URLRequest(url: URL(string: "https://example.com")!)
        HeaderApplicator.apply(
            to: &req,
            auth: [("anthropic-version", "2023-06-01")],
            extraGroups: [["anthropic-version": "1999-01-01"]]
        )
        XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
    }

    func testGoogleAuthHeaderProtected() {
        var req = URLRequest(url: URL(string: "https://example.com")!)
        HeaderApplicator.apply(
            to: &req,
            auth: [("x-goog-api-key", "real")],
            extraGroups: [["x-goog-api-key": "attacker"]]
        )
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-goog-api-key"), "real")
    }

    func testMultipleExtraGroupsAppliedInOrder() {
        var req = URLRequest(url: URL(string: "https://example.com")!)
        HeaderApplicator.apply(
            to: &req,
            auth: [],
            extraGroups: [["X-Env": "instance"], ["X-Env": "config"]]
        )
        // Later group wins for non-deny-listed keys (config-level beats
        // instance-level), preserving prior compat semantics.
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Env"), "config")
    }
}
