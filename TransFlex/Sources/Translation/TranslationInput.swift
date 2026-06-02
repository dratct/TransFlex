import Foundation

/// Translation payload. MIME for images is detected by the provider from
/// magic bytes — callers do not pass a content type.
public enum TranslationInput: Sendable {
    case text(String)
    case image(Data, accompanyingText: String?)
}
