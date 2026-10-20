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

@MainActor
final class PopupViewModelQuickModeTests: XCTestCase {
    private var presetStore: PresetStore!
    private var tempDir: URL!
    private var provider: MockLLMProvider!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PopupViewModelQuickModeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        presetStore = PresetStore(fileURL: tempDir.appendingPathComponent("presets.json"))
        try DefaultPresets.seedIfNeeded(into: presetStore)
        provider = MockLLMProvider()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    private func makeViewModel() -> PopupViewModel {
        let provider = provider!
        let service = TranslationService(provider: { _ in provider }, apiKey: { _ in "" })
        return PopupViewModel(
            translationService: service,
            presetStore: presetStore,
            pasteboard: PasteboardHelper(pasteboard: NSPasteboard(name: .init("PopupVMQuick-\(UUID().uuidString)")))
        )
    }

    func testQuickTranslationShowsOnlyOutputAndTranslatesSelection() async throws {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        let vm = makeViewModel()
        let target = try XCTUnwrap(presetStore.presets.last?.id)

        vm.startQuickTranslation(text: "Hello", presetID: target)

        XCTAssertTrue(vm.isOutputOnly)
        XCTAssertEqual(vm.selectedPresetID, target)
        XCTAssertEqual(vm.inputText, "Hello")
        for _ in 0..<100 where vm.state != .done(result: "Bonjour") {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(vm.state, .done(result: "Bonjour"))
    }

    func testShowInputLeavesOutputOnlyAndNotifiesOnce() throws {
        let vm = makeViewModel()
        var notified = 0
        vm.onShowInput = { notified += 1 }
        vm.presentQuickError("No text selected.", presetID: try XCTUnwrap(presetStore.presets.first?.id))
        XCTAssertTrue(vm.isOutputOnly)
        XCTAssertEqual(vm.state, .error(message: "No text selected.", partial: nil))

        vm.showInput()
        vm.showInput()

        XCTAssertFalse(vm.isOutputOnly)
        XCTAssertEqual(notified, 1)
    }

    func testNewAndDismissFromQuickErrorRestoreFullPopup() throws {
        let vm = makeViewModel()
        var notified = 0
        vm.onShowInput = { notified += 1 }
        let id = try XCTUnwrap(presetStore.presets.first?.id)

        vm.presentQuickError("x", presetID: id)
        vm.startNewTranslation()
        XCTAssertFalse(vm.isOutputOnly)
        XCTAssertEqual(notified, 1)

        vm.presentQuickError("x", presetID: id)
        vm.dismissError()
        XCTAssertFalse(vm.isOutputOnly)
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(notified, 2)
    }

    func testResetLeavesOutputOnlyWithoutResizeCallback() throws {
        let vm = makeViewModel()
        var notified = false
        vm.onShowInput = { notified = true }
        vm.presentQuickError("x", presetID: try XCTUnwrap(presetStore.presets.first?.id))

        vm.reset()

        XCTAssertFalse(vm.isOutputOnly)
        XCTAssertFalse(notified)
    }
}

@MainActor
final class PopupViewModelAccessibilityTests: XCTestCase {
    private var presetStore: PresetStore!
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PopupViewModelAccessibilityTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        presetStore = PresetStore(fileURL: tempDir.appendingPathComponent("presets.json"))
        try DefaultPresets.seedIfNeeded(into: presetStore)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    private func makeViewModel(granted: @escaping () -> Bool, opened: @escaping () -> Void = {}) -> PopupViewModel {
        PopupViewModel(
            translationService: TranslationService(provider: { _ in fatalError("unused") }, apiKey: { _ in "" }),
            presetStore: presetStore,
            isAccessibilityGranted: granted,
            openAccessibilitySettings: opened
        )
    }

    private func waitForState(_ vm: PopupViewModel, _ expected: PopupState) async throws {
        for _ in 0..<200 where vm.state != expected {
            try await Task.sleep(nanoseconds: 2_000_000)
        }
    }

    func testCardFlipsToGrantedWhenPermissionTurnsOn() async throws {
        var granted = false
        let vm = makeViewModel(granted: { granted })
        vm.presentAccessibilityRequired(presetID: try XCTUnwrap(presetStore.presets.first?.id), pollInterval: 1_000_000)

        XCTAssertTrue(vm.isOutputOnly)
        XCTAssertEqual(vm.state, .accessibilityRequired(granted: false))

        granted = true
        try await waitForState(vm, .accessibilityRequired(granted: true))
        XCTAssertEqual(vm.state, .accessibilityRequired(granted: true))
    }

    func testResetStopsWatchingForPermission() async throws {
        var granted = false
        let vm = makeViewModel(granted: { granted })
        vm.presentAccessibilityRequired(presetID: try XCTUnwrap(presetStore.presets.first?.id), pollInterval: 1_000_000)

        vm.reset()
        granted = true
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(vm.state, .idle)
    }

    func testOpenSettingsButtonCallsSystemOpener() {
        var opened = 0
        let vm = makeViewModel(granted: { false }, opened: { opened += 1 })
        vm.openAccessibilitySettings()
        XCTAssertEqual(opened, 1)
    }
}
