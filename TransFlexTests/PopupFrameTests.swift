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

    func testOutputOnlyWidthIsFortyPercentOnWideScreens() {
        let wide = CGRect(x: 0, y: 0, width: 2000, height: 1000)
        XCTAssertEqual(PopupFrame.initial(.outputOnly, in: wide).width, 800)
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
