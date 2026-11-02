import Foundation

/// Splits History entries into day sections ("Today", "Yesterday", then the
/// date), keeping the order they came in. Pure, so it is tested without a window.
enum HistoryDays {
    struct Section: Equatable {
        let title: String
        let entries: [HistoryEntry]
    }

    static func sections(_ entries: [HistoryEntry], now: Date = Date(), calendar: Calendar = .current) -> [Section] {
        var result: [Section] = []
        var currentDay: Date?
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            if day == currentDay, let last = result.popLast() {
                result.append(Section(title: last.title, entries: last.entries + [entry]))
            } else {
                result.append(Section(title: title(for: day, now: now, calendar: calendar), entries: [entry]))
                currentDay = day
            }
        }
        return result
    }

    static func title(for day: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        var style = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        if calendar.component(.year, from: day) != calendar.component(.year, from: now) {
            style = style.year()
        }
        return day.formatted(style)
    }
}
