import AppKit
import UniformTypeIdentifiers

/// Wrapper around `NSOpenPanel` for image selection. Filters to a whitelist
/// of bitmap formats the providers can decode and returns both the loaded
/// `NSImage` and the on-disk file size so the size cap can run before
/// expensive encode work.
@MainActor
enum ImageFilePicker {
    static let allowedTypes: [UTType] = [
        .png, .jpeg, .gif, .webP, .heic, .tiff, .bmp,
    ]

    struct Picked {
        let image: NSImage?
        let fileSizeBytes: Int
        let errorMessage: String?
    }

    static func choose() async -> Picked? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose an image to translate (max 20 MB)"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }
        let size: Int
        do {
            size = try ImageMetadata.fileSizeBytes(of: url)
        } catch {
            return Picked(image: nil, fileSizeBytes: 0, errorMessage: "Could not read the image file.")
        }
        if size > ImageTranslationCoordinator.maxFileSizeBytes {
            return Picked(image: nil, fileSizeBytes: size, errorMessage: "Image is too large (max 20 MB).")
        }
        if let pixels = ImageMetadata.pixelSize(of: url),
           pixels.width * pixels.height > ImageTranslationCoordinator.maxPixelCount {
            return Picked(image: nil, fileSizeBytes: size, errorMessage: "Image is too large (max 50 megapixels).")
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        return Picked(image: image, fileSizeBytes: size, errorMessage: nil)
    }
}
