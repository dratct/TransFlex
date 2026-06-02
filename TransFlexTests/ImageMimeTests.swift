import XCTest
@testable import TransFlex

final class ImageMimeTests: XCTestCase {
    func testDetectsPNGMagic() {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        XCTAssertEqual(ImageMime.detect(png), .png)
        XCTAssertEqual(ImageMime.detect(png).rawValue, "image/png")
    }

    func testDetectsJPEGMagic() {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        XCTAssertEqual(ImageMime.detect(jpeg), .jpeg)
        XCTAssertEqual(ImageMime.detect(jpeg).rawValue, "image/jpeg")
    }

    func testEmptyDataFallsBackToPNG() {
        XCTAssertEqual(ImageMime.detect(Data()), .png)
    }

    func testUnknownBytesFallBackToPNG() {
        XCTAssertEqual(ImageMime.detect(Data([0x00, 0x01, 0x02, 0x03])), .png)
    }

    func testJPEGEmittedInOpenAIRequest() {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])
        let body = OpenAIRequestBuilder.body(
            model: "gpt-4o",
            messages: [.init(role: .user, content: "describe")],
            image: jpeg,
            temperature: 0.3,
            maxTokens: nil,
            stream: true
        )
        let messages = body["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]
        let url = (content?[1]["image_url"] as? [String: Any])?["url"] as? String
        XCTAssertTrue(url?.hasPrefix("data:image/jpeg;base64,") ?? false, "url=\(url ?? "nil")")
    }

    func testJPEGEmittedInAnthropicRequest() {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE1])
        let body = AnthropicRequestBuilder.body(
            model: "claude-3-5-sonnet-latest",
            system: nil,
            conversation: [.init(role: .user, content: "describe")],
            image: jpeg,
            temperature: 0.3,
            maxTokens: 1024
        )
        let messages = body["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]
        let source = content?[0]["source"] as? [String: Any]
        XCTAssertEqual(source?["media_type"] as? String, "image/jpeg")
    }

    func testJPEGEmittedInGeminiRequest() {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xDB])
        let body = GeminiRequestBuilder.body(
            messages: [.init(role: .user, content: "describe")],
            image: jpeg,
            temperature: 0.3,
            maxTokens: nil
        )
        let contents = body["contents"] as? [[String: Any]]
        let parts = contents?.first?["parts"] as? [[String: Any]]
        let inline = parts?.first?["inline_data"] as? [String: Any]
        XCTAssertEqual(inline?["mime_type"] as? String, "image/jpeg")
    }
}
