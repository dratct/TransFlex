import Carbon.HIToolbox
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
    /// What the fake Replace selection reports: whether Accessibility is
    /// granted, and every text a ⌘V would have pasted.
    private var trusted = true
    private var replaceCopies = 0
    private var pasted: [String] = []

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
            selection: makeSelection(),
            translationService: TranslationService(provider: { _ in provider }, apiKey: { _ in "" }),
            pasteboard: PasteboardHelper(pasteboard: pasteboard),
            defaults: defaults
        )
    }

    /// Replace Selection without real keystrokes: the tests run inside the
    /// app, and the real capture would send ⌘C and ⌘V to whatever is in front.
    private func makeSelection() -> SelectionCapture {
        let board = NSPasteboard(name: .init("PopupWindowControllerTests-replace-\(UUID().uuidString)"))
        addTeardownBlock { board.releaseGlobally() }
        return SelectionCapture(
            pasteboard: board,
            isTrusted: { [unowned self] in trusted },
            modifiersHeld: { false },
            postCommandKey: { [unowned self] key in
                if key == CGKeyCode(kVK_ANSI_C) {
                    replaceCopies += 1
                    board.clearContents()
                    board.setString("hello", forType: .string)
                } else if key == CGKeyCode(kVK_ANSI_V) {
                    pasted.append(board.string(forType: .string) ?? "")
                }
            },
            focus: .none,
            pollInterval: 1_000_000,
            copyTimeout: 30_000_000,
            restoreDelay: 1_000_000,
            pasteConfirmTimeout: 50_000_000
        )
    }

    /// A full Popup with a draft, pinned and moved off its default place.
    private func showPinnedPopup() -> NSRect {
        controller.show()
        controller.viewModelForTesting?.inputText = "draft"
        controller.togglePin()
        let opened = controller.panelFrame
        controller.movePanel(toTopLeft: NSPoint(x: opened.minX + 40, y: opened.maxY - 40))
        return controller.panelFrame
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

    func testPinnedPopupStaysWhenAnotherAppComesForward() {
        controller.show()
        controller.togglePin()

        controller.otherAppCameForward(bundleID: "com.apple.TextEdit")
        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isPinned)

        controller.togglePin()
        controller.otherAppCameForward(bundleID: "com.apple.TextEdit")
        XCTAssertFalse(controller.isVisible, "unpinned, it hides as before")
    }

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
        // The app that was behind Settings comes forward as it closes.
        controller.otherAppCameForward(bundleID: "com.apple.TextEdit")

        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isPinned)
        XCTAssertEqual(controller.panelFrame, moved)
    }

    /// SwiftUI's hosting view takes the mouse-down itself, so the panel's
    /// `isMovableByWindowBackground` never moves the popup.
    func testEmptyHeaderSpaceDragsThePopup() async throws {
        controller.show()
        let width = controller.panelFrame.width

        try await waitUntil({
            self.controller.hitView(atTopLeftOffset: NSPoint(x: width * 0.5, y: 22)) is WindowDragView
        }, "the empty part of the header is a drag area")
    }

    /// The popup rarely holds the keyboard while another app is in front;
    /// without this the first press only focuses the panel and nothing moves.
    func testDragAreaTakesTheFirstClick() {
        XCTAssertTrue(WindowDragView().acceptsFirstMouse(for: nil))
    }

    /// The user pinned the popup to work in another app: Settings closing
    /// must not hand the popup a keyboard it did not have.
    func testSettingsCloseDoesNotAskTheKeyboardForAPinnedPopup() async throws {
        _ = showPinnedPopup()
        let asked = controller.panelKeyRequests

        controller.keepThroughOtherWindowClose()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(controller.isVisible)
        XCTAssertEqual(controller.panelKeyRequests, asked)
    }

    func testSettingsCloseGivesAnUnpinnedPopupTheKeyboardBack() async throws {
        controller.show()
        let asked = controller.panelKeyRequests

        controller.keepThroughOtherWindowClose()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(controller.panelKeyRequests, asked + 1)
    }

    /// A pinned popup is not made key when Settings closes, so the key
    /// check that rides on becoming key has to run on its own.
    func testSettingsCloseClearsTheMissingKeyCardInAPinnedPopup() async throws {
        _ = showPinnedPopup()
        controller.viewModelForTesting?.state = .missingKey(providerID: "mock")

        controller.keepThroughOtherWindowClose()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(controller.viewModelForTesting?.state, .idle)
    }

    /// Welcome's last button opens the Popup; one that is up and pinned
    /// would otherwise be emptied and recentred while still pinned.
    func testOpeningThePopupAgainEndsThePin() {
        _ = showPinnedPopup()

        controller.show()

        XCTAssertFalse(controller.isPinned)
    }

    // MARK: Secret check

    private static let flagged = "deploy with \(SecretScannerTests.githubToken) today"

    private func isSecretCard(_ state: PopupState?) -> Bool {
        if case .secretFound = state { return true }
        return false
    }

    func testFlaggedTextIsNotKeptAsDraftWhenThePopupHides() {
        controller.show()
        controller.viewModelForTesting?.inputText = Self.flagged
        controller.viewModelForTesting?.translate()
        XCTAssertTrue(isSecretCard(controller.viewModelForTesting?.state))

        controller.hide()
        controller.show()

        XCTAssertEqual(controller.viewModelForTesting?.inputText, "")
        XCTAssertEqual(controller.viewModelForTesting?.state, .idle)
    }

    func testFlaggedTextBeingEditedIsNotKeptEither() {
        controller.show()
        controller.viewModelForTesting?.inputText = Self.flagged
        controller.viewModelForTesting?.translate()
        controller.viewModelForTesting?.dismissError()

        controller.hide()
        controller.show()

        XCTAssertEqual(controller.viewModelForTesting?.inputText, "")
    }

    func testSendAnywayEndsWhenThePopupHides() async throws {
        provider.scriptedEvents = [.textDelta("xin chào")]
        controller.show()
        controller.viewModelForTesting?.inputText = Self.flagged
        controller.viewModelForTesting?.translate()
        controller.viewModelForTesting?.sendAnyway()
        try await waitUntil({ self.controller.viewModelForTesting?.state == .done(result: "xin chào") })

        controller.hide()
        controller.show()
        XCTAssertEqual(controller.viewModelForTesting?.inputText, Self.flagged, "a text sent anyway is kept like any Draft")

        controller.viewModelForTesting?.translate()
        XCTAssertTrue(isSecretCard(controller.viewModelForTesting?.state), "the next send asks again")
    }

    func testTranslateSelectionWithASecretOpensTheCardAndKeepsThePopupsDraft() async throws {
        controller.show()
        controller.viewModelForTesting?.inputText = "draft"
        controller.hide()
        copied = .success(Self.flagged)

        controller.quickTranslate(presetID: preset.id)

        try await waitUntil({ self.isSecretCard(self.controller.viewModelForTesting?.state) }, "the card shows")
        XCTAssertTrue(controller.isVisible)
        XCTAssertEqual(controller.viewModelForTesting?.isOutputOnly, true)
        XCTAssertNil(selectionBanner)
        XCTAssertTrue(provider.capturedMessages.isEmpty, "nothing was sent")

        controller.hide()
        controller.show()
        XCTAssertEqual(controller.viewModelForTesting?.inputText, "draft")
    }

    /// The card replaces a pinned Popup without hiding it; the Draft's clock
    /// still starts there, or the next open would drop the Draft at once.
    func testDraftSurvivesAPermissionCardShownInThePinnedPopup() {
        _ = showPinnedPopup()
        controller.reportReplaceFailure(SelectionCapture.Failure.accessibilityNotGranted, presetID: preset.id)
        controller.hide()

        controller.show()

        XCTAssertEqual(controller.viewModelForTesting?.inputText, "draft")
    }

    func testPresetShortcutGivesAVisiblePinnedPopupTheKeyboard() {
        let frame = showPinnedPopup()
        let asked = controller.panelKeyRequests

        controller.openForPreset(id: preset.id)

        XCTAssertEqual(controller.panelKeyRequests, asked + 1)
        XCTAssertTrue(controller.isPinned)
        XCTAssertEqual(controller.panelFrame, frame, "a visible popup is not opened again")
        XCTAssertEqual(controller.viewModelForTesting?.inputText, "draft")
    }

    func testPresetShortcutOpensAHiddenPopup() {
        controller.openForPreset(id: preset.id)

        XCTAssertTrue(controller.isVisible)
        XCTAssertEqual(controller.viewModelForTesting?.selectedPresetID, preset.id)
    }

    /// The drag area sits behind the header: its controls keep their clicks.
    func testHeaderControlsAreNotTheDragArea() async throws {
        _ = showPinnedPopup()
        let width = controller.panelFrame.width
        try await waitUntil({
            self.controller.hitView(atTopLeftOffset: NSPoint(x: width * 0.5, y: 24)) is WindowDragView
        }, "the header is laid out")

        // Preset picker, then History, Settings, Pin and Close from the right edge.
        for x in [60, width - 123, width - 93, width - 63, width - 33] {
            let hit = controller.hitView(atTopLeftOffset: NSPoint(x: x, y: 24))
            XCTAssertNotNil(hit, "x=\(x)")
            XCTAssertFalse(hit is WindowDragView, "x=\(x) lands on the drag area")
        }
    }

    func testPinnedPopupGrowsFromWhereItWasMoved() async throws {
        provider.scriptedEvents = [.textDelta("xin chào"), .stop(reason: .complete)]
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.controller.viewModelForTesting?.state == .done(result: "xin chào") }, "translation done")
        controller.togglePin()
        let opened = controller.panelFrame
        controller.movePanel(toTopLeft: NSPoint(x: opened.minX - 30, y: opened.maxY - 30))
        let moved = controller.panelFrame

        // Sent on every poll: the view's own late measurement may overwrite one report.
        try await waitUntil({
            self.controller.viewModelForTesting?.reportOutputHeight(content: 300, visible: 20, from: .translationColumn)
            return self.controller.panelFrame.height > moved.height + 1
        }, "the popup grows with its content")
        XCTAssertEqual(controller.panelFrame.minX, moved.minX)
        XCTAssertEqual(controller.panelFrame.maxY, moved.maxY)
        XCTAssertTrue(controller.isPinned)
    }

    func testShowInputWhilePinnedKeepsTopLeft() async throws {
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.controller.isVisible }, "the Output-only popup is shown")
        controller.togglePin()
        // Near the screen's top-left corner, where the Popup fits at any screen size.
        let opened = controller.panelFrame
        let visible = try XCTUnwrap(NSScreen.screens.first { $0.frame.intersects(opened) }).visibleFrame
        controller.movePanel(toTopLeft: NSPoint(x: visible.minX + 20, y: visible.maxY - 20))
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

    // MARK: Shortcuts while pinned

    func testPinnedTranslateSelectionIsRefusedWithABanner() async throws {
        let frame = showPinnedPopup()

        controller.quickTranslate(presetID: preset.id)

        XCTAssertEqual(selectionBanner?.title, "The popup is pinned")
        XCTAssertEqual(selectionBanner?.message, "Unpin it to translate a new selection.")
        XCTAssertEqual(selectionBanner?.canRetry, false)
        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isPinned)
        XCTAssertEqual(controller.panelFrame, frame)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(copyCount, 0, "nothing is copied from the other app")
        XCTAssertEqual(controller.viewModelForTesting?.state, .idle)
        XCTAssertEqual(controller.viewModelForTesting?.inputText, "draft")
    }

    func testPinnedOutputOnlyPopupRefusesTranslateSelectionToo() async throws {
        provider.scriptedEvents = [.textDelta("xin chào"), .stop(reason: .complete)]
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.controller.viewModelForTesting?.state == .done(result: "xin chào") }, "first translation done")
        controller.togglePin()

        controller.quickTranslate(presetID: preset.id)

        XCTAssertEqual(selectionBanner?.title, "The popup is pinned")
        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isPinned)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(copyCount, 1, "only the first press copied")
        XCTAssertEqual(controller.viewModelForTesting?.state, .done(result: "xin chào"))
    }

    func testTranslateSelectionStillRunsOverAnUnpinnedPopup() async throws {
        controller.show()

        controller.quickTranslate(presetID: preset.id)

        try await waitUntil({ self.copyCount == 1 }, "the selection is copied")
        XCTAssertNil(selectionBanner)
    }

    func testPinnedTranslateSelectionDuringAReplaceRunKeepsItsCapsule() async throws {
        _ = showPinnedPopup()
        hud.showTranslating(presetName: "EN") {}

        controller.quickTranslate(presetID: preset.id)

        XCTAssertTrue(hud.isRunning, "the banner would take the capsule's place")
        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isPinned)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(copyCount, 0)
    }

    func testPinnedReplaceKeepsThePopup() async throws {
        provider.scriptedEvents = [.textDelta("xin chào"), .stop(reason: .complete)]
        let frame = showPinnedPopup()

        controller.quickReplace(presetID: preset.id)

        XCTAssertTrue(controller.isVisible, "Replace does not hide a pinned popup")
        try await waitUntil({ self.pasted == ["xin chào"] }, "the translation is pasted")
        XCTAssertEqual(replaceCopies, 1)
        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isPinned)
        XCTAssertEqual(controller.panelFrame, frame)
        XCTAssertEqual(controller.viewModelForTesting?.state, .idle)
        XCTAssertEqual(controller.viewModelForTesting?.inputText, "draft")
    }

    /// While the pinned popup holds the keyboard, the ⌘C meant for the other
    /// app would land in it.
    func testPinnedReplaceTakesTheKeyboardFromThePopup() async throws {
        provider.scriptedEvents = [.textDelta("xin chào"), .stop(reason: .complete)]
        _ = showPinnedPopup()
        try XCTSkipUnless(controller.isPanelKey, "the test host did not make the popup key")

        controller.quickReplace(presetID: preset.id)

        XCTAssertFalse(controller.isPanelKey)
        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isPinned)
        try await waitUntil({ self.pasted == ["xin chào"] }, "the run finishes")
    }

    func testReplaceStillHidesAnUnpinnedPopup() async throws {
        provider.scriptedEvents = [.textDelta("xin chào"), .stop(reason: .complete)]
        controller.show()

        controller.quickReplace(presetID: preset.id)

        XCTAssertFalse(controller.isVisible)
        try await waitUntil({ self.pasted == ["xin chào"] }, "the run finishes")
    }

    func testPinnedReplaceFailureUsesTheBanner() {
        let frame = showPinnedPopup()

        controller.reportReplaceFailure(LLMError.server(status: 503, body: ""), presetID: preset.id)

        XCTAssertTrue(hud.isShowing, "the pinned translation is not replaced by the error")
        XCTAssertTrue(hold.isHeld)
        XCTAssertTrue(controller.isPinned)
        XCTAssertEqual(controller.panelFrame, frame)
        XCTAssertEqual(controller.viewModelForTesting?.state, .idle)
        XCTAssertEqual(controller.viewModelForTesting?.inputText, "draft")
    }

    func testPinnedPermissionCardKeepsThePinAndTopLeft() {
        let frame = showPinnedPopup()

        controller.reportReplaceFailure(SelectionCapture.Failure.accessibilityNotGranted, presetID: preset.id)

        XCTAssertEqual(controller.viewModelForTesting?.state, .accessibilityRequired(granted: false))
        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isPinned)
        XCTAssertEqual(controller.panelFrame.minX, frame.minX)
        XCTAssertEqual(controller.panelFrame.maxY, frame.maxY)
    }

    func testOpenPopupFromTheReplaceBannerShowsTheErrorInThePinnedPopup() throws {
        let frame = showPinnedPopup()
        controller.reportReplaceFailure(LLMError.server(status: 503, body: ""), presetID: preset.id)

        hud.model.onOpenPopup()

        guard case .error = try XCTUnwrap(controller.viewModelForTesting?.state) else {
            return XCTFail("the error shows in the popup: \(String(describing: controller.viewModelForTesting?.state))")
        }
        XCTAssertFalse(hud.isShowing)
        XCTAssertTrue(controller.isPinned)
        XCTAssertEqual(controller.panelFrame.minX, frame.minX)
        XCTAssertEqual(controller.panelFrame.maxY, frame.maxY)
    }

    func testPinnedStreamFailureStaysInThePopup() async throws {
        provider.scriptedEvents = [.textDelta("xin chào"), .stop(reason: .complete)]
        controller.quickTranslate(presetID: preset.id)
        try await waitUntil({ self.controller.viewModelForTesting?.state == .done(result: "xin chào") }, "first translation done")
        controller.togglePin()
        provider.scriptedEvents = []
        provider.scriptedError = LLMError.server(status: 503, body: "")

        controller.viewModelForTesting?.translate()

        try await waitUntil({
            if case .error(_, nil) = self.controller.viewModelForTesting?.state { return true }
            return false
        }, "the error card with Retry is in the popup")
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(controller.isVisible)
        XCTAssertTrue(controller.isPinned)
        XCTAssertEqual(controller.viewModelForTesting?.inputText, "hello")
        XCTAssertNil(selectionBanner)
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
