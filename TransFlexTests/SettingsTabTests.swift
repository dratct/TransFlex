import XCTest
@testable import TransFlex

final class SettingsTabTests: XCTestCase {
    func testVisibleTabs() {
        XCTAssertEqual(SettingsTab.allCases, [.general, .providers, .presets, .hotkeys, .about])
    }

    func testAboutInfo() {
        XCTAssertEqual(AboutInfo.repositoryURL.absoluteString, "https://github.com/dratct/transflex")
        XCTAssertEqual(AboutInfo.licenseURL.absoluteString, "https://github.com/dratct/transflex/blob/main/LICENSE")
        XCTAssertEqual(AboutInfo.donateURL.absoluteString, "https://paypal.me/truongtc1109")
        XCTAssertEqual(AboutInfo.licenseName, "MIT License")
    }

    func testAboutVersionTextOmitsBuildNumber() {
        XCTAssertEqual(AboutInfo.versionText(version: "0.1.0", build: "1"), "Version 0.1.0")
    }
}
