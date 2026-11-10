import XCTest
@testable import TransFlex

/// The first key for Anthropic or Gemini moves the built-in presets the user
/// never edited onto that provider, so they work without another step.
@MainActor
final class ProviderKeySaverTests: XCTestCase {
    private var tempDir: URL!
    private var keychain: KeychainStore!
    private var presets: PresetStore!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ProviderKeySaverTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        keychain = KeychainStore(service: "io.aiaz.transflex.tests.ProviderKeySaver")
        try? keychain.deleteAll()
        presets = PresetStore(fileURL: tempDir.appendingPathComponent("presets.json"))
        try DefaultPresets.seedIfNeeded(into: presets)
    }

    override func tearDown() async throws {
        try? keychain.deleteAll()
        try? FileManager.default.removeItem(at: tempDir)
    }

    private var saver: ProviderKeySaver { ProviderKeySaver(keychain: keychain, presetStore: presets) }

    private func preset(named name: String) -> Preset? {
        presets.presets.first { $0.name == name }
    }

    func testFirstAnthropicKeyMovesUneditedBuiltins() throws {
        let before = preset(named: "Natural EN ↔ VI")?.updatedAt
        try saver.save("sk-ant-test", for: "anthropic")

        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.providerID, "anthropic")
        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.modelID, "claude-haiku-4-5")
        XCTAssertEqual(preset(named: "Technical Doc EN ↔ VI")?.modelID, "claude-sonnet-5-5")
        XCTAssertEqual(preset(named: "Any → English (Natural)")?.modelID, "claude-haiku-4-5")
        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.updatedAt, before, "a move is not a user edit")
        XCTAssertEqual(PresetStore(fileURL: tempDir.appendingPathComponent("presets.json")).presets.map(\.providerID),
                       ["anthropic", "anthropic", "anthropic"], "the move is saved")
    }

    func testFirstGeminiKeyUsesGeminiModels() throws {
        try saver.save("AIza-test", for: "gemini")
        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.providerID, "gemini")
        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.modelID, "gemini-2.0-flash")
        XCTAssertEqual(preset(named: "Technical Doc EN ↔ VI")?.modelID, "gemini-1.5-pro")
    }

    func testEditedPresetStaysOnOpenAI() throws {
        var edited = try XCTUnwrap(preset(named: "Natural EN ↔ VI"))
        edited.systemPrompt += "\nAlways use formal Vietnamese."
        try presets.update(edited)
        var renamed = try XCTUnwrap(preset(named: "Technical Doc EN ↔ VI"))
        renamed.name = "My docs"
        try presets.update(renamed)

        try saver.save("sk-ant-test", for: "anthropic")

        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.providerID, "openai")
        XCTAssertEqual(preset(named: "My docs")?.providerID, "openai")
        XCTAssertEqual(preset(named: "Any → English (Natural)")?.providerID, "anthropic")
    }

    func testPresetWithAChosenModelStays() throws {
        var chosen = try XCTUnwrap(preset(named: "Natural EN ↔ VI"))
        chosen.modelID = "gpt-4.1"
        try presets.update(chosen)

        try saver.save("sk-ant-test", for: "anthropic")

        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.providerID, "openai")
        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.modelID, "gpt-4.1")
    }

    func testSecondKeyMovesNothing() throws {
        try keychain.set("sk-openai", forKey: "provider.openai.apiKey")
        try saver.save("sk-ant-test", for: "anthropic")
        XCTAssertEqual(Set(presets.presets.map(\.providerID)), ["openai"])
    }

    func testFirstOpenAIKeyMovesNothing() throws {
        try saver.save("sk-openai", for: "openai")
        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.modelID, "gpt-4o-mini")
        XCTAssertEqual(Set(presets.presets.map(\.providerID)), ["openai"])
    }

    func testEmptyKeyMovesNothing() {
        XCTAssertThrowsError(try saver.save("  ", for: "anthropic"))
        XCTAssertEqual(Set(presets.presets.map(\.providerID)), ["openai"])
    }

    func testSettingsSaveMovesPresets() throws {
        let store = ProvidersStore(fileURL: tempDir.appendingPathComponent("providers.json"), keychain: keychain)
        store.presetStore = presets
        try store.setCloudAPIKey("sk-ant-test", for: "anthropic")
        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.providerID, "anthropic")
        XCTAssertTrue(keychain.exists("provider.anthropic.apiKey"))
    }

    func testSettingsRemoveKeyStillDeletes() throws {
        let store = ProvidersStore(fileURL: tempDir.appendingPathComponent("providers.json"), keychain: keychain)
        store.presetStore = presets
        try keychain.set("sk-ant-test", forKey: "provider.anthropic.apiKey")
        try store.setCloudAPIKey("", for: "anthropic")
        XCTAssertFalse(keychain.exists("provider.anthropic.apiKey"))
    }

    func testWelcomeSaveMovesPresets() {
        let model = ProviderSetupModel.live(keychain: keychain, presetStore: presets)
        model.selected = "gemini"
        model.key = "AIza-test"
        XCTAssertTrue(model.save())
        XCTAssertEqual(preset(named: "Natural EN ↔ VI")?.providerID, "gemini")
    }

    func testNewPresetUsesKeyedProvider() {
        XCTAssertEqual(PresetStore.newPresetProvider(keyed: []).providerID, "openai")
        XCTAssertEqual(PresetStore.newPresetProvider(keyed: ["gemini"]).providerID, "gemini")
        XCTAssertEqual(PresetStore.newPresetProvider(keyed: ["gemini"]).model, "gemini-2.0-flash")
        XCTAssertEqual(PresetStore.newPresetProvider(keyed: ["gemini", "anthropic"]).model, "claude-haiku-4-5")
        XCTAssertEqual(PresetStore.newPresetProvider(keyed: ["anthropic", "openai"]).model, "gpt-4o-mini")
    }
}
