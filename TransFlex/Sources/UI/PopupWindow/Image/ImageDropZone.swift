import SwiftUI

/// Drop target and paste handler for image attachment. Wraps content
/// and intercepts image drops + Cmd-V when pasteboard has image data.
struct ImageDropZone<Content: View>: View {
    let onImage: (NSImage, ImageSource, Int?) -> Void
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
                let size: Int
                do {
                    size = try ImageMetadata.fileSizeBytes(of: url)
                } catch {
                    return
                }
                guard size <= ImageTranslationCoordinator.maxFileSizeBytes else { return }
                if let pixels = ImageMetadata.pixelSize(of: url),
                   pixels.width * pixels.height > ImageTranslationCoordinator.maxPixelCount {
                    return
                }
                guard let nsImage = NSImage(contentsOf: url) else { return }
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
