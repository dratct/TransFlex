import AppKit
import OSLog

/// Value type holding an attached image and its lazy-processed encoding.
/// Resizes + encodes on first access to avoid work when image is discarded.
enum ImageSource: String {
    case drag
    case paste
    case file
}

final class ImageInput {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "ImageInput")

    let source: NSImage
    let sourceType: ImageSource
    let originalSize: NSSize

    private var cache: [Int: ImageEncoder.EncodedImage] = [:]

    init(source: NSImage, sourceType: ImageSource) {
        self.source = source
        self.sourceType = sourceType
        self.originalSize = source.size
    }

    /// Resizes to `maxDim` and encodes. Caches per provider dimension.
    func processedData(maxDim: Int) -> (data: Data, mimeType: String)? {
        if let cached = cache[maxDim] {
            return (cached.data, cached.mimeType)
        }

        guard let resized = ImageResizer.resize(source, maxDim: maxDim) else {
            Self.logger.error("Image resize failed")
            return nil
        }
        guard let encoded = ImageEncoder.encode(resized) else {
            Self.logger.error("Image encode failed")
            return nil
        }

        cache[maxDim] = encoded
        return (encoded.data, encoded.mimeType)
    }
}
