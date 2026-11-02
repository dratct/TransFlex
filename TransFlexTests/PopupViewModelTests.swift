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

    private func makeViewModel(hasAPIKey: @escaping (Preset) -> Bool = { _ in true }) -> PopupViewModel {
        let provider = provider!
        let service = TranslationService(provider: { _ in provider }, apiKey: { _ in "" })
        return PopupViewModel(
            translationService: service,
            presetStore: presetStore,
            pasteboard: PasteboardHelper(pasteboard: NSPasteboard(name: .init("PopupVMQuick-\(UUID().uuidString)"))),
            hasAPIKey: hasAPIKey
        )
    }

    // MARK: Missing key (audit D2)

    func testMissingKeyShowsNoticeInsteadOfSending() throws {
        let vm = makeViewModel(hasAPIKey: { _ in false })
        let preset = try XCTUnwrap(vm.selectedPreset)
        vm.inputText = "hello"

        vm.translate()

        XCTAssertEqual(vm.state, .missingKey(providerID: preset.providerID))
        XCTAssertEqual(vm.inputText, "hello", "the user's text stays")
        XCTAssertNil(provider.capturedConfig, "nothing is sent without a key")
    }

    func testBackToTextFromMissingKeyReturnsToTheEditor() {
        let vm = makeViewModel(hasAPIKey: { _ in false })
        vm.inputText = "hello"
        vm.translate()

        vm.dismissError()

        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.inputText, "hello")
    }

    func testSelectionWithoutKeyShowsTheNoticeInTheOutputOnlyPopup() throws {
        let vm = makeViewModel(hasAPIKey: { _ in false })
        let target = try XCTUnwrap(presetStore.presets.last)

        vm.startQuickTranslation(text: "Hello", presetID: target.id)

        XCTAssertTrue(vm.isOutputOnly)
        XCTAssertEqual(vm.state, .missingKey(providerID: target.providerID))
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

    // MARK: Translate again from History (C-4)

    func testTranslateAgainUsesSavedPresetAndText() async throws {
        provider.scriptedEvents = [.textDelta("Xin chao"), .stop(reason: .complete)]
        let vm = makeViewModel()
        let saved = try XCTUnwrap(presetStore.presets.last)
        XCTAssertNotEqual(vm.selectedPresetID, saved.id, "the saved preset is not the one already selected")
        vm.presentQuickError("earlier selection failed", presetID: saved.id)
        XCTAssertTrue(vm.isOutputOnly)
        vm.switchPreset(try XCTUnwrap(presetStore.presets.first?.id))

        vm.translateAgain(text: "Hello", presetID: saved.id)

        XCTAssertFalse(vm.isOutputOnly, "the full popup, with the source text, not the output-only one")
        XCTAssertEqual(vm.selectedPresetID, saved.id)
        XCTAssertEqual(vm.inputText, "Hello")
        for _ in 0..<100 where vm.state != .done(result: "Xin chao") {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(vm.state, .done(result: "Xin chao"))
        XCTAssertEqual(provider.capturedMessages.last?.content, "Hello")
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

    // MARK: Draft rule (CONTEXT.md)

    func testPopupDraftComesBackAfterSelectionWhenKept() throws {
        let vm = makeViewModel()
        let draftPreset = try XCTUnwrap(presetStore.presets.first?.id)
        let shortcutPreset = try XCTUnwrap(presetStore.presets.last?.id)
        vm.switchPreset(draftPreset)
        vm.inputText = "half-typed draft"

        vm.presentQuickError("No text selected.", presetID: shortcutPreset)
        XCTAssertEqual(vm.selectedPresetID, shortcutPreset)
        XCTAssertEqual(vm.inputText, "", "the Output-only popup never shows the Draft")

        vm.openPopup(keepingDraft: true)

        XCTAssertFalse(vm.isOutputOnly)
        XCTAssertEqual(vm.inputText, "half-typed draft")
        XCTAssertEqual(vm.selectedPresetID, draftPreset)
        XCTAssertEqual(vm.state, .idle)
    }

    func testPopupResultComesBackWithItsDraft() throws {
        let vm = makeViewModel()
        vm.inputText = "hello"
        vm.state = .done(result: "xin chào")

        vm.presentQuickError("x", presetID: try XCTUnwrap(presetStore.presets.last?.id))
        vm.openPopup(keepingDraft: true)

        XCTAssertEqual(vm.inputText, "hello")
        XCTAssertEqual(vm.state, .done(result: "xin chào"))
    }

    func testPopupStartsEmptyAfterSelectionWhenCleared() throws {
        let vm = makeViewModel()
        let draftPreset = try XCTUnwrap(presetStore.presets.first?.id)
        vm.switchPreset(draftPreset)
        vm.inputText = "old draft"
        vm.state = .done(result: "cũ")

        vm.presentQuickError("x", presetID: try XCTUnwrap(presetStore.presets.last?.id))
        vm.openPopup(keepingDraft: false)

        XCTAssertFalse(vm.isOutputOnly)
        XCTAssertEqual(vm.inputText, "")
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.selectedPresetID, draftPreset, "the preset is a choice, not part of the Draft")
    }

    func testPopupNeverInheritsTheSelectionResult() throws {
        let vm = makeViewModel()

        vm.presentQuickError("No text selected.", presetID: try XCTUnwrap(presetStore.presets.last?.id))
        vm.openPopup(keepingDraft: true)

        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.inputText, "")
    }

    func testTwoSelectionsInARowStillHandBackTheFirstDraft() throws {
        let vm = makeViewModel()
        let last = try XCTUnwrap(presetStore.presets.last?.id)
        vm.inputText = "draft"

        vm.presentQuickError("x", presetID: last)
        vm.presentQuickError("y", presetID: last)
        vm.openPopup(keepingDraft: true)

        XCTAssertEqual(vm.inputText, "draft")
    }

    func testReopeningThePopupClearsOnlyWhenTold() {
        let vm = makeViewModel()
        vm.inputText = "draft"

        vm.openPopup(keepingDraft: true)
        XCTAssertEqual(vm.inputText, "draft")

        vm.openPopup(keepingDraft: false)
        XCTAssertEqual(vm.inputText, "")
    }

    func testShowInputTurnsTheSelectionIntoThePopup() throws {
        let vm = makeViewModel()
        vm.inputText = "older draft"
        vm.presentQuickError("x", presetID: try XCTUnwrap(presetStore.presets.last?.id))
        vm.inputText = "selected text"

        vm.showInput()
        vm.openPopup(keepingDraft: true)

        XCTAssertEqual(vm.inputText, "selected text")
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

    func testTranslateAgainCommandActsOnlyOnAShownResult() async throws {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        let vm = makeViewModel()

        XCTAssertFalse(vm.translateAgainIfShown(), "idle leaves ⌘↩ to the Translate button")

        vm.inputText = "Hello"
        vm.translate()
        for _ in 0..<100 where vm.state != .done(result: "Bonjour") {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        vm.inputText = "Hello there"
        provider.scriptedEvents = [.textDelta("Salut"), .stop(reason: .complete)]

        XCTAssertTrue(vm.translateAgainIfShown())
        for _ in 0..<100 where vm.state != .done(result: "Salut") {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(vm.state, .done(result: "Salut"), "⌘↩ after a result translates the edited source")
    }

    func testTranslateAgainCommandIgnoresTheOutputOnlyPopup() async throws {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        let vm = makeViewModel()
        vm.startQuickTranslation(text: "Hello", presetID: try XCTUnwrap(presetStore.presets.first?.id))
        for _ in 0..<100 where vm.state != .done(result: "Bonjour") {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(vm.state, .done(result: "Bonjour"))

        XCTAssertFalse(vm.translateAgainIfShown(), "the Output-only popup has no source to translate again")
        XCTAssertEqual(vm.state, .done(result: "Bonjour"))
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

    func testAccessibilityCardKeepsDraftForNextPopupOpen() throws {
        let vm = makeViewModel(granted: { false })
        vm.inputText = "draft"

        vm.presentAccessibilityRequired(presetID: try XCTUnwrap(presetStore.presets.last?.id), pollInterval: 1_000_000)
        vm.openPopup(keepingDraft: true)

        XCTAssertEqual(vm.inputText, "draft")
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

final class PopupHideClockTests: XCTestCase {
    private let twoMinutes = PopupResetPolicy.afterMinutes(2)
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testDraftKeptWithinThePolicyWindow() {
        var clock = PopupHideClock()
        clock.recordHide(outputOnly: false, at: t0)
        XCTAssertTrue(clock.keepsDraft(policy: twoMinutes, now: t0.addingTimeInterval(60)))
        XCTAssertFalse(clock.keepsDraft(policy: twoMinutes, now: t0.addingTimeInterval(130)))
    }

    func testOutputOnlyHideDoesNotExtendTheWindow() {
        var clock = PopupHideClock()
        clock.recordHide(outputOnly: false, at: t0)
        clock.recordHide(outputOnly: true, at: t0.addingTimeInterval(90))
        XCTAssertFalse(clock.keepsDraft(policy: twoMinutes, now: t0.addingTimeInterval(130)))
    }

    func testFirstOpenStartsEmptyUnlessNever() {
        let clock = PopupHideClock()
        XCTAssertFalse(clock.keepsDraft(policy: twoMinutes, now: t0))
        XCTAssertTrue(clock.keepsDraft(policy: .never, now: t0))
    }
}

final class PopupEscapeTests: XCTestCase {
    func testStreamingStops() {
        XCTAssertEqual(PopupEscape.action(for: .streaming(accumulated: "x"), isOutputOnly: false), .stop)
        XCTAssertEqual(PopupEscape.action(for: .streaming(accumulated: ""), isOutputOnly: true), .stop)
    }

    func testNoticeCardGoesBackToTheText() {
        XCTAssertEqual(PopupEscape.action(for: .error(message: "x", partial: nil), isOutputOnly: false), .backToText)
        XCTAssertEqual(PopupEscape.action(for: .missingKey(providerID: "openai"), isOutputOnly: false), .backToText)
    }

    func testEverythingElseCloses() {
        XCTAssertEqual(PopupEscape.action(for: .idle, isOutputOnly: false), .close)
        XCTAssertEqual(PopupEscape.action(for: .done(result: "x"), isOutputOnly: false), .close)
        XCTAssertEqual(PopupEscape.action(for: .error(message: "x", partial: "p"), isOutputOnly: false), .close)
        // The Output-only popup has no text to go back to.
        XCTAssertEqual(PopupEscape.action(for: .error(message: "x", partial: nil), isOutputOnly: true), .close)
        XCTAssertEqual(PopupEscape.action(for: .missingKey(providerID: "openai"), isOutputOnly: true), .close)
        XCTAssertEqual(PopupEscape.action(for: .accessibilityRequired(granted: false), isOutputOnly: true), .close)
    }
}
