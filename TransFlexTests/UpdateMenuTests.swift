import XCTest
@testable import TransFlex

@MainActor
final class UpdateMenuTests: XCTestCase {
    private final class FakeDriver: UpdaterDriver {
        var canCheckForUpdates = true
        var automaticallyChecksForUpdates = true
        var onUpdateFoundChange: ((Bool) -> Void)?
        var onCanCheckChange: ((Bool) -> Void)?
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

    func testEveryStatusMenuSymbolResolvesToAnImage() {
        for symbol in StatusMenuSymbol.allCases {
            XCTAssertNotNil(
                NSImage(systemSymbolName: symbol.rawValue, accessibilityDescription: nil),
                "No SF Symbol named \(symbol.rawValue)"
            )
        }
    }

    func testEveryStatusMenuItemAsksToKeepItsImageVisible() throws {
        let menu = try XCTUnwrap(StatusBarController(updater: AppUpdater(driver: FakeDriver())).menu)
        let items = menu.items.filter { !$0.isSeparatorItem }
        XCTAssertEqual(items.count, StatusMenuSymbol.allCases.count)
        guard items[0].responds(to: NSSelectorFromString("setPreferredImageVisibility:")) else {
            throw XCTSkip("Before macOS 27 a menu item always shows its image")
        }
        for item in items {
            XCTAssertNotNil(item.image, item.title)
            XCTAssertEqual(
                item.value(forKey: "preferredImageVisibility") as? Int, 1,
                "\(item.title) leaves its image to macOS 27, which hides it"
            )
        }
    }

    // Needs the macOS 27 SDK, which is where the enum is declared.
    #if compiler(>=6.4)
    func testVisibleIsTheValueTheAppSetsByKey() throws {
        guard #available(macOS 27.0, *) else { throw XCTSkip("NSMenuItem.ImageVisibility is macOS 27") }
        XCTAssertEqual(NSMenuItem.ImageVisibility.visible.rawValue, MenuItemImages.visible)
    }
    #endif
}
