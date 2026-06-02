import XCTest
@testable import TransFlex

final class SSEParserTests: XCTestCase {
    private var parser: SSEParser!

    override func setUp() {
        super.setUp()
        parser = SSEParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    func testSingleEvent() {
        let events = parser.feed(Data("data: hello\n\n".utf8))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.data, "hello")
    }

    func testEventWithNamedTypeAndId() {
        let events = parser.feed(Data("event: message_delta\nid: 42\ndata: {\"x\":1}\n\n".utf8))
        XCTAssertEqual(events.first?.event, "message_delta")
        XCTAssertEqual(events.first?.id, "42")
        XCTAssertEqual(events.first?.data, "{\"x\":1}")
    }

    func testMultipleDataLinesJoined() {
        let events = parser.feed(Data("data: line1\ndata: line2\n\n".utf8))
        XCTAssertEqual(events.first?.data, "line1\nline2")
    }

    func testCommentsIgnored() {
        let events = parser.feed(Data(": keep-alive\ndata: real\n\n".utf8))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.data, "real")
    }

    func testChunkSplitMidLine() {
        var events = parser.feed(Data("data: hel".utf8))
        XCTAssertEqual(events.count, 0)
        events = parser.feed(Data("lo\n\n".utf8))
        XCTAssertEqual(events.first?.data, "hello")
    }

    func testChunkSplitAcrossNewline() {
        var events = parser.feed(Data("data: a".utf8))
        events.append(contentsOf: parser.feed(Data("\n".utf8)))
        events.append(contentsOf: parser.feed(Data("\n".utf8)))
        XCTAssertEqual(events.first?.data, "a")
    }

    func testMultiByteUTF8AcrossChunks() {
        // U+1F600 grinning face = F0 9F 98 80
        let part1 = Data([0x64, 0x61, 0x74, 0x61, 0x3A, 0x20, 0xF0, 0x9F])
        let part2 = Data([0x98, 0x80, 0x0A, 0x0A])
        var events = parser.feed(part1)
        XCTAssertEqual(events.count, 0)
        events = parser.feed(part2)
        XCTAssertEqual(events.first?.data, "😀")
    }

    func testCRLFLineEndings() {
        let events = parser.feed(Data("data: x\r\n\r\n".utf8))
        XCTAssertEqual(events.first?.data, "x")
    }

    func testFlushOnUnterminated() {
        _ = parser.feed(Data("data: trailing\n".utf8))
        let event = parser.flush()
        XCTAssertEqual(event?.data, "trailing")
    }

    func testEmptyDataYieldsNoEvent() {
        let events = parser.feed(Data("\n".utf8))
        XCTAssertEqual(events.count, 0)
    }

    func testSequenceOfTwoEvents() {
        let events = parser.feed(Data("data: one\n\ndata: two\n\n".utf8))
        XCTAssertEqual(events.map { $0.data }, ["one", "two"])
    }

    func testDataWithoutSpaceAfterColon() {
        let events = parser.feed(Data("data:nospace\n\n".utf8))
        XCTAssertEqual(events.first?.data, "nospace")
    }

    func testFineGrainedByteBoundaries() {
        // Feed every byte one at a time — covers worst-case fragmentation.
        let stream = "data: abc\n\ndata: def\n\n"
        var events: [SSEEvent] = []
        for byte in stream.utf8 {
            events.append(contentsOf: parser.feed(Data([byte])))
        }
        XCTAssertEqual(events.map { $0.data }, ["abc", "def"])
    }
}
