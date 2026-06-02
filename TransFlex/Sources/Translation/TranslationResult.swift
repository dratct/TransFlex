import Foundation

/// Aggregates streamed `LLMEvent`s into a final text + usage snapshot.
/// Actor-isolated so concurrent ingest from a task group is safe.
public actor TranslationResult {
    private var textBuffer: String = ""
    private var inputTokens: Int = 0
    private var outputTokens: Int = 0
    private var stopReason: StopReason?

    public init() {}

    public func ingest(_ event: LLMEvent) {
        switch event {
        case .textDelta(let chunk):
            textBuffer.append(chunk)
        case .usage(let input, let output):
            inputTokens = input
            outputTokens = output
        case .stop(let reason):
            stopReason = reason
        case .error:
            break
        }
    }

    public func finalText() -> String { textBuffer }
    public func usage() -> (input: Int, output: Int) { (inputTokens, outputTokens) }
    public func reason() -> StopReason? { stopReason }
}
