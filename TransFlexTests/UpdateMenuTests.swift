import XCTest
@testable import TransFlex

@MainActor
final class UpdateMenuTests: XCTestCase {
    private final class FakeDriver: UpdaterDriver {
        var canCheckForUpdates = true
        var automaticallyChecksForUpdates = true
        var onUpdateFoundChange: ((Bool) -> Void)?
        func checkForUpdates() {}
    }

    func testTitleNamesAFoundUpdate() {
        XCTAssertEqual(UpdateMenu.title(updateFound: false), "Check for Updates…")
        XCTAssertEqual(UpdateMenu.title(updateFound: true), "Update Available…")
    }

    func testAboutShowsUpdatesOnlyWithAnUpdater() {
        XCTAssertFalse(AboutTab.showsUpdates(updater: nil))
        XCTAssertTrue(AboutTab.showsUpdates(updater: AppUpdater(driver: FakeDriver())))
    }
}
