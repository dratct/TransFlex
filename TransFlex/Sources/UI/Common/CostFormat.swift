import Foundation

/// One way to write a cost everywhere in the app: "96 tokens · $0.0004".
enum CostFormat {
    static func usd(_ amount: Double) -> String {
        "$" + String(format: "%.4f", amount)
    }

    /// A model with no price in the table says so rather than showing $0.
    static func usd(_ amount: Double?) -> String {
        amount.map(usd) ?? "price unknown"
    }

    /// Input and output together, the count History stores.
    static func tokens(_ count: Int) -> String {
        "\(count.formatted()) tokens"
    }
}
