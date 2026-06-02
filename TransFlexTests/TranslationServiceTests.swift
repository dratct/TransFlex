import XCTest
@testable import TransFlex

final class TranslationServiceTests: XCTestCase {
    private func makePreset(supportsVision: Bool = false, providerID: String = "mock") -> Preset {
        Preset(
            name: "P", providerID: providerID, modelID: "m1",
            systemPrompt: "Translate the input.",
            temperature: 0.4, supportsVision: supportsVision
        )
    }

    private func service(returning provider: LLMProvider, apiKey: String = "k") -> TranslationService {
        TranslationService(
            provider: { _ in provider },
            apiKey: { _ in apiKey }
        )
    }
    func testForwardsAllStreamEvents() async throws {
        let mock = MockLLMProvider()
        mock.scriptedEvents = [
            .textDelta("xin "),
            .textDelta("chào"),
            .usage(input: 12, output: 4),
            .stop(reason: .complete),
        ]
        let svc = service(returning: mock)

        var collected: [LLMEvent] = []
        for try await event in svc.translate(input: .text("hello"), preset: makePreset()) {
            collected.append(event)
        }
        XCTAssertEqual(collected, mock.scriptedEvents)
    }

    func testBuildsExpectedMessages() async throws {
        let mock = MockLLMProvider()
        mock.scriptedEvents = [.stop(reason: .complete)]
        let preset = makePreset()
        let svc = service(returning: mock)

        for try await _ in svc.translate(input: .text("hello"), preset: preset) { }

        XCTAssertEqual(mock.capturedMessages.count, 2)
        XCTAssertEqual(mock.capturedMessages[0].role, .system)
        XCTAssertEqual(mock.capturedMessages[1].content, "hello")
        XCTAssertEqual(mock.capturedConfig?.model, "m1")
        XCTAssertEqual(mock.capturedConfig?.temperature, 0.4)
        XCTAssertEqual(mock.capturedConfig?.apiKey, "k")
    }

    func testImageRoutesDataToProviderWhenVisionSupported() async throws {
        let mock = MockLLMProvider()
        mock.scriptedModels = [Model(id: "m1", name: "Mock", supportsVision: true)]
        mock.scriptedEvents = [.stop(reason: .complete)]
        let preset = makePreset(supportsVision: true)
        let svc = service(returning: mock)
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47])

        for try await _ in svc.translate(
            input: .image(imageBytes, accompanyingText: "translate"),
            preset: preset
        ) { }

        XCTAssertEqual(mock.capturedImage, imageBytes)
    }

    func testImageOnNonVisionPresetThrows() async {
        let mock = MockLLMProvider()
        let preset = makePreset(supportsVision: false)
        let svc = service(returning: mock)

        do {
            for try await _ in svc.translate(
                input: .image(Data([0x00]), accompanyingText: nil),
                preset: preset
            ) { }
            XCTFail("expected visionUnsupported")
        } catch let err as TranslationError {
            guard case .visionUnsupported = err else {
                XCTFail("got \(err)")
                return
            }
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testUnknownModelIDStillStreams() async throws {
        let mock = MockLLMProvider()
        mock.scriptedModels = [Model(id: "other-model", name: "Other", supportsVision: false)]
        mock.scriptedEvents = [.textDelta("ok"), .stop(reason: .complete)]
        let svc = service(returning: mock)
        let preset = makePreset()

        var deltas: [String] = []
        for try await event in svc.translate(input: .text("x"), preset: preset) {
            if case .textDelta(let s) = event { deltas.append(s) }
        }
        XCTAssertEqual(deltas.joined(), "ok")
    }

    func testUnknownProviderThrowsProviderMissing() async {
        let svc = TranslationService(
            provider: { _ in throw ProviderError.unknownProvider(id: "absent") },
            apiKey: { _ in "" }
        )
        let preset = makePreset(providerID: "absent")
        do {
            for try await _ in svc.translate(input: .text("x"), preset: preset) { }
            XCTFail("expected providerMissing")
        } catch let err as TranslationError {
            guard case .providerMissing = err else {
                XCTFail("got \(err)")
                return
            }
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testUpstreamProviderErrorPropagates() async {
        let mock = MockLLMProvider()
        mock.scriptedEvents = [.textDelta("partial")]
        mock.scriptedError = LLMError.rateLimit(retryAfterSeconds: 5)
        let svc = service(returning: mock)

        do {
            for try await _ in svc.translate(input: .text("x"), preset: makePreset()) { }
            XCTFail("expected upstream error")
        } catch let err as LLMError {
            XCTAssertEqual(err, .rateLimit(retryAfterSeconds: 5))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testTranslationResultActorAggregatesStream() async throws {
        let mock = MockLLMProvider()
        mock.scriptedEvents = [
            .textDelta("hel"),
            .textDelta("lo"),
            .usage(input: 1, output: 2),
            .stop(reason: .complete),
        ]
        let svc = service(returning: mock)
        let result = TranslationResult()

        for try await event in svc.translate(input: .text("xyz"), preset: makePreset()) {
            await result.ingest(event)
        }
        let text = await result.finalText()
        let usage = await result.usage()
        let reason = await result.reason()
        XCTAssertEqual(text, "hello")
        XCTAssertEqual(usage.input, 1)
        XCTAssertEqual(usage.output, 2)
        XCTAssertEqual(reason, .complete)
    }

    // MARK: - nil-localModels (OpenAI-compat hot-path)
    func testNilLocalModelsSkipsAvailableModelsCall() async throws {
        let mock = NoLocalCatalogMockProvider()
        mock.scriptedEvents = [.textDelta("ok"), .stop(reason: .complete)]
        let svc = service(returning: mock)
        let preset = makePreset(providerID: "no-catalog-mock")

        for try await _ in svc.translate(input: .text("x"), preset: preset) { }

        XCTAssertFalse(mock.availableModelsCalled, "availableModels() must not be called on the hot path")
    }

    func testNilLocalModelsImageBlockedByPresetFlag() async {
        let mock = NoLocalCatalogMockProvider()
        let preset = makePreset(supportsVision: false, providerID: "no-catalog-mock")
        let svc = service(returning: mock)
        do {
            for try await _ in svc.translate(
                input: .image(Data([0x00]), accompanyingText: nil),
                preset: preset
            ) { }
            XCTFail("expected visionUnsupported")
        } catch let err as TranslationError {
            guard case .visionUnsupported = err else {
                XCTFail("got \(err)")
                return
            }
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertFalse(mock.availableModelsCalled)
    }
}
