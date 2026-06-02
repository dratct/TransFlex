import Foundation

public struct SSEEvent: Equatable, Sendable {
    public let event: String?
    public let id: String?
    public let data: String

    public init(event: String? = nil, id: String? = nil, data: String) {
        self.event = event
        self.id = id
        self.data = data
    }
}

/// Stateful, byte-oriented parser per the SSE spec subset used by LLM APIs.
///
/// Buffers raw bytes and only decodes complete UTF-8 lines (`\n` delimited),
/// which side-steps multi-byte boundary corruption when a chunk lands in the
/// middle of a code point. Multiple `data:` lines within one event are
/// concatenated with `\n`, matching the WHATWG eventsource algorithm.
public final class SSEParser {
    private var byteBuffer: [UInt8] = []
    private var pendingEvent: String?
    private var pendingId: String?
    private var pendingData: [String] = []

    public init() {}

    /// Feeds raw bytes; returns any events whose terminating blank line was
    /// reached in this chunk.
    public func feed(_ bytes: Data) -> [SSEEvent] {
        byteBuffer.append(contentsOf: bytes)
        var events: [SSEEvent] = []
        while let newlineIndex = byteBuffer.firstIndex(of: 0x0A) {
            let lineBytes = byteBuffer[0..<newlineIndex]
            byteBuffer.removeSubrange(0...newlineIndex)
            let trimmed = stripTrailingCR(Array(lineBytes))
            let line = String(decoding: trimmed, as: UTF8.self)
            if let event = handleLine(line) {
                events.append(event)
            }
        }
        return events
    }

    /// Forces dispatch of any buffered event without a trailing blank line.
    /// Some servers close the stream cleanly without a final `\n\n`.
    public func flush() -> SSEEvent? {
        dispatchPending()
    }

    private func handleLine(_ line: String) -> SSEEvent? {
        if line.isEmpty {
            return dispatchPending()
        }
        if line.hasPrefix(":") {
            return nil
        }
        let (field, value) = splitField(line)
        switch field {
        case "event":
            pendingEvent = value
        case "data":
            pendingData.append(value)
        case "id":
            pendingId = value
        case "retry":
            break
        default:
            break
        }
        return nil
    }

    private func dispatchPending() -> SSEEvent? {
        defer {
            pendingEvent = nil
            pendingId = nil
            pendingData.removeAll(keepingCapacity: true)
        }
        guard !pendingData.isEmpty else { return nil }
        let data = pendingData.joined(separator: "\n")
        return SSEEvent(event: pendingEvent, id: pendingId, data: data)
    }

    private func splitField(_ line: String) -> (String, String) {
        guard let colonIdx = line.firstIndex(of: ":") else {
            return (line, "")
        }
        let field = String(line[..<colonIdx])
        var value = String(line[line.index(after: colonIdx)...])
        if value.hasPrefix(" ") { value.removeFirst() }
        return (field, value)
    }

    private func stripTrailingCR(_ bytes: [UInt8]) -> [UInt8] {
        guard bytes.last == 0x0D else { return bytes }
        return Array(bytes.dropLast())
    }
}
