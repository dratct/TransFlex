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
        field = nil
        acceptsPaste = true
        targetInPlace = true
        targetRestorable = true
        restoreCalls = 0
    }

    override func tearDown() async throws {
        pasteboard.releaseGlobally()
        try await super.tearDown()
    }

    /// `field` is what the focused text field shows; nil when the app does
    /// not expose it. A paste writes into it only when `acceptsPaste`.
    private var field: String?
    private var acceptsPaste = true
    /// Whether the app, field and selection the text was copied from are
    /// still in front at paste time, and whether restoring brings them back.
    private var targetInPlace = true
    private var targetRestorable = true
    private var restoreCalls = 0

    /// False: the app the text came from is unknown, as when nothing is frontmost.
    private var copies = 0
    private var knowsTarget = true
    /// What the next ⌘C copies, when it differs from the first selection.
    private var nextSelection: String?
    private var secretCheck = SecretCheck(isOn: { true }, isOnThisMac: { _ in false })

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
                    self.copies += 1
                    self.pasteboard.clearContents()
                    self.pasteboard.setString(self.nextSelection ?? selection, forType: .string)
                } else if key == CGKeyCode(kVK_ANSI_V) {
                    let text = self.pasteboard.string(forType: .string) ?? ""
                    self.pasted.append(text)
                    if self.acceptsPaste, self.field != nil { self.field = text }
                }
            },
            focus: SelectionCapture.Focus(
                capture: { [weak self] _ in
                    guard self?.knowsTarget ?? true else { return nil }
                    return SelectionCapture.TextTarget(pid: 42, element: nil, range: nil, checksSelection: false)
                },
                isInPlace: { [weak self] _, _ in self?.targetInPlace ?? false },
                restore: { [weak self] _ in
                    guard let self else { return }
                    self.restoreCalls += 1
                    if self.targetRestorable { self.targetInPlace = true }
                },
                text: { [weak self] _ in self?.field }
            ),
            pollInterval: 1_000_000,
            copyTimeout: 30_000_000,
            restoreDelay: 1_000_000,
            pasteConfirmTimeout: 50_000_000
        )
        return QuickReplaceCoordinator(translationService: service, selection: capture, secretCheck: secretCheck)
    }

    // MARK: Secret check

    private static let flagged = "deploy with \(SecretScannerTests.githubToken) today"

    private func stoppedCoordinator() async throws -> QuickReplaceCoordinator {
        provider.scriptedEvents = [.textDelta("triển khai"), .stop(reason: .complete)]
        let coordinator = makeCoordinator(selection: Self.flagged)
        do {
            _ = try await coordinator.run(preset: preset)
            XCTFail("a selection with a secret is not sent")
        } catch let found as QuickReplaceCoordinator.SecretFound {
            XCTAssertEqual(found.match, SecretMatch(kind: "GitHub token", masked: "ghp_…ZZZZ"))
            XCTAssertFalse("\(found)".contains("mmmm"), "the error never carries the value")
        }
        XCTAssertTrue(provider.capturedMessages.isEmpty, "nothing was sent")
        XCTAssertEqual(pasted, [], "nothing was pasted")
        return coordinator
    }

    func testSelectionWithASecretIsNotSentOrPasted() async throws {
        let coordinator = try await stoppedCoordinator()
        XCTAssertFalse(coordinator.isRunning)
    }

    func testSendAnywayTranslatesAndPastesOverTheSameSelection() async throws {
        let history = try HistoryStore(inMemory: true)
        let coordinator = try await stoppedCoordinator()
        coordinator.historyStore = history

        let ran = try await coordinator.runSendingAnyway(preset: preset)

        XCTAssertTrue(ran)
        XCTAssertEqual(pasted, ["triển khai"])
        XCTAssertTrue(provider.capturedMessages.last?.content.contains(SecretScannerTests.githubToken) ?? false)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(try history.allEntries().count, 0, "sent anyway is not saved to History")
    }

    func testSendAnywayBringsTheSelectionBackBeforePasting() async throws {
        let coordinator = try await stoppedCoordinator()
        targetInPlace = false

        _ = try await coordinator.runSendingAnyway(preset: preset)

        XCTAssertEqual(restoreCalls, 1)
        XCTAssertEqual(pasted, ["triển khai"])
    }

    func testSendAnywaySendsNoPasteWhenTheSelectionCannotBeBroughtBack() async throws {
        let coordinator = try await stoppedCoordinator()
        targetInPlace = false
        targetRestorable = false

        do {
            _ = try await coordinator.runSendingAnyway(preset: preset)
            XCTFail("the paste has nowhere to go")
        } catch {
            XCTAssertEqual(error as? SelectionCapture.Failure, .targetLost)
        }
        XCTAssertEqual(pasted, [])
        XCTAssertEqual(pasteboard.string(forType: .string), "triển khai")
    }

    func testSendAnywaySendsNoPasteWhenTheSourceAppIsUnknown() async throws {
        knowsTarget = false
        let coordinator = try await stoppedCoordinator()

        do {
            _ = try await coordinator.runSendingAnyway(preset: preset)
            XCTFail("an unknown app is never pasted into after a wait")
        } catch {
            XCTAssertEqual(error as? SelectionCapture.Failure, .targetLost)
        }
        XCTAssertEqual(pasted, [])
        XCTAssertEqual(pasteboard.string(forType: .string), "triển khai")
    }

    /// The banner waits with no time limit. Where the field cannot be
    /// compared (a browser), the selection itself is read again: anything
    /// else selected now means the user moved on.
    func testSendAnywaySendsNoPasteWhenSomethingElseIsSelectedNow() async throws {
        let coordinator = try await stoppedCoordinator()
        nextSelection = "another paragraph"

        do {
            _ = try await coordinator.runSendingAnyway(preset: preset)
            XCTFail("the selection is no longer the one that was copied")
        } catch {
            XCTAssertEqual(error as? SelectionCapture.Failure, .targetLost)
        }
        XCTAssertEqual(pasted, [])
        XCTAssertEqual(pasteboard.string(forType: .string), "triển khai")
    }

    /// The check reads the selection of the app the text came from, so that
    /// app is brought back first; when it cannot be, no ⌘C goes to whatever
    /// app is in front instead.
    func testSendAnywayNeverReadsAnotherAppsSelection() async throws {
        let coordinator = try await stoppedCoordinator()
        targetInPlace = false
        targetRestorable = false
        copies = 0

        _ = try? await coordinator.runSendingAnyway(preset: preset)

        XCTAssertEqual(restoreCalls, 1)
        XCTAssertEqual(copies, 0, "no ⌘C outside the app the text came from")
        XCTAssertEqual(pasted, [])
    }

    func testSendAnywayReadsTheSelectionAgainOnceTheSourceAppIsBack() async throws {
        let coordinator = try await stoppedCoordinator()
        targetInPlace = false
        copies = 0

        _ = try await coordinator.runSendingAnyway(preset: preset)

        XCTAssertEqual(restoreCalls, 1)
        XCTAssertEqual(copies, 1)
        XCTAssertEqual(pasted, ["triển khai"])
    }

    func testDroppedSelectionCannotBeSentAnyway() async throws {
        let coordinator = try await stoppedCoordinator()

        coordinator.discardParked()
        let ran = try await coordinator.runSendingAnyway(preset: preset)

        XCTAssertFalse(ran)
        XCTAssertTrue(provider.capturedMessages.isEmpty)
    }

    func testANewRunDropsTheWaitingSelection() async throws {
        let coordinator = try await stoppedCoordinator()
        nextSelection = "Hello"
        _ = try await coordinator.run(preset: preset)
        XCTAssertEqual(pasted, ["triển khai"], "the new run pastes its own translation")

        let ran = try await coordinator.runSendingAnyway(preset: preset)

        XCTAssertFalse(ran, "the earlier selection is gone")
        XCTAssertEqual(pasted.count, 1)
    }

    func testSecretIsSentWhenTheCheckIsOffOrTheEndpointIsOnThisMac() async throws {
        provider.scriptedEvents = [.textDelta("triển khai"), .stop(reason: .complete)]
        for check in [SecretCheck(isOn: { false }, isOnThisMac: { _ in false }),
                      SecretCheck(isOn: { true }, isOnThisMac: { _ in true })] {
            secretCheck = check
            pasted = []
            let ran = try await makeCoordinator(selection: Self.flagged).run(preset: preset)
            XCTAssertTrue(ran)
            XCTAssertEqual(pasted, ["triển khai"])
        }
    }

    func testSecretAnnouncementNamesTheKindNotTheValue() async throws {
        provider.scriptedEvents = []
        let coordinator = makeCoordinator(selection: Self.flagged)
        let announcer = RecordingAnnouncer()
        coordinator.announcer = announcer

        _ = try? await coordinator.run(preset: preset)

        XCTAssertEqual(announcer.messages.count, 1)
        XCTAssertTrue(announcer.messages[0].hasPrefix("GitHub token found. Not sent to "), announcer.messages[0])
        XCTAssertFalse(announcer.messages[0].contains("mmmm"))
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

    func testReplaceAnnouncesResult() async throws {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        let announcer = RecordingAnnouncer()
        let coordinator = makeCoordinator(selection: "Hello")
        coordinator.announcer = announcer

        try await coordinator.run(preset: preset)
        XCTAssertEqual(announcer.messages, ["Replaced with the translation"])

        provider.scriptedEvents = []
        provider.scriptedError = LLMError.offline
        _ = try? await coordinator.run(preset: preset)
        XCTAssertEqual(announcer.messages.last, "Couldn’t replace the selection")
    }

    func testFieldThatIgnoresThePasteFailsAndLeavesTranslationOnClipboard() async {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        field = "Hello"
        acceptsPaste = false
        let coordinator = makeCoordinator(selection: "Hello")

        do {
            try await coordinator.run(preset: preset)
            XCTFail("Expected the unchanged field to fail the replace")
        } catch {
            XCTAssertEqual(error as? SelectionCapture.Failure, .pasteNotApplied)
        }
        XCTAssertEqual(field, "Hello")
        XCTAssertEqual(pasteboard.string(forType: .string), "Bonjour")
        XCTAssertFalse(coordinator.isRunning)
    }

    func testFieldThatTakesThePasteSucceedsAndRestoresClipboard() async throws {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        pasteboard.clearContents()
        pasteboard.setString("user clipboard", forType: .string)
        field = "Hello"
        let coordinator = makeCoordinator(selection: "Hello")

        let ran = try await coordinator.run(preset: preset)

        XCTAssertTrue(ran)
        XCTAssertEqual(field, "Bonjour")
        XCTAssertEqual(pasteboard.string(forType: .string), "user clipboard")
    }

    func testElementThatDoesNotShowTheSelectionIsNotChecked() async throws {
        for shown in ["", "unrelated text"] {
            provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
            pasteboard.clearContents()
            pasteboard.setString("user clipboard", forType: .string)
            field = shown
            acceptsPaste = false
            let coordinator = makeCoordinator(selection: "Hello")

            let ran = try await coordinator.run(preset: preset)

            XCTAssertTrue(ran, "field \"\(shown)\"")
            XCTAssertEqual(pasteboard.string(forType: .string), "user clipboard", "field \"\(shown)\"")
        }
    }

    func testTranslationIdenticalToSelectionIsNotTreatedAsIgnored() async throws {
        provider.scriptedEvents = [.textDelta("OK"), .stop(reason: .complete)]
        field = "OK"
        acceptsPaste = false
        let coordinator = makeCoordinator(selection: "OK")

        let ran = try await coordinator.run(preset: preset)

        XCTAssertTrue(ran)
    }

    func testTargetStillInPlaceIsPastedWithoutRestoring() async throws {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        let coordinator = makeCoordinator(selection: "Hello")

        try await coordinator.run(preset: preset)

        XCTAssertEqual(restoreCalls, 0)
        XCTAssertEqual(pasted, ["Bonjour"])
    }

    func testTargetLeftDuringTranslationIsRestoredBeforePasting() async throws {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        targetInPlace = false
        let coordinator = makeCoordinator(selection: "Hello")

        let ran = try await coordinator.run(preset: preset)

        XCTAssertTrue(ran)
        XCTAssertEqual(restoreCalls, 1)
        XCTAssertEqual(pasted, ["Bonjour"])
    }

    func testTargetThatCannotBeRestoredIsNeverPastedInto() async {
        provider.scriptedEvents = [.textDelta("Bonjour"), .stop(reason: .complete)]
        targetInPlace = false
        targetRestorable = false
        let coordinator = makeCoordinator(selection: "Hello")

        do {
            try await coordinator.run(preset: preset)
            XCTFail("Expected the lost target to fail the replace")
        } catch {
            XCTAssertEqual(error as? SelectionCapture.Failure, .targetLost)
        }
        XCTAssertTrue(pasted.isEmpty, "⌘V must not reach whatever is in front now")
        XCTAssertEqual(pasteboard.string(forType: .string), "Bonjour")
        XCTAssertFalse(coordinator.isRunning)
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
        try await waitUntil({ hold.log == ["hold"] })
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
        try await waitUntil({ hold.log == ["hold"] })
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
