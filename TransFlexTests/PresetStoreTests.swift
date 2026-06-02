import XCTest
@testable import TransFlex

final class PresetStoreTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PresetStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("presets.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    @MainActor
    func testStartsEmptyWhenFileMissing() {
        let store = PresetStore(fileURL: fileURL)
        XCTAssertTrue(store.presets.isEmpty)
    }

    @MainActor
    func testSeedingCreatesFileWithBuiltins() throws {
        let store = PresetStore(fileURL: fileURL)
        try DefaultPresets.seedIfNeeded(into: store)
        XCTAssertEqual(store.presets.count, DefaultPresets.builtins.count)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @MainActor
    func testSeedingIsIdempotent() throws {
        let store = PresetStore(fileURL: fileURL)
        try DefaultPresets.seedIfNeeded(into: store)
        let firstIDs = store.presets.map(\.id)
        try DefaultPresets.seedIfNeeded(into: store)
        XCTAssertEqual(store.presets.map(\.id), firstIDs)
    }

    @MainActor
    func testRoundTripAcrossInstances() throws {
        let s1 = PresetStore(fileURL: fileURL)
        try DefaultPresets.seedIfNeeded(into: s1)
        let originalCount = s1.presets.count

        let s2 = PresetStore(fileURL: fileURL)
        XCTAssertEqual(s2.presets.count, originalCount)
        XCTAssertEqual(s2.presets.map(\.name).sorted(),
                       s1.presets.map(\.name).sorted())
    }

    @MainActor
    func testCRUDPersists() throws {
        let store = PresetStore(fileURL: fileURL)
        let preset = Preset(
            name: "Custom",
            providerID: "openai",
            modelID: "gpt-4o-mini",
            systemPrompt: "translate"
        )
        try store.add(preset)
        XCTAssertEqual(store.presets.count, 1)

        var modified = preset
        modified.name = "Renamed"
        try store.update(modified)
        XCTAssertEqual(store.presets.first?.name, "Renamed")

        try store.delete(id: preset.id)
        XCTAssertTrue(store.presets.isEmpty)

        // Reload to confirm disk state.
        let reloaded = PresetStore(fileURL: fileURL)
        XCTAssertTrue(reloaded.presets.isEmpty)
    }



    @MainActor
    func testCorruptFileBackedUpAndStartsEmpty() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ this is not valid json".utf8).write(to: fileURL)
        let store = PresetStore(fileURL: fileURL)
        XCTAssertTrue(store.presets.isEmpty)

        let entries = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertTrue(entries.contains { $0.contains("bak") }, "expected backup file present, got \(entries)")
    }

    @MainActor
    func testIsOrphanedFlagsUnknownProvider() throws {
        let store = PresetStore(fileURL: fileURL)
        let registry = ProviderRegistry(session: .shared)
        let known = Preset(name: "ok", providerID: "openai", modelID: "gpt-4o-mini", systemPrompt: "")
        let orphan = Preset(name: "missing", providerID: "openai-compatible:gone", modelID: "x", systemPrompt: "")
        XCTAssertFalse(store.isOrphaned(known, in: registry))
        XCTAssertTrue(store.isOrphaned(orphan, in: registry))
    }

    @MainActor
    func testDuplicateHotkeysRejected() throws {
        let store = PresetStore(fileURL: fileURL)
        let combo = KeyCombo(modifiers: 0x80000, keyCode: 18)
        let p1 = Preset(name: "A", hotkey: combo, providerID: "openai", modelID: "m", systemPrompt: "")
        let p2 = Preset(name: "B", hotkey: combo, providerID: "openai", modelID: "m", systemPrompt: "")

        XCTAssertThrowsError(try store.replaceAll(with: [p1, p2])) { error in
            guard let storeError = error as? PresetStoreError,
                  case .duplicateHotkey(let k, _) = storeError else {
                XCTFail("expected duplicateHotkey, got \(error)")
                return
            }
            XCTAssertEqual(k, combo)
        }
        XCTAssertTrue(store.presets.isEmpty, "failed save must not mutate in-memory state")
    }

    @MainActor
    func testNilHotkeysDoNotCollide() throws {
        let store = PresetStore(fileURL: fileURL)
        let p1 = Preset(name: "A", hotkey: nil, providerID: "openai", modelID: "m", systemPrompt: "")
        let p2 = Preset(name: "B", hotkey: nil, providerID: "openai", modelID: "m", systemPrompt: "")
        try store.replaceAll(with: [p1, p2])
        XCTAssertEqual(store.presets.count, 2)
    }

    @MainActor
    func testDistinctHotkeysAllowed() throws {
        let store = PresetStore(fileURL: fileURL)
        let p1 = Preset(name: "A", hotkey: KeyCombo(modifiers: 0x80000, keyCode: 18), providerID: "openai", modelID: "m", systemPrompt: "")
        let p2 = Preset(name: "B", hotkey: KeyCombo(modifiers: 0x80000, keyCode: 19), providerID: "openai", modelID: "m", systemPrompt: "")
        try store.replaceAll(with: [p1, p2])
        XCTAssertEqual(store.presets.count, 2)
    }
}
