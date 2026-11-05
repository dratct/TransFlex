import XCTest
@testable import TransFlex

@MainActor
final class AppUpdaterTests: XCTestCase {
    private final class FakeDriver: UpdaterDriver {
        var canCheckForUpdates = true
        var automaticallyChecksForUpdates = true
        var checkCount = 0
        var onUpdateFoundChange: ((Bool) -> Void)?

        func checkForUpdates() { checkCount += 1 }
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

    func testCheckForUpdatesAsksDriver() {
        let driver = FakeDriver()
        let updater = AppUpdater(driver: driver, activateApp: {})

        updater.checkForUpdates()

        XCTAssertEqual(driver.checkCount, 1)
    }
}
