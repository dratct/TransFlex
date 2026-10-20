import XCTest
@testable import TransFlex

final class QuickPopupSizingTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    func testInitialFrameIsNarrowShortAndLeavesRoomToGrowDown() {
        let frame = QuickPopupSizing.initialFrame(in: screen)
        XCTAssertEqual(frame.width, 400)
        XCTAssertEqual(frame.height, 200)
        XCTAssertEqual(frame.midX, 500)
        XCTAssertEqual(frame.maxY, 800) // top of a 600pt popup centered on screen
    }

    func testGrowsByOverflowKeepingTopEdge() throws {
        let start = QuickPopupSizing.initialFrame(in: screen)
        let grown = try XCTUnwrap(QuickPopupSizing.grownFrame(
            current: start, outputContentHeight: 250, outputVisibleHeight: 100, in: screen
        ))
        XCTAssertEqual(grown.height, 350)
        XCTAssertEqual(grown.maxY, start.maxY)
        XCTAssertEqual(grown.width, start.width)
    }

    func testGrowthIsCappedAtMaxHeight() throws {
        let start = QuickPopupSizing.initialFrame(in: screen)
        let grown = try XCTUnwrap(QuickPopupSizing.grownFrame(
            current: start, outputContentHeight: 5000, outputVisibleHeight: 100, in: screen
        ))
        XCTAssertEqual(grown.height, 600)
        XCTAssertNil(QuickPopupSizing.grownFrame(
            current: grown, outputContentHeight: 6000, outputVisibleHeight: 500, in: screen
        ))
    }

    func testNeverShrinks() {
        let start = CGRect(x: 0, y: 400, width: 400, height: 400)
        XCTAssertNil(QuickPopupSizing.grownFrame(
            current: start, outputContentHeight: 50, outputVisibleHeight: 300, in: screen
        ))
    }
}
