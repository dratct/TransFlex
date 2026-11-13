import XCTest
@testable import TransFlex

/// DESIGN.md › Popup states: which buttons each state shows.
final class PopupFooterTests: XCTestCase {
    private func actions(_ state: PopupState, outputOnly: Bool = false, wide: Bool = true) -> [PopupFooter.Action] {
        PopupFooter.items(for: state, isOutputOnly: outputOnly, isWide: wide).map(\.action)
    }

    private func primaries(_ state: PopupState, outputOnly: Bool = false) -> [PopupFooter.Action] {
        PopupFooter.items(for: state, isOutputOnly: outputOnly)
            .filter { $0.prominence == .primary }
            .map(\.action)
    }

    func testPopupStateTable() {
        XCTAssertEqual(actions(.idle), [.translate])
        XCTAssertEqual(actions(.streaming(accumulated: "Xin")), [.stop])
        XCTAssertEqual(actions(.done(result: "Xin chào")), [.new, .translateAgain, .copyAndClose])
        XCTAssertEqual(actions(.error(message: "x", partial: "Xin")), [.new])
        XCTAssertEqual(actions(.error(message: "x", partial: nil)), [.backToText])
        XCTAssertEqual(actions(.missingKey(providerID: "openai")), [.backToText])
        XCTAssertEqual(actions(Self.secretFound), [.sendAnyway, .backToText])
    }

    private static let secretFound = PopupState.secretFound(
        SecretMatch(kind: "GitHub token", masked: "ghp_…9xQ2"), providerID: "openai"
    )

    /// The Output-only popup has no text on screen to go back to, so showing
    /// it takes the filled button there.
    func testSecretCardInOutputOnlyPopupOffersShowTextFirst() {
        XCTAssertEqual(actions(Self.secretFound, outputOnly: true), [.sendAnyway, .showText])
        XCTAssertEqual(primaries(Self.secretFound, outputOnly: true), [.showText])
    }

    /// Going back is the safe choice, so it is the filled button; ⌘↩ belongs
    /// to neither, so a habitual second press sends nothing.
    func testSecretCardMakesBackToTextPrimaryAndKeepsSendAnywayOffCommandReturn() {
        XCTAssertEqual(primaries(Self.secretFound), [.backToText])
        XCTAssertEqual(PopupFooter.Action.sendAnyway.title, "Send anyway")
        XCTAssertEqual(PopupFooter.Action.sendAnyway.keys, ["⌘", "⇧", "↩"])
    }

    func testOnePrimaryPerStateWhereTheFooterHasOne() {
        XCTAssertEqual(primaries(.idle), [.translate])
        XCTAssertEqual(primaries(.done(result: "a")), [.copyAndClose])
        XCTAssertEqual(primaries(.done(result: "a"), outputOnly: true), [.copyAndClose])
        // Stop has nothing to confirm; the notice card and strip carry their own primary.
        XCTAssertEqual(primaries(.streaming(accumulated: "")), [])
        XCTAssertEqual(primaries(.error(message: "x", partial: nil)), [])
        XCTAssertEqual(
            PopupFooter.partialStripItems.filter { $0.prominence == .primary }.map(\.action),
            [.retry]
        )
    }

    func testPartialStripOffersRetryOnly() {
        XCTAssertEqual(PopupFooter.partialStripItems.map(\.action), [.retry])
    }

    func testStoppedResultFooterMatchesDone() {
        XCTAssertEqual(actions(.done(result: "a", stopped: true)), actions(.done(result: "a")))
        XCTAssertEqual(actions(.done(result: "a", stopped: true), outputOnly: true), actions(.done(result: "a"), outputOnly: true))
    }

    func testNarrowDoneDropsTheTranslateAgainButton() {
        XCTAssertEqual(actions(.done(result: "a"), wide: false), [.new, .copyAndClose])
    }

    func testOutputOnlyOffersShowTextAndNeverEscBackToText() {
        XCTAssertEqual(actions(.done(result: "a"), outputOnly: true), [.showText, .copyAndClose])
        XCTAssertEqual(actions(.streaming(accumulated: ""), outputOnly: true), [.showText, .stop])
        // Esc closes the Output-only popup, so "Back to text esc" would lie.
        XCTAssertEqual(actions(.error(message: "x", partial: nil), outputOnly: true), [.showText])
        XCTAssertEqual(actions(.missingKey(providerID: "openai"), outputOnly: true), [.showText])
    }

    func testCopyAndCloseNamesWhatHappens() {
        XCTAssertEqual(PopupFooter.Action.copyAndClose.title, "Copy & Close")
        XCTAssertEqual(PopupFooter.Action.translateAgain.keys, ["⌘", "↩"])
    }
}
