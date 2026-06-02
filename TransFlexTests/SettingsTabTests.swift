import XCTest
@testable import TransFlex

final class SettingsTabTests: XCTestCase {
    func testVisibleTabs() {
        XCTAssertEqual(SettingsTab.allCases, [.general, .providers, .presets, .hotkeys])
    }
}
