import XCTest
@testable import TransFlex

final class SettingsTabTests: XCTestCase {
    func testVisibleTabs() {
        XCTAssertEqual(SettingsTab.allCases, [.general, .providers, .presets, .about])
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

/// Settings is a normal window: it stays open while the user works elsewhere.
@MainActor
final class SettingsWindowTests: XCTestCase {
    func testSettingsStaysVisibleWhenAnotherAppActivates() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let controller = SettingsWindowController(presetStore: PresetStore(fileURL: tempDir.appendingPathComponent("presets.json")))
        controller.show()
        defer { controller.close() }
        XCTAssertTrue(controller.isVisible)

        let finder = try XCTUnwrap(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first)
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: NSWorkspace.shared,
            userInfo: [NSWorkspace.applicationUserInfoKey: finder]
        )
        for _ in 0..<20 { try await Task.sleep(nanoseconds: 5_000_000) }

        XCTAssertTrue(controller.isVisible, "switching to another app leaves Settings open")
    }
}
