import XCTest
@testable import TransFlex

/// Opening a TransFlex window hides the Replace failure banner and gives Esc
/// back first; a Translate Selection failure shows a banner, not the popup.
@MainActor
final class PopupWindowControllerTests: XCTestCase {
    private var tempDir: URL!
    private var hold: RecordingEscapeHold!
    private var provider: MockLLMProvider!
    private var preset: Preset!
    private var copied: Result<String, Error> = .success("hello")
    private var copyCount = 0
    private var controller: PopupWindowController!
    private var pasteboard: NSPasteboard!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        hold = RecordingEscapeHold()
        provider = MockLLMProvider()
        let provider = provider!
        let store = PresetStore(fileURL: tempDir.appendingPathComponent("presets.json"))
        preset = Preset(name: "Mock", providerID: "mock", modelID: "m1", systemPrompt: "Translate.")
        try store.add(preset)
        pasteboard = NSPasteboard(name: .init("PopupWindowControllerTests-\(UUID().uuidString)"))
        // A fixed name: a fresh one per run leaves an empty plist behind each time.
        let suite = "io.aiaz.transflex.tests.PopupWindowController"
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: PopupViewModel.copyResultAutomaticallyKey)
        controller = PopupWindowController(
            presetStore: store,
            escapeHold: hold,
            copySelection: { [unowned self] in
                copyCount += 1
                return try copied.get()
            },
            translationService: TranslationService(provider: { _ in provider }, apiKey: { _ in "" }),
            pasteboard: PasteboardHelper(pasteboard: pasteboard),
            defaults: defaults
        )
    }

    override func tearDown() async throws {
        controller.hide()
        hud.hide()
        try? FileManager.default.removeItem(at: tempDir)
    }

    private var hud: ReplaceHUD { controller.replaceHUD }

    private func showFailureBanner() {
        hud.showFailed(message: "Boom.", onOpenPopup: {}, onRetry: {})
    }

    private var selectionBanner: SelectionBanner? {
        if case .selectionFailed(let banner) = hud.model.phase, hud.isShowing { return banner }
        return nil
    }

    // MARK: Replace banner and Esc

    func testShowingPopupHidesBannerAndReleases() {
        showFailureBanner()
        XCTAssertTrue(hold.isHeld, "the controller's banner uses the shared hold")
        controller.show()
        XCTAssertFalse(hud.isShowing)
        XCTAssertFalse(hold.isHeld)
    }

    func testHideReplaceBannerReleases() {
        showFailureBanner()
        XCTAssertTrue(hold.isHeld)
        controller.hideReplaceBanner()
        XCTAssertFalse(hud.isShowing)
        XCTAssertFalse(hold.isHeld)
    }

    func testShowingPopupDuringARunKeepsItsCapsule() {
        hud.showTranslating(presetName: "EN") {}
        controller.show()
        XCTAssertTrue(hud.isShowing)
    }

    func testFailureWhilePopupIsOpenGoesToThePopup() {
        controller.show()
        controller.reportReplaceFailure(LLMError.server(status: 503, body: ""), presetID: UUID())
        XCTAssertFalse(hud.isShowing)
        XCTAssertFalse(hold.isHeld)
    }

    // MARK: Pin

    func testHidingUnpins() {
        controller.show()
        controller.togglePin()
        XCTAssertTrue(controller.isPinned)

        controller.hide()

        XCTAssertFalse(controller.isPinned, "a pin lasts one open")
    }

    func testToggleWhilePinnedClosesAndUnpins() {
        controller.show()
        controller.togglePin()

        controller.toggle()

        XCTAssertFalse(controller.isVisible)
        XCTAssertFalse(controller.isPinned)
    }

    func testNextOpenAfterAPinIsUnpinnedAtTheDefaultFrame() {
        controller.show(at: NSPoint(x: 200, y: 200))
        let defaultFrame = controller.panelFrame
        controller.togglePin()
        controller.movePanel(toTopLeft: NSPoint(x: defaultFrame.minX + 40, y: defaultFrame.maxY - 40))
        XCTAssertNotEqual(controller.panelFrame, defaultFrame)

        controller.hide()
        controller.show(at: NSPoint(x: 200, y: 200))

        XCTAssertFalse(controller.isPinned)
        XCTAssertEqual(controller.panelFrame, defaultFrame)
    }

    func testPinSurvivesSettingsClose() async throws {
        controller.show()
        controller.togglePin()
        controller.movePanel(toTopLeft: NSPoint(x: controller.panelFrame.minX + 40, y: controller.panelFrame.maxY - 40))
        let moved = controller.panelFrame

        controller.keepThroughOtherWindowClose()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isPinned)
        XCTAssertEqual(controller.panelFrame, moved)
    }

    func testShowInputWhilePinnedKeepsTopLeft() async throws {
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.controller.isVisible }, "the Output-only popup is shown")
        controller.togglePin()
        let opened = controller.panelFrame
        controller.movePanel(toTopLeft: NSPoint(x: opened.minX - 40, y: opened.maxY - 40))
        let moved = controller.panelFrame

        controller.viewModelForTesting?.showInput()

        let frame = controller.panelFrame
        XCTAssertGreaterThan(frame.height, moved.height, "the Popup is taller than the Output-only popup")
        XCTAssertEqual(frame.minX, moved.minX)
        XCTAssertEqual(frame.maxY, moved.maxY)
        XCTAssertTrue(controller.isPinned)
    }

    func testTranslateAgainUnpinsAndRecentres() {
        controller.show()
        let defaultFrame = controller.panelFrame
        controller.togglePin()
        controller.movePanel(toTopLeft: NSPoint(x: defaultFrame.minX + 40, y: defaultFrame.maxY - 40))

        controller.translateAgain(text: "hello", presetID: preset.id)

        XCTAssertTrue(controller.isVisible)
        XCTAssertFalse(controller.isPinned)
        XCTAssertEqual(controller.panelFrame, defaultFrame)
    }

    // MARK: Translate Selection banner

    func testNothingSelectedShowsBannerWithoutPopup() async throws {
        copied = .failure(SelectionCapture.Failure.noSelection)
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.selectionBanner != nil }, "banner shown")
        XCTAssertEqual(selectionBanner?.title, "Nothing selected")
        XCTAssertFalse(controller.isVisible)
    }

    func testPermissionCardGrowsThePopupToFit() async throws {
        copied = .failure(SelectionCapture.Failure.accessibilityNotGranted)
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.controller.isVisible }, "the card uses the popup")
        try await waitUntil(
            { self.controller.panelFrame.height > PopupFrame.outputOnlyMinHeight + 1 },
            "the popup grows to show the whole card, not a scroll view"
        )
    }

    func testStreamErrorBeforeTextHidesPopupAndShowsBanner() async throws {
        provider.scriptedError = LLMError.server(status: 503, body: "")
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.selectionBanner != nil }, "banner shown")
        XCTAssertEqual(selectionBanner?.title, "mock is having trouble")
        XCTAssertFalse(controller.isVisible)
    }

    func testSelectionRetryReusesCopiedText() async throws {
        provider.scriptedError = LLMError.offline
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.selectionBanner != nil }, "banner shown")
        provider.capturedMessages = []
        provider.scriptedError = nil
        provider.scriptedEvents = [.textDelta("xin chào"), .stop(reason: .complete)]

        hud.model.onRetry()

        try await waitUntil({ !self.provider.capturedMessages.isEmpty }, "retry translated again")
        XCTAssertEqual(copyCount, 1, "retry must not copy again: the user is elsewhere by now")
        XCTAssertTrue(provider.capturedMessages.contains { "\($0)".contains("hello") }, "\(provider.capturedMessages)")
        XCTAssertTrue(controller.isVisible)
        try await waitUntil({ self.pasteboard.string(forType: .string) == "xin chào" }, "auto-copy reaches the test's own pasteboard")
    }

    func testTranslateSelectionReleasesReplaceBannerHold() {
        showFailureBanner()
        controller.quickTranslate(presetID: preset.id)
        XCTAssertFalse(hold.isHeld)
        XCTAssertFalse(hud.isShowing)
    }

    func testSelectionFailureDuringAReplaceRunKeepsItsCapsule() async throws {
        hud.showTranslating(presetName: "EN") {}
        copied = .failure(SelectionCapture.Failure.noSelection)
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.controller.isVisible }, "the failure goes to the popup")
        XCTAssertEqual(hud.model.phase, .translating(presetName: "EN"))
        XCTAssertTrue(hud.isShowing)
    }
}
