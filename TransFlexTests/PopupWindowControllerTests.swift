import XCTest
@testable import TransFlex

/// C-9: opening a TransFlex window hides the Replace failure banner and gives
/// Esc back first, so Esc works inside that window.
@MainActor
final class PopupWindowControllerTests: XCTestCase {
    private var tempDir: URL!
    private var hold: RecordingEscapeHold!
    private var controller: PopupWindowController!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        hold = RecordingEscapeHold()
        controller = PopupWindowController(
            presetStore: PresetStore(fileURL: tempDir.appendingPathComponent("presets.json")),
            escapeHold: hold
        )
    }

    private var hud: ReplaceHUD { controller.replaceHUD }

    private func showFailureBanner() {
        hud.showFailed(message: "Boom.", onOpenPopup: {}, onRetry: {})
    }

    override func tearDown() async throws {
        controller.hide()
        hud.hide()
        try? FileManager.default.removeItem(at: tempDir)
    }

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
}
