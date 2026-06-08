import Foundation

struct AppIdentity {
    private static let fallbackBundleIdentifier = "io.aiaz.transflex"
    private static let fallbackDisplayName = "TransFlex"
    private static let fallbackApplicationSupportDirectoryName = "TransFlex"

    let bundleIdentifier: String
    let displayName: String
    let applicationSupportDirectoryName: String
    let keychainService: String

    static var current: AppIdentity {
        AppIdentity(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) {
        let bundleIdentifier = Self.value(
            for: "CFBundleIdentifier",
            in: infoDictionary
        ) ?? Self.fallbackBundleIdentifier
        let displayName = Self.value(
            for: "CFBundleDisplayName",
            in: infoDictionary
        ) ?? Self.value(
            for: "CFBundleName",
            in: infoDictionary
        ) ?? Self.fallbackDisplayName

        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.applicationSupportDirectoryName = Self.value(
            for: "TransFlexApplicationSupportDirectoryName",
            in: infoDictionary
        ) ?? Self.fallbackApplicationSupportDirectoryName
        self.keychainService = Self.value(
            for: "TransFlexKeychainService",
            in: infoDictionary
        ) ?? bundleIdentifier
    }

    func applicationSupportDirectory(baseURL: URL) -> URL {
        baseURL.appendingPathComponent(applicationSupportDirectoryName, isDirectory: true)
    }

    private static func value(for key: String, in infoDictionary: [String: Any]) -> String? {
        guard let raw = infoDictionary[key] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }
}
