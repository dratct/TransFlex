import Foundation
import ServiceManagement
import OSLog

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "LaunchAtLoginManager")

    @Published private(set) var status: SMAppService.Status

    var isEnabled: Bool {
        status == .enabled
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    private let getStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void
    private let openLoginItemsSettings: () -> Void

    static let shared = LaunchAtLoginManager(
        getStatus: { SMAppService.mainApp.status },
        register: { try SMAppService.mainApp.register() },
        unregister: { try SMAppService.mainApp.unregister() },
        openLoginItemsSettings: { SMAppService.openSystemSettingsLoginItems() }
    )

    init(
        getStatus: @escaping () -> SMAppService.Status,
        register: @escaping () throws -> Void,
        unregister: @escaping () throws -> Void,
        openLoginItemsSettings: @escaping () -> Void = {}
    ) {
        self.status = .notRegistered
        self.getStatus = getStatus
        self.register = register
        self.unregister = unregister
        self.openLoginItemsSettings = openLoginItemsSettings
        refreshStatus()
    }

    func refreshStatus() {
        status = getStatus()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            let currentStatus = getStatus()
            if enabled {
                if currentStatus != .enabled && currentStatus != .requiresApproval {
                    try register()
                    Self.logger.info("Successfully registered launch at login.")
                }
            } else {
                if currentStatus == .enabled || currentStatus == .requiresApproval {
                    try unregister()
                    Self.logger.info("Successfully unregistered launch at login.")
                }
            }
            refreshStatus()
        } catch {
            Self.logger.error("Failed to update launch at login status to \(enabled): \(error.localizedDescription)")
            refreshStatus()
        }
    }

    func openApprovalSettings() {
        openLoginItemsSettings()
    }
}
