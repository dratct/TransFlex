import AppKit
import Foundation

enum ValidationResult {
    case ok(ImageInput)
    case tooLarge(reason: String)
    case unsupportedFormat
}

enum ImageTranslationError: LocalizedError {
    case providerUnavailable
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .providerUnavailable:
            return "This provider cannot process this image."
        case .processingFailed:
            return "Could not process the image."
        }
    }
}

@MainActor
final class ImageTranslationCoordinator {
    static let costConfirmationThreshold: Double = 0.05

    nonisolated static let maxFileSizeBytes = 20 * 1024 * 1024
    nonisolated static let maxPixelCount = 50_000_000

    static func validateAndWrap(
        _ image: NSImage,
        source: ImageSource,
        fileSizeBytes: Int? = nil
    ) -> ValidationResult {
        if let bytes = fileSizeBytes, bytes > maxFileSizeBytes {
            return .tooLarge(reason: "Image is too large (max 20 MB).")
        }

        let pixelSize = ImageMetadata.pixelSize(of: image)
        let pixels = (pixelSize?.width ?? Int(image.size.width)) * (pixelSize?.height ?? Int(image.size.height))
        if pixels > maxPixelCount {
            return .tooLarge(reason: "Image is too large (max 50 megapixels).")
        }

        return .ok(ImageInput(source: image, sourceType: source))
    }

    static func preflightCost(imageInput: ImageInput, model: String) -> Double? {
        let estimatedTokens = 768
        return CostTable.estimate(model: model, input: estimatedTokens, output: 0, hadImage: true)
    }

    static func buildInput(
        imageInput: ImageInput,
        providerID: String,
        accompanyingText: String
    ) throws -> TranslationInput {
        let provider = try ProviderRegistry.shared.provider(for: providerID)
        guard let processed = imageInput.processedData(maxDim: provider.maxImageDim) else {
            throw ImageTranslationError.processingFailed
        }

        let trimmed = accompanyingText.trimmingCharacters(in: .whitespacesAndNewlines)
        return .image(processed.data, accompanyingText: trimmed.isEmpty ? nil : trimmed)
    }
}
