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
}
