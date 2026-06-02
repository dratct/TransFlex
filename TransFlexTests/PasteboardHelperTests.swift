import XCTest
import AppKit
@testable import TransFlex

final class PasteboardHelperTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var helper: PasteboardHelper!

    override func setUp() {
        super.setUp()
        // Isolated pasteboard so tests don't clobber the user's clipboard.
        pasteboard = NSPasteboard(name: NSPasteboard.Name("TransFlexTests.\(UUID().uuidString)"))
        helper = PasteboardHelper(pasteboard: pasteboard)
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        pasteboard = nil
        helper = nil
        super.tearDown()
    }

    func testTextRoundTrip() {
        XCTAssertTrue(helper.writeText("hello world"))
        XCTAssertEqual(helper.readText(), "hello world")
    }

    func testWriteTextOverwrites() {
        helper.writeText("first")
        helper.writeText("second")
        XCTAssertEqual(helper.readText(), "second")
    }

    func testChangeCountIncrementsOnWrite() {
        let initial = helper.changeCount
        helper.writeText("a")
        XCTAssertGreaterThan(helper.changeCount, initial)
    }

    func testReadTextReturnsNilWhenEmpty() {
        XCTAssertNil(helper.readText())
    }

    func testImageRoundTrip() {
        let image = makeTestImage()
        XCTAssertTrue(helper.writeImage(image))
        XCTAssertNotNil(helper.readImage())
    }

    private func makeTestImage() -> NSImage {
        let size = NSSize(width: 4, height: 4)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
