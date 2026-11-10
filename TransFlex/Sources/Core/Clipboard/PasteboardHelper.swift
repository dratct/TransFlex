import AppKit

/// Thin wrapper over `NSPasteboard.general` for text + image read/write.
///
/// Stateless. `changeCount` exposed so callers can detect external mutations
/// (e.g. user copied something while popup was open).
public final class PasteboardHelper {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int { pasteboard.changeCount }

    // MARK: - Text

    public func readText() -> String? {
        pasteboard.string(forType: .string)
    }

    @discardableResult
    public func writeText(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    // MARK: - Image

    public func readImage() -> NSImage? {
        let classes: [AnyClass] = [NSImage.self]
        guard let objects = pasteboard.readObjects(forClasses: classes, options: nil) as? [NSImage] else {
            return nil
        }
        return objects.first
    }

    /// The image a copied file points at, as Finder's Copy puts only the URL.
    public func readFileURLImage() -> NSImage? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first
        else { return nil }
        return NSImage(contentsOf: url)
    }

    @discardableResult
    public func writeImage(_ image: NSImage) -> Bool {
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }
}
