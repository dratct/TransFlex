import AppKit
import XCTest
@testable import TransFlex

@MainActor
final class DockVisibilityControllerTests: XCTestCase {
    func testFirstVisibleRegularWindowShowsDockIcon() {
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = DockVisibilityController(setActivationPolicy: { policies.append($0) })

        controller.showDockIcon(for: .settings)

        XCTAssertEqual(policies, [.regular])
    }

    func testDockIconStaysVisibleUntilLastRegularWindowIsHidden() {
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = DockVisibilityController(setActivationPolicy: { policies.append($0) })

        controller.showDockIcon(for: .settings)
        controller.showDockIcon(for: .history)
        controller.hideDockIcon(for: .settings)
        XCTAssertEqual(policies, [.regular])

        controller.hideDockIcon(for: .history)
        XCTAssertEqual(policies, [.regular, .accessory])
    }

    func testDuplicateShowDoesNotTogglePolicyAgain() {
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = DockVisibilityController(setActivationPolicy: { policies.append($0) })

        controller.showDockIcon(for: .settings)
        controller.showDockIcon(for: .settings)
        controller.hideDockIcon(for: .settings)

        XCTAssertEqual(policies, [.regular, .accessory])
    }

    func testHidingUnknownOwnerDoesNothing() {
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = DockVisibilityController(setActivationPolicy: { policies.append($0) })

        controller.hideDockIcon(for: .settings)

        XCTAssertEqual(policies, [])
    }
}
