import AppKit
import Carbon.HIToolbox
import XCTest
@testable import TransFlex

@MainActor
final class QuickReplaceCoordinatorTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var provider: MockLLMProvider!
    private var pasted: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        pasteboard = NSPasteboard(name: .init("QuickReplaceCoordinatorTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        provider = MockLLMProvider()
        pasted = []
    }

    override func tearDown() async throws {
        pasteboard.releaseGlobally()
        try await super.tearDown()
    }

    private func makeCoordinator(selection: String) -> QuickReplaceCoordinator {
        let provider = provider!
        let service = TranslationService(provider: { _ in provider }, apiKey: { _ in "" })
        let capture = SelectionCapture(
            pasteboard: pasteboard,
            isTrusted: { true },
            modifiersHeld: { false },
            postCommandKey: { [weak self] key in
                guard let self else { return }
                if key == CGKeyCode(kVK_ANSI_C) {
                    self.pasteboard.clearContents()
                    self.pasteboard.setString(selection, forType: .string)
                } else if key == CGKeyCode(kVK_ANSI_V) {
                    self.pasted.append(self.pasteboard.string(forType: .string) ?? "")
                }
            },
            pollInterval: 1_000_000,
            copyTimeout: 30_000_000,
            restoreDelay: 1_000_000
        )
        return QuickReplaceCoordinator(translationService: service, selection: capture)
    }

    private var preset: Preset {
        Preset(name: "Test", providerID: "mock", modelID: "m1", systemPrompt: "Translate")
    }

    func testPastesFullTranslationKeepingSelectionEdgeWhitespace() async throws {
        provider.scriptedEvents = [.textDelta("Bon"), .textDelta("jour\n"), .stop(reason: .complete)]
        let coordinator = makeCoordinator(selection: "Hello\n")

        let ran = try await coordinator.run(preset: preset)

        XCTAssertTrue(ran)
        XCTAssertEqual(pasted, ["Bonjour\n"])
        XCTAssertTrue(provider.capturedMessages.last?.content.contains("Hello") ?? false)
    }

    func testProviderErrorDoesNotPaste() async {
        provider.scriptedEvents = [.textDelta("Bon")]
        provider.scriptedError = LLMError.auth
        let coordinator = makeCoordinator(selection: "Hello")

        do {
            try await coordinator.run(preset: preset)
            XCTFail("Expected provider error")
        } catch {
            XCTAssertEqual(error as? LLMError, .auth)
        }
        XCTAssertTrue(pasted.isEmpty)
        XCTAssertFalse(coordinator.isRunning)
    }

    func testEmptyTranslationDoesNotPaste() async {
        provider.scriptedEvents = [.textDelta("  \n"), .stop(reason: .complete)]
        let coordinator = makeCoordinator(selection: "Hello")

        do {
            try await coordinator.run(preset: preset)
            XCTFail("Expected EmptyResult")
        } catch {
            XCTAssertTrue(error is QuickReplaceCoordinator.EmptyResult)
        }
        XCTAssertTrue(pasted.isEmpty)
    }

    func testKeepingEdgeWhitespace() {
        XCTAssertEqual(QuickReplaceCoordinator.keepingEdgeWhitespace(of: "  hi \n", around: "xin"), "  xin \n")
        XCTAssertEqual(QuickReplaceCoordinator.keepingEdgeWhitespace(of: "hi", around: "xin"), "xin")
    }
}
