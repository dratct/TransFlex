import Foundation

/// Detects PNG vs JPEG from leading magic bytes. The image-translation flow
/// accepts screenshots (PNG) and clipboard / Files-app pastes (often JPEG);
/// hardcoding `image/png` made Gemini misinterpret JPEG payloads. Falls back
/// to PNG when bytes are too short or unrecognized so existing PNG callers
/// keep their MIME unchanged.
public enum ImageMime: String, Sendable {
    case png = "image/png"
    case jpeg = "image/jpeg"

    public static func detect(_ data: Data) -> ImageMime {
        let head = data.prefix(4)
        if head.count >= 4, head[head.startIndex] == 0x89,
           head[head.index(head.startIndex, offsetBy: 1)] == 0x50,
           head[head.index(head.startIndex, offsetBy: 2)] == 0x4E,
           head[head.index(head.startIndex, offsetBy: 3)] == 0x47 {
            return .png
        }
        if head.count >= 3, head[head.startIndex] == 0xFF,
           head[head.index(head.startIndex, offsetBy: 1)] == 0xD8,
           head[head.index(head.startIndex, offsetBy: 2)] == 0xFF {
            return .jpeg
        }
        return .png
    }
}
