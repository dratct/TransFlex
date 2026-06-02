import XCTest
@testable import TransFlex

final class PopupDismissPolicyTests: XCTestCase {
    private let own = "io.aiaz.transflex"

    func test_sameBundle_doesNotHide() {
        XCTAssertFalse(PopupDismissPolicy.shouldHide(activatedBundleID: own, ownBundleID: own))
    }

    func test_allowlistMember_doesNotHide() {
        XCTAssertFalse(PopupDismissPolicy.shouldHide(activatedBundleID: "com.apple.coreauthd", ownBundleID: own))
    }

    func test_securityAgent_doesNotHide() {
        // Keychain ACL prompt ("Allow access to <item>") is presented by SecurityAgent.
        XCTAssertFalse(PopupDismissPolicy.shouldHide(activatedBundleID: "com.apple.SecurityAgent", ownBundleID: own))
    }

    func test_localAuthenticationUIService_doesNotHide() {
        // Touch ID / device password sheet is presented by LocalAuthentication.UIService.
        XCTAssertFalse(PopupDismissPolicy.shouldHide(activatedBundleID: "com.apple.LocalAuthentication.UIService", ownBundleID: own))
    }

    func test_openSavePanelService_doesNotHide() {
        // Sandboxed NSOpenPanel/NSSavePanel host process. Image-attach picker
        // activates this XPC service; popup must remain visible.
        XCTAssertFalse(PopupDismissPolicy.shouldHide(
            activatedBundleID: "com.apple.appkit.xpc.openAndSavePanelService",
            ownBundleID: own
        ))
    }

    func test_realOtherApp_hides() {
        XCTAssertTrue(PopupDismissPolicy.shouldHide(activatedBundleID: "com.apple.Safari", ownBundleID: own))
    }

    func test_nilBundle_hides() {
        XCTAssertTrue(PopupDismissPolicy.shouldHide(activatedBundleID: nil, ownBundleID: own))
    }

    func test_emptyBundle_hides() {
        XCTAssertTrue(PopupDismissPolicy.shouldHide(activatedBundleID: "", ownBundleID: own))
    }

    func test_customAllowlist_overrides() {
        let custom: Set<String> = ["com.example.custom"]
        XCTAssertFalse(PopupDismissPolicy.shouldHide(
            activatedBundleID: "com.example.custom",
            ownBundleID: own,
            allowlist: custom
        ))
    }
}
