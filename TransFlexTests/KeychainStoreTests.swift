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

    func testDeleteAllRemovesEveryItemUnderService() throws {
        // The file-based keychain deletes only one match per SecItemDelete call.
        try store.set("a", forKey: "first")
        try store.set("b", forKey: "second")
        try store.deleteAll()
        XCTAssertFalse(store.exists("first"))
        XCTAssertFalse(store.exists("second"))
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

/// Query shape per backend; these never touch a keychain.
final class KeychainStoreQueryTests: XCTestCase {
    func testFileBackendQueriesTheFileBasedKeychain() {
        let store = KeychainStore(service: "svc", backend: .file)

        let query = store.addQuery(account: "k", data: Data("v".utf8))

        XCTAssertNil(query[kSecUseDataProtectionKeychain as String])
        XCTAssertNil(query[kSecAttrAccessible as String])
        XCTAssertEqual(query[kSecAttrService as String] as? String, "svc")
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, "k")
    }

    func testDataProtectionBackendSetsFlagAndAccessibility() {
        let store = KeychainStore(service: "svc", backend: .dataProtection)

        let query = store.addQuery(account: "k", data: Data("v".utf8))

        XCTAssertEqual(query[kSecUseDataProtectionKeychain as String] as? Bool, true)
        XCTAssertEqual(
            query[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlock as String
        )
    }

    func testMissingEntitlementGetsItsOwnError() {
        XCTAssertEqual(KeychainError(status: errSecMissingEntitlement), .missingEntitlement)
        XCTAssertEqual(KeychainError(status: errSecInteractionNotAllowed), .unhandled(errSecInteractionNotAllowed))
    }
}

/// A Debug build configured with its own keychain file keeps every item there,
/// never in the login keychain.
final class KeychainStoreFileAtTests: XCTestCase {
    private var directory: URL!
    private var path: String!
    private var keychain: SecKeychain?
    private var service: String!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("KeychainStoreFileAtTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        path = directory.appendingPathComponent("test.keychain-db").path
        let password = "test-password"
        let status = SecKeychainCreate(path, UInt32(password.utf8.count), password, false, nil, &keychain)
        XCTAssertEqual(status, errSecSuccess)
        service = "io.aiaz.transflex.tests.fileAt.\(UUID().uuidString)"
        // A locked keychain must fail, not put a password dialog on the screen.
        SecKeychainSetUserInteractionAllowed(false)
    }

    override func tearDownWithError() throws {
        SecKeychainSetUserInteractionAllowed(true)
        try? KeychainStore(service: service, backend: .file).deleteAll()
        if let keychain { SecKeychainDelete(keychain) }
        try? FileManager.default.removeItem(at: directory)
    }

    private var store: KeychainStore { KeychainStore(service: service, backend: .fileAt(path: path)) }
    private var loginStore: KeychainStore { KeychainStore(service: service, backend: .file) }

    func testRoundTripStaysInItsKeychain() throws {
        try store.set("sk-secret", forKey: "provider.openai.apiKey")

        XCTAssertFalse(loginStore.exists("provider.openai.apiKey"), "nothing lands in the login keychain")
        XCTAssertTrue(store.exists("provider.openai.apiKey"))
        XCTAssertEqual(try store.get("provider.openai.apiKey"), "sk-secret")

        try store.set("sk-second", forKey: "provider.openai.apiKey")
        XCTAssertEqual(try store.get("provider.openai.apiKey"), "sk-second")

        try store.delete("provider.openai.apiKey")
        XCTAssertFalse(store.exists("provider.openai.apiKey"))
    }

    func testDeleteAllEmptiesOnlyItsKeychain() throws {
        try store.set("a", forKey: "one")
        try store.set("b", forKey: "two")
        try store.deleteAll()
        XCTAssertNil(try store.get("one"))
        XCTAssertNil(try store.get("two"))
    }

    private func lockedStore(passwordFile contents: String?) throws -> KeychainStore {
        try store.set("sk-secret", forKey: "provider.openai.apiKey")
        let passwordFile = directory.appendingPathComponent("keychain-password").path
        if let contents { try contents.write(toFile: passwordFile, atomically: true, encoding: .utf8) }
        XCTAssertEqual(SecKeychainLock(keychain), errSecSuccess)
        return KeychainStore(service: service, backend: .fileAt(path: path, passwordFile: passwordFile))
    }

    private func isUnlocked() -> Bool {
        var status: SecKeychainStatus = 0
        SecKeychainGetStatus(keychain, &status)
        return status & SecKeychainStatus(kSecUnlockStateStatus) != 0
    }

    func testLockedKeychainUnlocksWithItsPasswordFile() throws {
        let locked = try lockedStore(passwordFile: "test-password\n")
        XCTAssertEqual(try locked.get("provider.openai.apiKey"), "sk-secret")
        XCTAssertTrue(isUnlocked())
    }

    // With user interaction off, a query on a locked keychain fails with -25308 anyway, so these
    // tests name the error the unlock step itself raises.
    func testWrongPasswordFileThrows() throws {
        let locked = try lockedStore(passwordFile: "not-the-password")
        XCTAssertThrowsError(try locked.get("provider.openai.apiKey")) {
            XCTAssertEqual($0 as? KeychainError, .unhandled(errSecAuthFailed))
        }
        XCTAssertFalse(isUnlocked())
    }

    func testMissingPasswordFileThrows() throws {
        let locked = try lockedStore(passwordFile: nil)
        let passwordFile = directory.appendingPathComponent("keychain-password").path
        XCTAssertThrowsError(try locked.get("provider.openai.apiKey")) {
            XCTAssertEqual($0 as? KeychainError, .passwordFileUnreadable(passwordFile))
        }
        XCTAssertFalse(isUnlocked())
    }

    func testLockedKeychainWithoutPasswordFileThrows() throws {
        _ = try lockedStore(passwordFile: nil)
        let noFile = KeychainStore(service: service, backend: .fileAt(path: path))
        XCTAssertThrowsError(try noFile.get("provider.openai.apiKey")) {
            XCTAssertEqual($0 as? KeychainError, .lockedWithoutPasswordFile)
        }
    }

    func testMissingKeychainFileThrowsInsteadOfUsingLogin() {
        let missing = KeychainStore(service: service, backend: .fileAt(path: directory.appendingPathComponent("absent.keychain-db").path))
        XCTAssertThrowsError(try missing.set("x", forKey: "k"))
        XCTAssertFalse(loginStore.exists("k"), "a missing keychain never falls back to login")
    }
}
