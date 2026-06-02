import AppKit
import ImageIO

enum ImageMetadata {
    static func pixelSize(of image: NSImage) -> (width: Int, height: Int)? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return (cgImage.width, cgImage.height)
    }

    static func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    static func fileSizeBytes(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber {
            return size.intValue
        }
        if let size = attributes[.size] as? Int {
            return size
        }
        throw CocoaError(.fileReadUnknown)
    }
}
