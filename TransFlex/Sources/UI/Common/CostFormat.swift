import Foundation

/// One way to write a cost everywhere in the app: "$0.0004".
enum CostFormat {
    static func usd(_ amount: Double) -> String {
        "$" + String(format: "%.4f", amount)
    }
}
