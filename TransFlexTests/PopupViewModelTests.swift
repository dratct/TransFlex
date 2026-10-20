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

    func testQuickErrorKeepsDraftAndPresetForNextNormalOpen() throws {
        let vm = makeViewModel()
        let draftPreset = try XCTUnwrap(presetStore.presets.first?.id)
        let shortcutPreset = try XCTUnwrap(presetStore.presets.last?.id)
        vm.switchPreset(draftPreset)
        vm.inputText = "half-typed draft"

        vm.presentQuickError("No text selected.", presetID: shortcutPreset)
        XCTAssertEqual(vm.selectedPresetID, shortcutPreset)

        vm.leaveOutputOnly()

        XCTAssertFalse(vm.isOutputOnly)
        XCTAssertEqual(vm.inputText, "half-typed draft")
        XCTAssertEqual(vm.selectedPresetID, draftPreset)
        XCTAssertEqual(vm.state, .idle)
    }

    func testQuickWithoutDraftKeepsQuickResultOnNormalOpen() throws {
        let vm = makeViewModel()
        let shortcutPreset = try XCTUnwrap(presetStore.presets.last?.id)

        vm.presentQuickError("No text selected.", presetID: shortcutPreset)
        vm.leaveOutputOnly()

        XCTAssertEqual(vm.selectedPresetID, shortcutPreset)
        XCTAssertEqual(vm.state, .error(message: "No text selected.", partial: nil))
    }

    func testStaleResetDropsKeptDraft() throws {
        let vm = makeViewModel()
        vm.inputText = "old draft"
        vm.presentQuickError("x", presetID: try XCTUnwrap(presetStore.presets.last?.id))

        vm.reset()
        vm.leaveOutputOnly()

        XCTAssertEqual(vm.inputText, "")
    }

    func testAttachOnPresetWithoutVisionExplainsInsteadOfAttaching() throws {
        let vm = makeViewModel()
        let preset = try XCTUnwrap(vm.selectedPreset)
        XCTAssertFalse(preset.supportsVision)
        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }

        vm.attachImage(image, source: .paste)

        XCTAssertNil(vm.attachedImage)
        guard case .error(let message, nil) = vm.state else {
            return XCTFail("expected an error, got \(vm.state)")
        }
        XCTAssertTrue(message.contains("Supports Vision"), message)
    }

    func testCopyResultCopiesOnlyWhenATranslationIsShown() async throws {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        let board = NSPasteboard(name: .init("PopupVMCopy-\(UUID().uuidString)"))
        let service = TranslationService(provider: { [provider] _ in provider! }, apiKey: { _ in "" })
        let vm = PopupViewModel(translationService: service, presetStore: presetStore, pasteboard: PasteboardHelper(pasteboard: board))

        XCTAssertFalse(vm.copyResultIfShown(), "idle popup must leave ⌘C to the text editor")

        vm.inputText = "Hello"
        vm.translate()
        for _ in 0..<100 where vm.state != .done(result: "Bonjour") {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        board.clearContents()

        XCTAssertTrue(vm.copyResultIfShown())
        XCTAssertEqual(board.string(forType: .string), "Bonjour")
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

    func testAccessibilityCardKeepsDraftForNextNormalOpen() throws {
        let vm = makeViewModel(granted: { false })
        vm.inputText = "draft"

        vm.presentAccessibilityRequired(presetID: try XCTUnwrap(presetStore.presets.last?.id), pollInterval: 1_000_000)
        vm.leaveOutputOnly()

        XCTAssertEqual(vm.inputText, "draft")
        XCTAssertEqual(vm.state, .idle)
    }

    func testAccessibilityCardWithoutDraftStartsCleanOnNormalOpen() throws {
        let vm = makeViewModel(granted: { false })

        vm.presentAccessibilityRequired(presetID: try XCTUnwrap(presetStore.presets.last?.id), pollInterval: 1_000_000)
        vm.leaveOutputOnly()

        XCTAssertEqual(vm.state, .idle)
        XCTAssertFalse(vm.isOutputOnly)
    }

    func testOpenSettingsButtonCallsSystemOpener() {
        var opened = 0
        let vm = makeViewModel(granted: { false }, opened: { opened += 1 })
        vm.openAccessibilitySettings()
        XCTAssertEqual(opened, 1)
    }
}
