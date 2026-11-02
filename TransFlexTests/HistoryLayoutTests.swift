import XCTest
@testable import TransFlex

/// DESIGN.md › History: grouped by day; utility windows cascade by 24pt.
final class HistoryLayoutTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return c
    }()

    private func entry(_ date: Date) -> HistoryEntry {
        HistoryEntry(presetID: UUID(), providerID: "openai", modelID: "gpt-5", inputText: "a", outputText: "b", createdAt: date)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testEntriesFallIntoTodayYesterdayAndDatedSections() {
        let now = date(2026, 11, 2, 15)
        let entries = [date(2026, 11, 2, 10), date(2026, 11, 2, 1), date(2026, 11, 1, 23), date(2026, 10, 20, 9), date(2025, 12, 31, 9)].map(entry)
        let sections = HistoryDays.sections(entries, now: now, calendar: calendar)
        XCTAssertEqual(sections.map(\.entries.count), [2, 1, 1, 1])
        XCTAssertEqual(sections[0].title, "Today")
        XCTAssertEqual(sections[1].title, "Yesterday")
        XCTAssertFalse(sections[2].title.contains("2026"), "same year leaves the year out")
        XCTAssertTrue(sections[3].title.contains("2025"))
    }

    func testNoEntriesNoSections() {
        XCTAssertTrue(HistoryDays.sections([], calendar: calendar).isEmpty)
    }

    @MainActor
    func testUtilityWindowsCascadeDownAndRightBy24() {
        let other = NSRect(x: 100, y: 200, width: 720, height: 520)
        let origin = UtilityWindowPlacement.cascadedOrigin(size: NSSize(width: 800, height: 500), below: other)
        XCTAssertEqual(origin.x, 124)
        // Top edges: 720 for the other window, 696 for the new one.
        XCTAssertEqual(origin.y + 500, 696)
    }
}
