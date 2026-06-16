import XCTest
@testable import TransFlex

@MainActor
final class PopupViewModelTests: XCTestCase {
    private var presetStore: PresetStore!
    private var tempDir: URL!
    private var fileURL: URL!
    private var service: TranslationService!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PopupViewModelTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("presets.json")
        presetStore = PresetStore(fileURL: fileURL)
        try DefaultPresets.seedIfNeeded(into: presetStore)

        service = TranslationService(
            provider: { _ in fatalError("Not expected to run translation") },
            apiKey: { _ in "" }
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    func testInitDefaultsToFirstPreset() {
        let vm = PopupViewModel(
            translationService: service,
            presetStore: presetStore
        )
        XCTAssertEqual(vm.selectedPresetID, presetStore.presets.first?.id)
    }

    func testResetPreservesSelectedPreset() {
        let vm = PopupViewModel(
            translationService: service,
            presetStore: presetStore
        )
        XCTAssertEqual(vm.selectedPresetID, presetStore.presets.first?.id)

        if presetStore.presets.count > 1 {
            let secondPresetID = presetStore.presets[1].id
            vm.switchPreset(secondPresetID)
            XCTAssertEqual(vm.selectedPresetID, secondPresetID)

            vm.reset()
            XCTAssertEqual(vm.selectedPresetID, secondPresetID)
        }
    }
}
