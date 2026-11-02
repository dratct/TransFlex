import XCTest
@testable import TransFlex

/// docs/design/mockups.html › History: what each line of the window says.
final class HistoryTextTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return c
    }()

    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 15))! }

    private func entry(cost: Double?, at date: Date, model: String = "gpt-4o") -> HistoryEntry {
        HistoryEntry(
            presetID: UUID(), providerID: "openai", modelID: model, inputText: "a", outputText: "b",
            durationMs: 800, tokenCount: 96, inputTokens: 40, outputTokens: 56, costUSD: cost, createdAt: date
        )
    }

    private func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, calendar: calendar, timeZone: calendar.timeZone))
    }

    func testCostIsDollarsToFourPlaces() {
        XCTAssertEqual(CostFormat.usd(0.0004), "$0.0004")
        XCTAssertEqual(CostFormat.usd(0.00114), "$0.0011")
        XCTAssertEqual(CostFormat.usd(1.5), "$1.5000")
    }

    func testUnknownCostSaysSo() {
        XCTAssertEqual(HistoryText.cost(nil), "price unknown")
        XCTAssertEqual(HistoryText.cost(0.0004), "$0.0004")
    }

    func testRowSubtitleIsPresetTimeCost() {
        let at = now.addingTimeInterval(-3_600)
        let row = entry(cost: 0.0004, at: at)

        XCTAssertEqual(
            HistoryText.subtitle(row, presetName: "Natural EN ↔ VI", calendar: calendar),
            "Natural EN ↔ VI · \(time(at)) · $0.0004"
        )
    }

    func testRowSubtitleFallsBackToModelWhenThePresetIsGone() {
        let at = now.addingTimeInterval(-60)
        let row = entry(cost: nil, at: at, model: "gpt-6-luna")

        XCTAssertEqual(
            HistoryText.subtitle(row, presetName: nil, calendar: calendar),
            "gpt-6-luna · \(time(at)) · price unknown"
        )
    }

    func testWhenNamesTodayAndYesterday() {
        let today = now.addingTimeInterval(-3_600)
        let yesterday = now.addingTimeInterval(-86_400)

        XCTAssertEqual(HistoryText.when(today, now: now, calendar: calendar), "Today at \(time(today))")
        XCTAssertEqual(HistoryText.when(yesterday, now: now, calendar: calendar), "Yesterday at \(time(yesterday))")
    }

    func testWhenOlderShowsTheDate() {
        let old = now.addingTimeInterval(-5 * 86_400)
        let day = old.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: calendar, timeZone: calendar.timeZone))

        XCTAssertEqual(HistoryText.when(old, now: now, calendar: calendar), "\(day) at \(time(old))")
    }

    func testDetailMetaListsModelDurationTokensCost() {
        XCTAssertEqual(HistoryText.detailMeta(entry(cost: 0.0004, at: now)), "gpt-4o · 0.8 s · 96 tokens · $0.0004")
    }

    func testTodayLabel() {
        XCTAssertEqual(HistoryText.today(total: 0.0012, unpriced: 0), "Today: $0.0012")
        XCTAssertEqual(HistoryText.today(total: 0.0012, unpriced: 2), "Today: $0.0012 · 2 unpriced")
        XCTAssertNil(HistoryText.today(total: nil, unpriced: 3))
    }
}
