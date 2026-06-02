import AppKit
import ImageIO

/// Downscales images to fit within a provider's max dimension.
enum ImageResizer {
    /// Returns a CGImage whose longer side is at most `maxDim` pixels.
    /// Returns `nil` if the source cannot be decoded or already fits.
    static func resize(_ nsImage: NSImage, maxDim: Int) -> CGImage? {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // Already within bounds — return as-is
        guard cgImage.width > maxDim || cgImage.height > maxDim else { return cgImage }

        guard let data = nsImage.tiffRepresentation,
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }

        let options = [
            kCGImageSourceThumbnailMaxPixelSize: maxDim,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
