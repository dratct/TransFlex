import XCTest
@testable import TransFlex
import AppKit

@MainActor
final class ImageTranslationCoordinatorTests: XCTestCase {
    func test_ok_smallImage() {
        let img = makeImage(width: 100, height: 100)
        let result = ImageTranslationCoordinator.validateAndWrap(img, source: .file, fileSizeBytes: 1024)
        guard case .ok(let input) = result else { return XCTFail("Expected ok, got \(result)") }
        XCTAssertEqual(input.sourceType, .file)
    }

    func test_tooLarge_fileSize() {
        let img = makeImage(width: 100, height: 100)
        let oversized = ImageTranslationCoordinator.maxFileSizeBytes + 1
        let result = ImageTranslationCoordinator.validateAndWrap(img, source: .file, fileSizeBytes: oversized)
        guard case .tooLarge(let reason) = result else { return XCTFail("Expected tooLarge, got \(result)") }
        XCTAssertTrue(reason.contains("MB"), "Reason should mention MB, got: \(reason)")
    }

    func test_tooLarge_pixelCount() {
        // 8000 × 8000 = 64 MP > 50 MP cap
        let img = makeImage(width: 8000, height: 8000)
        let result = ImageTranslationCoordinator.validateAndWrap(img, source: .paste)
        guard case .tooLarge(let reason) = result else { return XCTFail("Expected tooLarge, got \(result)") }
        XCTAssertTrue(reason.contains("megapixel"), "Reason should mention megapixel, got: \(reason)")
    }

    func test_ok_dragSource() {
        let img = makeImage(width: 200, height: 200)
        let result = ImageTranslationCoordinator.validateAndWrap(img, source: .drag)
        guard case .ok(let input) = result else { return XCTFail("Expected ok, got \(result)") }
        XCTAssertEqual(input.sourceType, .drag)
    }

    private func makeImage(width: CGFloat, height: CGFloat) -> NSImage {
        let size = NSSize(width: width, height: height)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        img.unlockFocus()
        return img
    }
}
