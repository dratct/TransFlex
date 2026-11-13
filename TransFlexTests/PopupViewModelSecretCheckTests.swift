import XCTest
@testable import TransFlex

@MainActor
final class PopupViewModelSecretCheckTests: XCTestCase {
    private static let token = SecretScannerTests.githubToken
    private static let flagged = "deploy with \(token) today"
    private static let match = SecretMatch(kind: "GitHub token", masked: "ghp_…ZZZZ")

    private var presetStore: PresetStore!
    private var tempDir: URL!
    private var provider: MockLLMProvider!
    private var announcer: RecordingAnnouncer!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PopupViewModelSecretCheckTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        presetStore = PresetStore(fileURL: tempDir.appendingPathComponent("presets.json"))
        try DefaultPresets.seedIfNeeded(into: presetStore)
        provider = MockLLMProvider()
        provider.scriptedEvents = [.textDelta("bonjour")]
        announcer = RecordingAnnouncer()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    private func makeViewModel(isOn: Bool = true, isOnThisMac: Bool = false) -> PopupViewModel {
        let provider = provider!
        return PopupViewModel(
            translationService: TranslationService(provider: { _ in provider }, apiKey: { _ in "" }),
            presetStore: presetStore,
            pasteboard: PasteboardHelper(pasteboard: NSPasteboard(name: .init("PopupVMSecret-\(UUID().uuidString)"))),
            announcer: announcer,
            secretCheck: SecretCheck(isOn: { isOn }, isOnThisMac: { _ in isOnThisMac })
        )
    }

    private var wasSent: Bool { !provider.capturedMessages.isEmpty }

    private func flaggedViewModel() throws -> PopupViewModel {
        let vm = makeViewModel()
        vm.inputText = Self.flagged
        vm.translate()
        XCTAssertEqual(vm.state, .secretFound(Self.match, providerID: try XCTUnwrap(vm.selectedPreset).providerID))
        return vm
    }

    // MARK: Stopping

    func testSecretStopsBeforeSendingAndShowsKindAndMaskedValue() throws {
        let vm = try flaggedViewModel()
        let name = ProviderRegistry.shared.displayName(for: try XCTUnwrap(vm.selectedPreset).providerID)

        XCTAssertFalse(wasSent)
        XCTAssertEqual(announcer.messages.last, "GitHub token found. Not sent to \(name).")
    }

    func testOrdinaryTextTranslatesAsBefore() async throws {
        let vm = makeViewModel()
        vm.inputText = "clone https://git@github.com/a/b.git with sk-short"

        vm.translate()

        try await waitUntil({ vm.state == .done(result: "bonjour") })
        XCTAssertTrue(wasSent)
    }

    func testSettingOffSendsTheSecret() async throws {
        let vm = makeViewModel(isOn: false)
        vm.inputText = Self.flagged

        vm.translate()

        try await waitUntil({ vm.state == .done(result: "bonjour") })
    }

    func testEndpointOnThisMacIsNotChecked() async throws {
        let vm = makeViewModel(isOnThisMac: true)
        vm.inputText = Self.flagged

        vm.translate()

        try await waitUntil({ vm.state == .done(result: "bonjour") })
    }

    func testSettingIsOnUntilTheUserTurnsItOff() {
        let suite = "io.aiaz.transflex.tests.SecretCheck"
        UserDefaults().removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        let check = SecretCheck.live(defaults: defaults)

        XCTAssertTrue(check.isOn(), "never set: on")
        XCTAssertEqual(check.match(in: Self.flagged, providerID: "openai"), Self.match)

        defaults.set(false, forKey: SecretCheck.settingKey)
        XCTAssertFalse(check.isOn())
        XCTAssertNil(check.match(in: Self.flagged, providerID: "openai"))
    }

    /// Attaching sets the typed text aside, so only the image is sent.
    func testImageAloneIsNotChecked() throws {
        var preset = try XCTUnwrap(presetStore.presets.first)
        preset.supportsVision = true
        try presetStore.update(preset)
        let vm = makeViewModel()
        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        vm.inputText = Self.flagged
        vm.attachImage(image, source: .paste)
        XCTAssertNotNil(vm.attachedImage)

        vm.translate()

        if case .secretFound = vm.state { XCTFail("an image is sent without a check") }
    }

    // MARK: The card

    func testTranslateAgainOnTheCardSendsNothing() throws {
        let vm = try flaggedViewModel()

        vm.translate()
        XCTAssertFalse(vm.translateAgainIfShown())

        XCTAssertFalse(wasSent)
        if case .secretFound = vm.state {} else { XCTFail("the card stays") }
    }

    func testSendAnywaySendsThatTextUnchanged() async throws {
        let vm = try flaggedViewModel()

        vm.sendAnyway()

        try await waitUntil({ vm.state == .done(result: "bonjour") })
        XCTAssertTrue(String(describing: provider.capturedMessages).contains(Self.token))
    }

    func testSendAnywayDoesNothingWithoutACard() {
        let vm = makeViewModel()
        vm.inputText = Self.flagged

        vm.sendAnyway()

        XCTAssertFalse(wasSent)
        XCTAssertEqual(vm.state, .idle)
    }

    func testBackToTextKeepsTheText() throws {
        let vm = try flaggedViewModel()

        vm.dismissError()

        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.inputText, Self.flagged)
    }

    // MARK: How long Send anyway lasts

    private func sentAnywayThenFailed() async throws -> PopupViewModel {
        provider.scriptedEvents = []
        provider.scriptedError = LLMError.network("down")
        let vm = try flaggedViewModel()
        vm.sendAnyway()
        try await waitUntil({ if case .error = vm.state { return true } else { return false } })
        provider.capturedMessages = []
        provider.scriptedError = nil
        provider.scriptedEvents = [.textDelta("bonjour")]
        return vm
    }

    func testRetryOfTheSameTextDoesNotAskAgain() async throws {
        let vm = try await sentAnywayThenFailed()

        vm.translate()

        try await waitUntil({ vm.state == .done(result: "bonjour") })
    }

    func testEditingTheTextAndBackAsksAgain() async throws {
        let vm = try await sentAnywayThenFailed()

        vm.inputText = Self.flagged + "!"
        vm.inputText = Self.flagged
        vm.translate()

        XCTAssertFalse(wasSent)
        if case .secretFound = vm.state {} else { XCTFail("asks again") }
    }

    func testSwitchingPresetAsksAgain() async throws {
        let vm = try await sentAnywayThenFailed()
        let other = try XCTUnwrap(presetStore.presets.first { $0.id != vm.selectedPresetID })

        vm.switchPreset(other.id)
        vm.translate()

        XCTAssertFalse(wasSent)
        if case .secretFound = vm.state {} else { XCTFail("asks again") }
    }

    func testHidingThePopupAsksAgain() async throws {
        let vm = try await sentAnywayThenFailed()

        vm.popupDidHide()
        vm.inputText = Self.flagged
        vm.translate()

        XCTAssertFalse(wasSent)
        if case .secretFound = vm.state {} else { XCTFail("asks again") }
    }

    // MARK: History

    func testOrdinaryTranslationIsRecorded() async throws {
        let history = try HistoryStore(inMemory: true)
        let vm = makeViewModel()
        vm.historyStore = history
        vm.inputText = "hello"

        vm.translate()

        try await waitUntil({ (try? history.allEntries().count) == 1 })
    }

    func testSentAnywayTranslationIsNotRecorded() async throws {
        let history = try HistoryStore(inMemory: true)
        let vm = try flaggedViewModel()
        vm.historyStore = history

        vm.sendAnyway()
        try await waitUntil({ vm.state == .done(result: "bonjour") })
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(try history.allEntries().count, 0)
    }

    func testSentAnywayIsNotRecordedWhenThePopupHidesWhileItStreams() async throws {
        let history = try HistoryStore(inMemory: true)
        let vm = try flaggedViewModel()
        vm.historyStore = history

        vm.sendAnyway()
        vm.popupDidHide()
        try await waitUntil({ vm.state == .done(result: "bonjour") })
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(try history.allEntries().count, 0)
    }

    // MARK: Draft

    func testHidingWithTheCardShowingDropsTheText() throws {
        let vm = try flaggedViewModel()

        vm.popupDidHide()

        XCTAssertEqual(vm.inputText, "")
        XCTAssertEqual(vm.state, .idle)
    }

    func testHidingWhileEditingAFlaggedTextDropsIt() throws {
        let vm = try flaggedViewModel()
        vm.dismissError()

        vm.popupDidHide()

        XCTAssertEqual(vm.inputText, "")
    }

    func testHidingAfterSendAnywayKeepsTheDraft() async throws {
        let vm = try flaggedViewModel()
        vm.sendAnyway()
        try await waitUntil({ vm.state == .done(result: "bonjour") })

        vm.popupDidHide()

        XCTAssertEqual(vm.inputText, Self.flagged)
        XCTAssertEqual(vm.state, .done(result: "bonjour"))
    }

    func testHidingOrdinaryTextKeepsIt() {
        let vm = makeViewModel()
        vm.inputText = "hello"

        vm.popupDidHide()

        XCTAssertEqual(vm.inputText, "hello")
    }

    // MARK: Translate Selection

    func testSelectionWithASecretOpensTheCardAndSendsNothing() throws {
        let vm = makeViewModel()
        var bannerFailures = 0
        vm.onOutputOnlyFailure = { _ in bannerFailures += 1 }

        vm.startQuickTranslation(text: Self.flagged, presetID: try XCTUnwrap(vm.selectedPresetID))

        XCTAssertTrue(vm.isOutputOnly)
        if case .secretFound = vm.state {} else { XCTFail("the card shows") }
        XCTAssertFalse(wasSent)
        XCTAssertEqual(bannerFailures, 0, "a card, not the banner")
    }

    func testShowTextOnTheCardShowsTheEditorWithTheSelection() throws {
        let vm = makeViewModel()
        vm.startQuickTranslation(text: Self.flagged, presetID: try XCTUnwrap(vm.selectedPresetID))

        vm.showInput()

        XCTAssertFalse(vm.isOutputOnly)
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.inputText, Self.flagged)
    }

    func testSendAnywayFromTheOutputOnlyCardTranslates() async throws {
        let vm = makeViewModel()
        vm.startQuickTranslation(text: Self.flagged, presetID: try XCTUnwrap(vm.selectedPresetID))

        vm.sendAnyway()

        try await waitUntil({ vm.state == .done(result: "bonjour") })
        XCTAssertTrue(vm.isOutputOnly)
    }

    func testHidingTheOutputOnlyCardKeepsThePopupsOwnDraft() throws {
        let vm = makeViewModel()
        vm.inputText = "my draft"
        vm.startQuickTranslation(text: Self.flagged, presetID: try XCTUnwrap(vm.selectedPresetID))

        vm.popupDidHide()
        vm.openPopup(keepingDraft: true)

        XCTAssertEqual(vm.inputText, "my draft")
    }

    // MARK: The value never leaves the scanner

    func testStateAndAnnouncementNeverCarryTheValue() throws {
        let vm = try flaggedViewModel()

        XCTAssertFalse(String(describing: vm.state).contains("mmmm"))
        XCTAssertFalse(announcer.messages.joined().contains("mmmm"))
    }
}
