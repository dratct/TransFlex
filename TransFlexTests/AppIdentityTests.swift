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

    func testKeychainBackendReadsDataProtectionFromInfoDictionary() {
        let identity = AppIdentity(infoDictionary: ["TransFlexKeychainBackend": "dataProtection"])

        XCTAssertEqual(identity.keychainBackend, .dataProtection)
    }

    func testKeychainBackendFallsBackToFileKeychain() {
        XCTAssertEqual(AppIdentity(infoDictionary: [:]).keychainBackend, .file)
        XCTAssertEqual(AppIdentity(infoDictionary: ["TransFlexKeychainBackend": "file"]).keychainBackend, .file)
        XCTAssertEqual(
            AppIdentity(infoDictionary: ["TransFlexKeychainBackend": "$(TRANSFLEX_KEYCHAIN_BACKEND)"]).keychainBackend,
            .file
        )
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

    func testKeychainPathSelectsFileAtBackend() {
        let identity = AppIdentity(infoDictionary: [
            "TransFlexKeychainPath": "/Users/me/Library/Keychains/transflex-dev.keychain-db",
        ])
        XCTAssertEqual(identity.keychainBackend, .fileAt(path: "/Users/me/Library/Keychains/transflex-dev.keychain-db"))
    }

    func testKeychainPasswordFileGoesWithPath() {
        let identity = AppIdentity(infoDictionary: [
            "TransFlexKeychainPath": "/tmp/dev.keychain-db",
            "TransFlexKeychainPasswordFile": "/repo/Config/Local.keychain-password",
        ])
        XCTAssertEqual(identity.keychainBackend, .fileAt(path: "/tmp/dev.keychain-db", passwordFile: "/repo/Config/Local.keychain-password"))
        XCTAssertEqual(AppIdentity(infoDictionary: [
            "TransFlexKeychainPath": "/tmp/dev.keychain-db",
            "TransFlexKeychainPasswordFile": "$(TRANSFLEX_KEYCHAIN_PASSWORD_FILE)",
        ]).keychainBackend, .fileAt(path: "/tmp/dev.keychain-db"))
    }

    func testKeychainPathWinsOverDataProtection() {
        let identity = AppIdentity(infoDictionary: [
            "TransFlexKeychainBackend": "dataProtection",
            "TransFlexKeychainPath": "/tmp/dev.keychain-db",
        ])
        XCTAssertEqual(identity.keychainBackend, .fileAt(path: "/tmp/dev.keychain-db"))
    }

    func testMissingOrUnresolvedKeychainPathKeepsBackend() {
        XCTAssertEqual(AppIdentity(infoDictionary: [:]).keychainBackend, .file)
        XCTAssertEqual(AppIdentity(infoDictionary: ["TransFlexKeychainPath": ""]).keychainBackend, .file)
        XCTAssertEqual(AppIdentity(infoDictionary: ["TransFlexKeychainPath": "$(TRANSFLEX_KEYCHAIN_PATH)"]).keychainBackend, .file)
        XCTAssertEqual(AppIdentity(infoDictionary: [
            "TransFlexKeychainBackend": "dataProtection",
            "TransFlexKeychainPath": "",
        ]).keychainBackend, .dataProtection)
    }
}
