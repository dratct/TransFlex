import XCTest
@testable import TransFlex

@MainActor
final class ProvidersStoreTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!
    private var keychain: KeychainStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        fileURL = tempDir.appendingPathComponent("providers.json")
        keychain = KeychainStore(service: "io.aiaz.transflex.tests.providers.\(UUID().uuidString)")
    }

    override func tearDown() {
        try? keychain.deleteAll()
        try? FileManager.default.removeItem(at: tempDir)
        keychain = nil
        fileURL = nil
        tempDir = nil
        super.tearDown()
    }

    func testCompatHeadersPersistNamesOnlyAndStoreValuesInKeychain() throws {
        let store = ProvidersStore(fileURL: fileURL, keychain: keychain)
        let instance = OpenAICompatInstance(
            instanceId: "gateway",
            displayName: "Gateway",
            baseURL: URL(string: "https://gw.example.com/v1")!,
            extraHeaders: ["X-Gateway-Token": "secret-token"]
        )

        try store.addCompatInstance(instance, apiKey: "api-secret")

        let data = try Data(contentsOf: fileURL)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("X-Gateway-Token"))
        XCTAssertFalse(json.contains("secret-token"))
        XCTAssertFalse(json.contains("api-secret"))
        XCTAssertEqual(store.compatExtraHeaderValue(for: "gateway", headerName: "X-Gateway-Token"), "secret-token")
    }

    func testLegacyHeaderValuesMigrateOutOfProvidersJSON() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try """
        {
          "openAICompatInstances": [
            {
              "instanceId": "legacy",
              "displayName": "Legacy",
              "baseURL": "https://gw.example.com/v1",
              "extraHeaders": { "X-Legacy-Token": "legacy-secret" }
            }
          ]
        }
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = ProvidersStore(fileURL: fileURL, keychain: keychain)

        let json = try String(contentsOf: fileURL)
        XCTAssertFalse(json.contains("legacy-secret"))
        XCTAssertEqual(store.compatExtraHeaderValue(for: "legacy", headerName: "X-Legacy-Token"), "legacy-secret")
    }
}
