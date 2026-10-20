import AppKit
import Carbon.HIToolbox
import XCTest
@testable import TransFlex

@MainActor
final class SelectionCaptureTests: XCTestCase {
    private var pasteboard: NSPasteboard!

    override func setUp() async throws {
        try await super.setUp()
        pasteboard = NSPasteboard(name: .init("SelectionCaptureTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("user clipboard", forType: .string)
    }

    override func tearDown() async throws {
        pasteboard.releaseGlobally()
        try await super.tearDown()
    }

    private func makeCapture(
        trusted: Bool = true,
        onKey: @escaping @MainActor (CGKeyCode, NSPasteboard) -> Void
    ) -> SelectionCapture {
        let pb = pasteboard!
        return SelectionCapture(
            pasteboard: pb,
            isTrusted: { trusted },
            modifiersHeld: { false },
            postCommandKey: { onKey($0, pb) },
            pollInterval: 1_000_000,
            copyTimeout: 30_000_000,
            restoreDelay: 1_000_000
        )
    }

    func testCopyReturnsSelectionAndRestoresClipboard() async throws {
        let capture = makeCapture { key, pb in
            guard key == CGKeyCode(kVK_ANSI_C) else { return }
            pb.clearContents()
            pb.setString("selected text", forType: .string)
        }

        let text = try await capture.copySelection()

        XCTAssertEqual(text, "selected text")
        XCTAssertEqual(pasteboard.string(forType: .string), "user clipboard")
    }

    func testCopyWithNothingSelectedThrowsAndKeepsClipboard() async {
        let capture = makeCapture { _, _ in }

        do {
            _ = try await capture.copySelection()
            XCTFail("Expected noSelection")
        } catch {
            XCTAssertEqual(error as? SelectionCapture.Failure, .noSelection)
        }
        XCTAssertEqual(pasteboard.string(forType: .string), "user clipboard")
    }

    func testUntrustedProcessDoesNotPostKeys() async {
        var posted = false
        let capture = makeCapture(trusted: false) { _, _ in posted = true }

        do {
            _ = try await capture.copySelection()
            XCTFail("Expected accessibilityNotGranted")
        } catch {
            XCTAssertEqual(error as? SelectionCapture.Failure, .accessibilityNotGranted)
        }
        XCTAssertFalse(posted)
    }

    func testPasteExposesTextAtCommandVThenRestoresClipboard() async throws {
        var seenAtPaste: String?
        let capture = makeCapture { key, pb in
            if key == CGKeyCode(kVK_ANSI_V) { seenAtPaste = pb.string(forType: .string) }
        }

        try await capture.paste("translated")

        XCTAssertEqual(seenAtPaste, "translated")
        XCTAssertEqual(pasteboard.string(forType: .string), "user clipboard")
    }

    func testPasteKeepsClipboardWrittenByUserMeanwhile() async throws {
        let capture = makeCapture { key, pb in
            guard key == CGKeyCode(kVK_ANSI_V) else { return }
            pb.clearContents()
            pb.setString("copied during paste", forType: .string)
        }

        try await capture.paste("translated")

        XCTAssertEqual(pasteboard.string(forType: .string), "copied during paste")
    }
}
