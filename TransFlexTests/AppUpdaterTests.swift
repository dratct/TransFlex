import XCTest
@testable import TransFlex

@MainActor
final class AppUpdaterTests: XCTestCase {
    private final class FakeDriver: UpdaterDriver {
        var canCheckForUpdates = true
        var automaticallyChecksForUpdates = true
        var calls: [String] = []
        var onUpdateFoundChange: ((Bool) -> Void)?
        var onCanCheckChange: ((Bool) -> Void)?

        func checkForUpdates() { calls.append("check") }
    }

    func testDebugInfoIsDisabled() {
        XCTAssertFalse(AppUpdater.isEnabled(infoDictionary: [:]))
        XCTAssertFalse(AppUpdater.isEnabled(infoDictionary: ["SUFeedURL": ""]))
        XCTAssertFalse(AppUpdater.isEnabled(infoDictionary: ["SUFeedURL": "  "]))
    }

    func testReleaseInfoIsEnabled() {
        let info: [String: Any] = [
            "SUFeedURL": "https://github.com/dratct/TransFlex/releases/latest/download/appcast.xml"
        ]
        XCTAssertTrue(AppUpdater.isEnabled(infoDictionary: info))
    }

    func testToggleWritesThroughToDriver() {
        let driver = FakeDriver()
        let updater = AppUpdater(driver: driver)

        updater.automaticallyChecksForUpdates = false
        XCTAssertFalse(driver.automaticallyChecksForUpdates)

        driver.automaticallyChecksForUpdates = true
        XCTAssertTrue(updater.automaticallyChecksForUpdates)
    }

    func testDriverReportSetsAndClearsUpdateFound() {
        let driver = FakeDriver()
        let updater = AppUpdater(driver: driver)
        XCTAssertFalse(updater.updateFound)

        driver.onUpdateFoundChange?(true)
        XCTAssertTrue(updater.updateFound)

        driver.onUpdateFoundChange?(false)
        XCTAssertFalse(updater.updateFound)
    }

    func testCheckForUpdatesActivatesTheAppFirst() {
        let driver = FakeDriver()
        let updater = AppUpdater(driver: driver, activateApp: { driver.calls.append("activate") })

        updater.checkForUpdates()

        XCTAssertEqual(driver.calls, ["activate", "check"])
    }

    func testCanCheckFollowsTheDriver() {
        let driver = FakeDriver()
        let updater = AppUpdater(driver: driver)
        XCTAssertTrue(updater.canCheckForUpdates)

        driver.onCanCheckChange?(false)
        XCTAssertFalse(updater.canCheckForUpdates)
    }

    func testScheduledFindOutOfFocusIsLeftToTheBadge() {
        XCTAssertTrue(AppUpdater.standardDriverShowsScheduledUpdate(immediateFocus: true))
        XCTAssertFalse(AppUpdater.standardDriverShowsScheduledUpdate(immediateFocus: false))
    }

    func testOnlyAFindSparkleLeavesUnshownRaisesTheBadge() {
        XCTAssertTrue(AppUpdater.badgesUpdate(handledByStandardDriver: false, userInitiated: false))
        XCTAssertFalse(AppUpdater.badgesUpdate(handledByStandardDriver: true, userInitiated: false))
        XCTAssertFalse(AppUpdater.badgesUpdate(handledByStandardDriver: true, userInitiated: true))
    }
}
