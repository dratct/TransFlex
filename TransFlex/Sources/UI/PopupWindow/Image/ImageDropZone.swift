import SwiftUI

/// Checks a dropped file before it is read, so the drop can say why it was refused.
enum ImageDropRules {
    static func rejection(forFileSize bytes: Int) -> String? {
        bytes > ImageTranslationCoordinator.maxFileSizeBytes ? "Image is too large (max 20 MB)." : nil
    }

    static let tooManyPixels = "Image is too large (max 50 megapixels)."
    static let unreadable = "Unsupported image format."
}

/// Drop target and paste handler for image attachment. Wraps content
/// and intercepts image drops + Cmd-V when pasteboard has image data.
struct ImageDropZone<Content: View>: View {
    let onImage: (NSImage, ImageSource, Int?) -> Void
    /// A dropped file refused before reading, with the reason to show.
    var onRejected: (String) -> Void = { _ in }
    @ViewBuilder let content: Content

    var body: some View {
        content
            .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }
            .onPasteCommand(of: [.png, .tiff, .fileURL]) { items in
                handlePaste(items)
            }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier("public.image") {
            provider.loadObject(ofClass: NSImage.self) { image, _ in
                guard let nsImage = image as? NSImage else { return }
                DispatchQueue.main.async { onImage(nsImage, .drag, nil) }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }
                let reject: (String) -> Void = { reason in DispatchQueue.main.async { onRejected(reason) } }
                guard let size = try? ImageMetadata.fileSizeBytes(of: url) else {
                    return reject(ImageDropRules.unreadable)
                }
                if let reason = ImageDropRules.rejection(forFileSize: size) { return reject(reason) }
                if let pixels = ImageMetadata.pixelSize(of: url),
                   pixels.width * pixels.height > ImageTranslationCoordinator.maxPixelCount {
                    return reject(ImageDropRules.tooManyPixels)
                }
                guard let nsImage = NSImage(contentsOf: url) else { return reject(ImageDropRules.unreadable) }
                DispatchQueue.main.async { onImage(nsImage, .drag, size) }
            }
            return true
        }

        return false
    }

    private func handlePaste(_ items: [NSItemProvider]) {
        guard let item = items.first else { return }
        if item.hasItemConformingToTypeIdentifier("public.image") {
            item.loadObject(ofClass: NSImage.self) { image, _ in
                guard let nsImage = image as? NSImage else { return }
                DispatchQueue.main.async { onImage(nsImage, .paste, nil) }
            }
        }
    }
}
