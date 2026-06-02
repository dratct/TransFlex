import XCTest
@testable import TransFlex

final class KeychainStoreTests: XCTestCase {
    private var store: KeychainStore!
    private var testService: String!

    override func setUp() {
        super.setUp()
        // Fresh service per test method keeps state isolated even across
        // parallel runs and avoids polluting the user's login keychain.
        testService = "io.aiaz.transflex.tests.\(UUID().uuidString)"
        store = KeychainStore(service: testService)
    }

    override func tearDown() {
        try? store.deleteAll()
        store = nil
        testService = nil
        super.tearDown()
    }

    func testStringRoundTrip() throws {
        try store.set("sk-secret-123", forKey: "openai")
        XCTAssertEqual(try store.get("openai"), "sk-secret-123")
    }

    func testStringOverwrite() throws {
        try store.set("first", forKey: "k")
        try store.set("second", forKey: "k")
        XCTAssertEqual(try store.get("k"), "second")
    }

    func testRepeatedOverwriteSurvivesDuplicateItem() throws {
        // Regression guard for add-first-then-update path: the second write
        // hits errSecDuplicateItem, and must transparently update.
        for value in ["v1", "v2", "v3", "v4"] {
            try store.set(value, forKey: "rotating")
        }
        XCTAssertEqual(try store.get("rotating"), "v4")
    }

    func testMissingKeyReturnsNil() throws {
        XCTAssertNil(try store.get("nope"))
    }

    func testDeleteRemovesItem() throws {
        try store.set("v", forKey: "k")
        try store.delete("k")
        XCTAssertNil(try store.get("k"))
    }

    func testDeleteMissingDoesNotThrow() {
        XCTAssertNoThrow(try store.delete("never-set"))
    }

    func testSetNilDeletes() throws {
        try store.set("v", forKey: "k")
        try store.set(nil, forKey: "k")
        XCTAssertNil(try store.get("k"))
    }

    func testDataRoundTrip() throws {
        let blob = Data([0x00, 0xff, 0x42, 0x13])
        try store.setData(blob, forKey: "blob")
        XCTAssertEqual(try store.getData("blob"), blob)
    }

    func testIsolationPerService() throws {
        let other = KeychainStore(service: testService + ".other")
        try store.set("a", forKey: "shared")
        try other.set("b", forKey: "shared")
        XCTAssertEqual(try store.get("shared"), "a")
        XCTAssertEqual(try other.get("shared"), "b")
        try other.deleteAll()
    }
}
