import Foundation

/// One way to write a cost everywhere in the app: "96 tokens · $0.0004".
enum CostFormat {
    static func usd(_ amount: Double) -> String {
        "$" + String(format: "%.4f", amount)
    }

    /// Input and output together, the count History stores.
    static func tokens(_ count: Int) -> String {
        "\(count.formatted()) tokens"
    }
}
