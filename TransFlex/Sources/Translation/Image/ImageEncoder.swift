import AppKit
import ImageIO

/// Encodes a CGImage to compressed Data with MIME type.
/// JPEG 0.85 for opaque images, PNG fallback for alpha-channel content.
enum ImageEncoder {
    struct EncodedImage {
        let data: Data
        let mimeType: String
    }

    static func encode(_ cgImage: CGImage) -> EncodedImage? {
        let hasAlpha = cgImage.alphaInfo != .none && cgImage.alphaInfo != .noneSkipLast
        let uti: CFString = hasAlpha ? "public.png" as CFString : "public.jpeg" as CFString
        let mimeType = hasAlpha ? "image/png" : "image/jpeg"

        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, uti, 1, nil) else { return nil }

        let options: [CFString: Any] = hasAlpha
            ? [:]
            : [kCGImageDestinationLossyCompressionQuality: 0.85]

        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(dest) else { return nil }

        return EncodedImage(data: data as Data, mimeType: mimeType)
    }
}
