import XCTest
import ServiceManagement
@testable import TransFlex

@MainActor
final class LaunchAtLoginManagerTests: XCTestCase {
    func testEnabledStatusReflected() {
        var status: SMAppService.Status = .notRegistered
        let manager = LaunchAtLoginManager(
            getStatus: { status },
            register: { status = .enabled },
            unregister: { status = .notRegistered }
        )

        XCTAssertFalse(manager.isEnabled)

        manager.setEnabled(true)
        XCTAssertTrue(manager.isEnabled)
        XCTAssertEqual(status, .enabled)

        manager.setEnabled(false)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertEqual(status, .notRegistered)
    }

    func testFailedRegisterRevertsState() {
        struct DummyError: Error {}
        var status: SMAppService.Status = .notRegistered
        let manager = LaunchAtLoginManager(
            getStatus: { status },
            register: { throw DummyError() },
            unregister: { status = .notRegistered }
        )

        XCTAssertFalse(manager.isEnabled)
        manager.setEnabled(true)
        XCTAssertFalse(manager.isEnabled) // Reverted back because register failed
    }

    func testRegisterRefreshesRequiresApprovalStatus() {
        var status: SMAppService.Status = .notRegistered
        let manager = LaunchAtLoginManager(
            getStatus: { status },
            register: { status = .requiresApproval },
            unregister: { status = .notRegistered }
        )

        manager.setEnabled(true)

        XCTAssertFalse(manager.isEnabled)
    }

    func testRequiresApprovalStatusExposedForUI() {
        var status: SMAppService.Status = .requiresApproval
        let manager = LaunchAtLoginManager(
            getStatus: { status },
            register: { status = .enabled },
            unregister: { status = .notRegistered }
        )

        XCTAssertTrue(manager.needsApproval)
        status = .enabled
        manager.refreshStatus()
        XCTAssertFalse(manager.needsApproval)
    }

    func testOpenApprovalSettingsUsesInjectedAction() {
        var didOpenSettings = false
        let manager = LaunchAtLoginManager(
            getStatus: { .requiresApproval },
            register: {},
            unregister: {},
            openLoginItemsSettings: { didOpenSettings = true }
        )

        manager.openApprovalSettings()

        XCTAssertTrue(didOpenSettings)
    }

    func testFailedUnregisterRevertsState() {
        struct DummyError: Error {}
        var status: SMAppService.Status = .enabled
        let manager = LaunchAtLoginManager(
            getStatus: { status },
            register: { status = .enabled },
            unregister: { throw DummyError() }
        )

        XCTAssertTrue(manager.isEnabled)
        manager.setEnabled(false)
        XCTAssertTrue(manager.isEnabled) // Reverted back because unregister failed
    }
}
