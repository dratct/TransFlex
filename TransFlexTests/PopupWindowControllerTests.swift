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

    private func waitUntil(_ condition: () -> Bool, _ message: String = "") async throws {
        for _ in 0..<200 where !condition() { try await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertTrue(condition(), message)
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

    // MARK: Translate Selection banner

    func testNothingSelectedShowsBannerWithoutPopup() async throws {
        copied = .failure(SelectionCapture.Failure.noSelection)
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.selectionBanner != nil }, "banner shown")
        XCTAssertEqual(selectionBanner?.title, "Nothing selected")
        XCTAssertFalse(controller.isVisible)
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
