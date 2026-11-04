import XCTest
@testable import TransFlex

final class PopupFrameTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    private let small = CGRect(x: 0, y: 0, width: 800, height: 500)

    // MARK: Popup

    func testPopupIsSixtyPercentCentred() {
        let frame = PopupFrame.initial(.popup, in: screen)
        XCTAssertEqual(frame, CGRect(x: 200, y: 200, width: 600, height: 600))
    }

    func testPopupKeepsItsMinimumOnSmallScreens() {
        let frame = PopupFrame.initial(.popup, in: small)
        XCTAssertEqual(frame.width, 520)
        XCTAssertEqual(frame.height, 360)
        XCTAssertEqual(frame.midX, small.midX)
        XCTAssertEqual(frame.midY, small.midY)
    }

    func testPopupNeverExceedsTheScreen() {
        let tiny = CGRect(x: 0, y: 0, width: 400, height: 300)
        let frame = PopupFrame.initial(.popup, in: tiny)
        XCTAssertLessThanOrEqual(frame.width, tiny.width)
        XCTAssertLessThanOrEqual(frame.height, tiny.height)
    }

    // MARK: Output-only popup

    func testOutputOnlyStartsShortAndLeavesRoomToGrowDown() {
        let frame = PopupFrame.initial(.outputOnly, in: screen)
        XCTAssertEqual(frame.width, 420) // 40% is 400, below the 420 minimum
        XCTAssertEqual(frame.height, 160)
        XCTAssertEqual(frame.midX, 500)
        XCTAssertEqual(frame.maxY, 800) // top of a 600pt popup centred on screen
    }

    func testOutputOnlyWidthStopsAtReadableMaximum() {
        let wide = CGRect(x: 0, y: 0, width: 2000, height: 1000)
        XCTAssertEqual(PopupFrame.initial(.outputOnly, in: wide).width, 660) // 40% is 800
    }

    // MARK: Output-only popup sized from its source

    private let chrome: CGFloat = 130

    func testShortSourceOpensAtMinimum() {
        let frame = PopupFrame.predicted(textHeight: { _ in 20 }, chromeHeight: chrome, in: screen)
        XCTAssertEqual(frame.size, CGSize(width: 420, height: 160))
    }

    func testMediumSourceOpensAtItsHeight() {
        let frame = PopupFrame.predicted(textHeight: { _ in 300 }, chromeHeight: chrome, in: screen)
        XCTAssertEqual(frame.size, CGSize(width: 420, height: 430))
    }

    func testLongSourceWidensUntilItFits() {
        // Text area scales inversely with the text column width (window − 56).
        let frame = PopupFrame.predicted(
            textHeight: { 200_000 / $0 }, chromeHeight: chrome, in: screen
        )
        // 420…480 overflow the 600pt cap; 500 (column 444) is the first that fits.
        XCTAssertEqual(frame.width, 500)
        XCTAssertEqual(frame.height, 130 + 200_000 / 444, accuracy: 0.01)
    }

    func testTooLongSourceOpensAtMaxWidthAndHeight() {
        let frame = PopupFrame.predicted(textHeight: { _ in 5000 }, chromeHeight: chrome, in: screen)
        XCTAssertEqual(frame.size, CGSize(width: 660, height: 600))
    }

    func testPredictedKeepsTopEdgeAndCentre() {
        let offset = CGRect(x: 100, y: 50, width: 1000, height: 1000)
        for textHeight: CGFloat in [0, 300, 5000] {
            let frame = PopupFrame.predicted(textHeight: { _ in textHeight }, chromeHeight: chrome, in: offset)
            XCTAssertEqual(frame.midX, offset.midX)
            XCTAssertEqual(frame.maxY, offset.midY + 300) // top of a 60% popup centred on screen
        }
    }

    func testWideScreenNeverPassesReadableMaximum() {
        let wide = CGRect(x: 0, y: 0, width: 2560, height: 1400)
        let frame = PopupFrame.predicted(textHeight: { _ in 50_000 }, chromeHeight: chrome, in: wide)
        XCTAssertEqual(frame.width, 660)
        XCTAssertEqual(frame.height, 840)
    }

    func testPredictedStaysOnSmallScreens() {
        let tiny = CGRect(x: 0, y: 0, width: 600, height: 400)
        let long = PopupFrame.predicted(textHeight: { _ in 5000 }, chromeHeight: chrome, in: tiny)
        XCTAssertEqual(long.size, CGSize(width: 600, height: 240))
        XCTAssertTrue(tiny.contains(long))
        let short = PopupFrame.predicted(textHeight: { _ in 0 }, chromeHeight: chrome, in: tiny)
        XCTAssertEqual(short.size, CGSize(width: 420, height: 160))
    }

    func testGrowsByOverflowKeepingTopEdge() throws {
        let start = PopupFrame.initial(.outputOnly, in: screen)
        let grown = try XCTUnwrap(PopupFrame.grown(
            current: start, outputContentHeight: 250, outputVisibleHeight: 100, in: screen
        ))
        XCTAssertEqual(grown.height, 310)
        XCTAssertEqual(grown.maxY, start.maxY)
        XCTAssertEqual(grown.width, start.width)
    }

    func testGrowthIsCappedAtMaxHeight() throws {
        let start = PopupFrame.initial(.outputOnly, in: screen)
        let grown = try XCTUnwrap(PopupFrame.grown(
            current: start, outputContentHeight: 5000, outputVisibleHeight: 100, in: screen
        ))
        XCTAssertEqual(grown.height, 600)
        XCTAssertNil(PopupFrame.grown(
            current: grown, outputContentHeight: 6000, outputVisibleHeight: 500, in: screen
        ))
    }

    func testNeverShrinks() {
        let start = CGRect(x: 0, y: 400, width: 400, height: 400)
        XCTAssertNil(PopupFrame.grown(
            current: start, outputContentHeight: 50, outputVisibleHeight: 300, in: screen
        ))
    }

}
