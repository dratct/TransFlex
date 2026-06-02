import Foundation

public struct ModelPrice: Sendable, Equatable {
    public let inputPer1k: Double
    public let outputPer1k: Double
    public let imagePer1k: Double

    public init(inputPer1k: Double, outputPer1k: Double, imagePer1k: Double = 0) {
        self.inputPer1k = inputPer1k
        self.outputPer1k = outputPer1k
        self.imagePer1k = imagePer1k
    }
}

/// Hardcoded provider prices in USD per 1k tokens. Verify against each
/// provider's pricing page on every plan-update cycle — silent drift here
/// turns the cost estimate into a lie.
public enum CostTable {
    public static let prices: [String: ModelPrice] = [
        "gpt-4o-mini":         .init(inputPer1k: 0.00015, outputPer1k: 0.0006,  imagePer1k: 0.0007),
        "gpt-4o":              .init(inputPer1k: 0.0025,  outputPer1k: 0.01,    imagePer1k: 0.003),
        "gpt-4-turbo":         .init(inputPer1k: 0.01,    outputPer1k: 0.03,    imagePer1k: 0.003),

        "claude-3-5-sonnet-latest": .init(inputPer1k: 0.003,  outputPer1k: 0.015,  imagePer1k: 0.0048),
        "claude-3-5-haiku-latest":  .init(inputPer1k: 0.0008, outputPer1k: 0.004,  imagePer1k: 0.0008),
        "claude-3-opus-latest":     .init(inputPer1k: 0.015,  outputPer1k: 0.075,  imagePer1k: 0.024),

        "gemini-2.0-flash":    .init(inputPer1k: 0.0001,  outputPer1k: 0.0004,  imagePer1k: 0.0001),
        "gemini-1.5-pro":      .init(inputPer1k: 0.00125, outputPer1k: 0.005,   imagePer1k: 0.00125),
        "gemini-1.5-flash":    .init(inputPer1k: 0.000075, outputPer1k: 0.0003, imagePer1k: 0.000075),
    ]

    public static func price(for model: String) -> ModelPrice? {
        prices[model]
    }

    /// Returns a USD estimate, or `nil` when the model has no known price.
    /// `nil` is distinct from a real `0` — callers must render it as "unknown",
    /// not "$0.00". Image cost is a flat per-image surcharge from `imagePer1k`.
    public static func estimate(
        model: String,
        input: Int,
        output: Int,
        hadImage: Bool
    ) -> Double? {
        guard let p = prices[model] else { return nil }
        let textCost = (Double(input) * p.inputPer1k + Double(output) * p.outputPer1k) / 1000.0
        let imageCost = hadImage ? p.imagePer1k : 0
        return textCost + imageCost
    }
}
