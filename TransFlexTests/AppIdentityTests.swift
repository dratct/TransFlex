import XCTest
@testable import TransFlex

final class AppIdentityTests: XCTestCase {
    func testFallbackIdentityMatchesReleaseApp() {
        let identity = AppIdentity(infoDictionary: [:])

        XCTAssertEqual(identity.bundleIdentifier, "io.aiaz.transflex")
        XCTAssertEqual(identity.displayName, "TransFlex")
        XCTAssertEqual(identity.applicationSupportDirectoryName, "TransFlex")
        XCTAssertEqual(identity.keychainService, "io.aiaz.transflex")
    }

    func testDebugIdentityCanBeReadFromInfoDictionary() {
        let identity = AppIdentity(infoDictionary: [
            "CFBundleIdentifier": "io.aiaz.transflex.dev",
            "CFBundleDisplayName": "TransFlex Dev",
            "TransFlexApplicationSupportDirectoryName": "TransFlexDev",
            "TransFlexKeychainService": "io.aiaz.transflex.dev",
        ])

        XCTAssertEqual(identity.bundleIdentifier, "io.aiaz.transflex.dev")
        XCTAssertEqual(identity.displayName, "TransFlex Dev")
        XCTAssertEqual(identity.applicationSupportDirectoryName, "TransFlexDev")
        XCTAssertEqual(identity.keychainService, "io.aiaz.transflex.dev")
    }

    func testKeychainServiceDefaultsToResolvedBundleIdentifier() {
        let identity = AppIdentity(infoDictionary: [
            "CFBundleIdentifier": "io.aiaz.transflex.dev",
        ])

        XCTAssertEqual(identity.keychainService, "io.aiaz.transflex.dev")
    }

    func testUnresolvedBuildSettingPlaceholdersFallBackToReleaseIdentity() {
        let identity = AppIdentity(infoDictionary: [
            "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
            "CFBundleDisplayName": "$(TRANSFLEX_DISPLAY_NAME)",
            "TransFlexApplicationSupportDirectoryName": "$(TRANSFLEX_APP_SUPPORT_DIR)",
            "TransFlexKeychainService": "$(TRANSFLEX_KEYCHAIN_SERVICE)",
        ])

        XCTAssertEqual(identity.bundleIdentifier, "io.aiaz.transflex")
        XCTAssertEqual(identity.displayName, "TransFlex")
        XCTAssertEqual(identity.applicationSupportDirectoryName, "TransFlex")
        XCTAssertEqual(identity.keychainService, "io.aiaz.transflex")
    }

    func testApplicationSupportDirectoryUsesIdentitySpecificFolder() {
        let identity = AppIdentity(infoDictionary: [
            "TransFlexApplicationSupportDirectoryName": "TransFlexDev",
        ])
        let baseURL = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)

        XCTAssertEqual(
            identity.applicationSupportDirectory(baseURL: baseURL).path,
            "/tmp/Application Support/TransFlexDev"
        )
    }
}
