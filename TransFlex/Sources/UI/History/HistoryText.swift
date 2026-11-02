import Foundation

/// The words History shows for an entry. Pure, so it is tested without a window.
enum HistoryText {
    static func cost(_ amount: Double?) -> String {
        amount.map(CostFormat.usd) ?? "price unknown"
    }

    /// The sidebar row's second line: preset (or the model, once the preset is
    /// deleted) · time · cost.
    static func subtitle(_ entry: HistoryEntry, presetName: String?, calendar: Calendar = .current) -> String {
        [presetName ?? entry.modelID, time(entry.createdAt, calendar: calendar), cost(entry.costUSD)]
            .joined(separator: " · ")
    }

    /// "Today at 10:26", "Yesterday at 18:02", else the date.
    static func when(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let day: String
        if calendar.isDate(date, inSameDayAs: now) {
            day = "Today"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday) {
            day = "Yesterday"
        } else {
            day = date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone))
        }
        return "\(day) at \(time(date, calendar: calendar))"
    }

    /// The detail header after the date: model · duration · tokens · cost.
    static func detailMeta(_ entry: HistoryEntry) -> String {
        var parts = [entry.modelID]
        if let ms = entry.durationMs {
            parts.append((Double(ms) / 1000).formatted(.number.precision(.fractionLength(1))) + " s")
        }
        if let tokens = entry.tokenCount { parts.append(CostFormat.tokens(tokens)) }
        if entry.hadImage { parts.append("image") }
        parts.append(cost(entry.costUSD))
        return parts.joined(separator: " · ")
    }

    /// The toolbar's daily total; nil hides it when nothing today has a price.
    static func today(total: Double?, unpriced: Int) -> String? {
        guard let total else { return nil }
        let base = "Today: " + CostFormat.usd(total)
        return unpriced > 0 ? base + " · \(unpriced) unpriced" : base
    }

    private static func time(_ date: Date, calendar: Calendar) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, calendar: calendar, timeZone: calendar.timeZone))
    }
}
