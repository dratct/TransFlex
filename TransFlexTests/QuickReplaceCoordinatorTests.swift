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

    // MARK: - Esc is held only while a run is active

    private func makeHeldCoordinator(selection: String) -> (QuickReplaceCoordinator, RecordingEscapeHold) {
        let coordinator = makeCoordinator(selection: selection)
        let hold = RecordingEscapeHold()
        coordinator.escapeHold = hold
        return (coordinator, hold)
    }

    func testEscIsReleasedAfterAPaste() async throws {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        let (coordinator, hold) = makeHeldCoordinator(selection: "Hello")
        try await coordinator.run(preset: preset)
        XCTAssertEqual(hold.log, ["hold", "release"])
    }

    func testEscIsReleasedAfterAProviderError() async {
        provider.scriptedError = LLMError.auth
        let (coordinator, hold) = makeHeldCoordinator(selection: "Hello")
        _ = try? await coordinator.run(preset: preset)
        XCTAssertEqual(hold.log, ["hold", "release"])
    }

    func testEscIsReleasedAfterAnEmptyTranslation() async {
        provider.scriptedEvents = [.textDelta(" "), .stop(reason: .complete)]
        let (coordinator, hold) = makeHeldCoordinator(selection: "Hello")
        _ = try? await coordinator.run(preset: preset)
        XCTAssertEqual(hold.log, ["hold", "release"])
    }

    func testEscIsReleasedWhenNothingIsSelected() async {
        let (coordinator, hold) = makeHeldCoordinator(selection: "")
        do {
            try await coordinator.run(preset: preset)
            XCTFail("Expected noSelection")
        } catch {
            XCTAssertEqual(error as? SelectionCapture.Failure, .noSelection)
        }
        XCTAssertEqual(hold.log, ["hold", "release"])
    }

    func testEscCancelsTheRunWithoutPasting() async throws {
        provider.scriptedEvents = [.textDelta("Bon")]
        provider.holdsOpen = true
        let (coordinator, hold) = makeHeldCoordinator(selection: "Hello")

        let run = Task { try await coordinator.run(preset: preset) }
        for _ in 0..<200 where hold.log != ["hold"] { try await Task.sleep(nanoseconds: 5_000_000) }
        hold.press()

        do {
            _ = try await run.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError, "got \(error)")
        }
        XCTAssertTrue(pasted.isEmpty)
        XCTAssertEqual(hold.log, ["hold", "release"])
        XCTAssertFalse(coordinator.isRunning)
    }

    func testASecondPressWhileRunningNeitherHoldsNorReleasesEsc() async throws {
        provider.scriptedEvents = [.textDelta("Bon")]
        provider.holdsOpen = true
        let (coordinator, hold) = makeHeldCoordinator(selection: "Hello")

        let run = Task { try await coordinator.run(preset: preset) }
        for _ in 0..<200 where hold.log != ["hold"] { try await Task.sleep(nanoseconds: 5_000_000) }
        let second = try await coordinator.run(preset: preset)
        XCTAssertFalse(second)
        XCTAssertEqual(hold.log, ["hold"])

        coordinator.cancel()
        _ = try? await run.value
        XCTAssertEqual(hold.log, ["hold", "release"])
    }

    func testKeepingEdgeWhitespace() {
        XCTAssertEqual(QuickReplaceCoordinator.keepingEdgeWhitespace(of: "  hi \n", around: "xin"), "  xin \n")
        XCTAssertEqual(QuickReplaceCoordinator.keepingEdgeWhitespace(of: "hi", around: "xin"), "xin")
    }
}

@MainActor
private final class RecordingEscapeHold: EscapeHold {
    private(set) var log: [String] = []
    private var onPress: (() -> Void)?

    func hold(onPress: @escaping () -> Void) {
        log.append("hold")
        self.onPress = onPress
    }

    func release() {
        log.append("release")
        onPress = nil
    }

    func press() { onPress?() }
}
