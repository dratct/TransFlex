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

    // MARK: - Esc while the failure banner shows (C-9)

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
}
