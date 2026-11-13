import XCTest
@testable import TransFlex

/// DESIGN.md › Replace Selection: the banner says that nothing was changed,
/// and the capsule stays on the pointer's screen.
@MainActor
final class ReplaceHUDTests: XCTestCase {
    func testFailureSaysTheTextWasLeftAlone() {
        XCTAssertEqual(
            ReplaceHUD.failureMessage(for: QuickReplaceCoordinator.EmptyResult()),
            "The provider returned nothing. Your text was left as it was."
        )
        XCTAssertTrue(ReplaceHUD.failureMessage(for: LLMError.auth).hasSuffix(" Nothing was changed."))
    }

    func testIgnoredOrLostPasteSaysTheTranslationIsOnTheClipboard() {
        for failure in [SelectionCapture.Failure.pasteNotApplied, .targetLost] {
            let message = ReplaceHUD.failureMessage(for: failure)
            XCTAssertTrue(message.contains("on the clipboard"), message)
            XCTAssertFalse(message.contains("Nothing was changed"), message)
        }
    }

    func testCapsuleSitsDownAndRightOfThePointer() throws {
        let screen = try XCTUnwrap(NSScreen.main).visibleFrame
        let point = NSPoint(x: screen.midX, y: screen.midY)
        let frame = ReplaceHUD.frame(size: NSSize(width: 200, height: 30), besidePointer: point)
        XCTAssertEqual(frame.minX, point.x + 14)
        XCTAssertEqual(frame.maxY, point.y - 14)
    }

    func testCapsuleNeverLeavesTheScreen() throws {
        let screen = try XCTUnwrap(NSScreen.main).visibleFrame
        let corner = NSPoint(x: screen.maxX - 1, y: screen.minY + 1)
        let frame = ReplaceHUD.frame(size: NSSize(width: 200, height: 30), besidePointer: corner)
        XCTAssertTrue(screen.contains(frame), "\(frame) outside \(screen)")
    }

    // MARK: - Secret check banner

    private static let match = SecretMatch(kind: "GitHub token", masked: "ghp_…9xQ2")

    private func secretHUD(_ hold: RecordingEscapeHold, sendAnyway: @escaping () -> Void = {}, dismiss: @escaping () -> Void = {}) -> ReplaceHUD {
        let hud = ReplaceHUD(escapeHold: hold)
        hud.showSecretFound(Self.match, providerName: "OpenAI", onSendAnyway: sendAnyway, onDismiss: dismiss)
        addTeardownBlock { hud.hide() }
        return hud
    }

    func testSecretBannerSaysWhatWasFoundAndThatItWasNotSent() {
        XCTAssertEqual(
            ReplaceHUD.secretMessage(for: Self.match, providerName: "OpenAI"),
            "ghp_…9xQ2 · Not sent to OpenAI. Your text was left as it was."
        )
        XCTAssertEqual(
            ReplaceHUD.secretMessage(for: SecretMatch(kind: "Private key", masked: ""), providerName: "OpenAI"),
            "Not sent to OpenAI. Your text was left as it was."
        )
    }

    func testSecretBannerHoldsEscapeAndStaysUntilClosed() {
        let hold = RecordingEscapeHold()
        let hud = secretHUD(hold)
        XCTAssertTrue(hud.isShowing)
        XCTAssertTrue(hold.isHeld)
        XCTAssertEqual(hud.model.phase, .secretFound(Self.match, providerName: "OpenAI"))
    }

    func testEscapeClosesSecretBannerReleasesAndDropsTheSelection() {
        let hold = RecordingEscapeHold()
        var dismissed = 0
        let hud = secretHUD(hold, dismiss: { dismissed += 1 })

        hold.press()

        XCTAssertFalse(hud.isShowing)
        XCTAssertFalse(hold.isHeld)
        XCTAssertEqual(dismissed, 1)
    }

    func testCloseButtonAndHideBannerDropTheSelectionToo() {
        var dismissed = 0
        let first = secretHUD(RecordingEscapeHold(), dismiss: { dismissed += 1 })
        first.model.onClose()
        let second = secretHUD(RecordingEscapeHold(), dismiss: { dismissed += 1 })
        second.hideBanner()

        XCTAssertFalse(first.isShowing)
        XCTAssertFalse(second.isShowing)
        XCTAssertEqual(dismissed, 2)
    }

    func testSendAnywayReleasesEscapeFirstAndDoesNotCountAsDismissed() {
        let hold = RecordingEscapeHold()
        var dismissed = 0
        var heldWhenSent: Bool?
        let hud = secretHUD(hold, sendAnyway: { heldWhenSent = hold.isHeld }, dismiss: { dismissed += 1 })

        hud.model.onSendAnyway()

        XCTAssertEqual(heldWhenSent, false, "the resumed run takes its own hold")
        XCTAssertFalse(hud.isShowing)
        XCTAssertEqual(dismissed, 0)
    }

    // MARK: - Esc while the failure banner shows

    private func failedHUD(_ hold: RecordingEscapeHold, openPopup: @escaping () -> Void = {}, retry: @escaping () -> Void = {}) -> ReplaceHUD {
        let hud = ReplaceHUD(escapeHold: hold)
        hud.showFailed(message: "Boom.", onOpenPopup: openPopup, onRetry: retry)
        addTeardownBlock { hud.hide() }
        XCTAssertTrue(hold.isHeld, "precondition: the failure banner holds Esc")
        return hud
    }

    func testFailureBannerHoldsEscape() {
        let hold = RecordingEscapeHold()
        let hud = failedHUD(hold)
        XCTAssertTrue(hud.isShowing)
        XCTAssertTrue(hold.isHeld)
    }

    func testEscapeClosesBannerAndReleases() {
        let hold = RecordingEscapeHold()
        let hud = failedHUD(hold)
        hold.press()
        XCTAssertFalse(hud.isShowing)
        XCTAssertFalse(hold.isHeld)
    }

    func testCloseButtonReleases() {
        let hold = RecordingEscapeHold()
        let hud = failedHUD(hold)
        hud.model.onClose()
        XCTAssertFalse(hud.isShowing)
        XCTAssertFalse(hold.isHeld)
    }

    func testRetryReleases() {
        let hold = RecordingEscapeHold()
        var retried = false
        let hud = failedHUD(hold, retry: { retried = true })
        hud.model.onRetry()
        XCTAssertTrue(retried)
        XCTAssertFalse(hud.isShowing)
        XCTAssertFalse(hold.isHeld)
    }

    func testOpenPopupReleases() {
        let hold = RecordingEscapeHold()
        var opened = false
        let hud = failedHUD(hold, openPopup: { opened = true })
        hud.model.onOpenPopup()
        XCTAssertTrue(opened)
        XCTAssertFalse(hud.isShowing)
        XCTAssertFalse(hold.isHeld)
    }

    func testHideWhileRunHoldsDoesNotReleaseRunHold() {
        let hold = RecordingEscapeHold()
        let hud = ReplaceHUD(escapeHold: hold)
        addTeardownBlock { hud.hide() }
        hud.showTranslating(presetName: "EN") {}
        hold.hold {}  // the run's own hold
        hud.hide()
        XCTAssertTrue(hold.isHeld)
        XCTAssertEqual(hold.log, ["hold"])
    }

    func testNewRunReleasesBannerHoldFirst() {
        let hold = RecordingEscapeHold()
        let hud = failedHUD(hold)
        hud.showTranslating(presetName: "EN") {}
        XCTAssertFalse(hold.isHeld)
        XCTAssertEqual(hold.log, ["hold", "release"])
    }

    func testHideBannerLeavesARunningCapsule() {
        let hold = RecordingEscapeHold()
        let hud = ReplaceHUD(escapeHold: hold)
        addTeardownBlock { hud.hide() }
        hud.showTranslating(presetName: "EN") {}
        hud.hideBanner()
        XCTAssertTrue(hud.isShowing)
    }

    // MARK: - Translate Selection banner

    private final class ManualScheduler {
        var pending: [(seconds: TimeInterval, work: () -> Void, cancelled: Bool)] = []
        var live: [Int] { pending.indices.filter { !pending[$0].cancelled } }

        var scheduler: ReplaceHUD.Scheduler {
            { [unowned self] seconds, work in
                pending.append((seconds, work, false))
                let index = pending.count - 1
                return { [unowned self] in pending[index].cancelled = true }
            }
        }

        func fireLive() { for i in live { pending[i].work() } }
    }

    private let nothingSelected = SelectionBanner(title: "Nothing selected", message: "Select some text first.", canRetry: false)

    func testSelectionBannerDoesNotHoldEscape() {
        let hold = RecordingEscapeHold()
        let hud = ReplaceHUD(escapeHold: hold)
        addTeardownBlock { hud.hide() }
        hud.showSelectionFailed(nothingSelected) {}
        XCTAssertTrue(hud.isShowing)
        XCTAssertEqual(hud.model.phase, .selectionFailed(nothingSelected))
        XCTAssertEqual(hold.log, [])
    }

    func testSelectionBannerHidesAfterTimeout() {
        let clock = ManualScheduler()
        let hud = ReplaceHUD(escapeHold: RecordingEscapeHold(), scheduler: clock.scheduler)
        addTeardownBlock { hud.hide() }
        hud.showSelectionFailed(nothingSelected) {}
        XCTAssertEqual(clock.live.map { clock.pending[$0].seconds }, [ReplaceHUD.selectionBannerDuration])
        clock.fireLive()
        XCTAssertFalse(hud.isShowing)
    }

    func testHoverPausesAndExitRestartsTimer() {
        let clock = ManualScheduler()
        let hud = ReplaceHUD(escapeHold: RecordingEscapeHold(), scheduler: clock.scheduler)
        addTeardownBlock { hud.hide() }
        hud.showSelectionFailed(nothingSelected) {}
        hud.model.onHover(true)
        XCTAssertTrue(clock.live.isEmpty, "the pointer on the banner stops the countdown")
        hud.model.onHover(false)
        XCTAssertEqual(clock.live.map { clock.pending[$0].seconds }, [ReplaceHUD.selectionBannerDuration])
        clock.fireLive()
        XCTAssertFalse(hud.isShowing)
    }

    func testSelectionRetryHidesAndRetries() {
        let hud = ReplaceHUD(escapeHold: RecordingEscapeHold())
        addTeardownBlock { hud.hide() }
        var retried = false
        hud.showSelectionFailed(SelectionBanner(title: "You're offline", message: "x", canRetry: true)) { retried = true }
        hud.model.onRetry()
        XCTAssertTrue(retried)
        XCTAssertFalse(hud.isShowing)
    }

    func testStaleHoverDoesNotHideANewRun() {
        let clock = ManualScheduler()
        let hud = ReplaceHUD(escapeHold: RecordingEscapeHold(), scheduler: clock.scheduler)
        addTeardownBlock { hud.hide() }
        hud.showSelectionFailed(nothingSelected) {}
        hud.showTranslating(presetName: "EN") {}
        hud.model.onHover(false)
        clock.fireLive()
        XCTAssertEqual(hud.model.phase, .translating(presetName: "EN"))
        XCTAssertTrue(hud.isShowing)
    }

    func testFailureMessageNamesTheProvider() {
        XCTAssertEqual(
            ReplaceHUD.failureMessage(for: LLMError.server(status: 503, body: ""), providerName: "Gemini"),
            "Gemini is having trouble. Try again in a moment. Nothing was changed."
        )
    }
}
