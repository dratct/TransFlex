import Foundation
import OSLog

struct ProvidersConfig: Codable, Equatable {
    var openAICompatInstances: [OpenAICompatInstance]
}

/// Non-secret provider metadata (instance name, baseURL, defaultModel, custom header names).
/// Secrets live exclusively in Keychain. Atomic JSON write prevents corruption on crash.
@MainActor
final class ProvidersStore: ObservableObject {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "ProvidersStore")

    @Published private(set) var config: ProvidersConfig

    private let fileURL: URL
    private let secrets: OpenAICompatSecretStore

    init(fileURL: URL? = nil, keychain: KeychainStore = KeychainStore()) {
        let resolved = fileURL ?? Self.defaultFileURL()
        self.fileURL = resolved
        self.secrets = OpenAICompatSecretStore(keychain: keychain)
        self.config = Self.loadFromDisk(at: resolved)
        migrateLegacyHeaderValues()
    }

    // MARK: - OpenAI-Compat CRUD

    func addCompatInstance(_ instance: OpenAICompatInstance, apiKey: String) throws {
        guard !config.openAICompatInstances.contains(where: { $0.instanceId == instance.instanceId }) else {
            throw ProviderError.invalidConfiguration("Instance '\(instance.displayName)' already exists")
        }
        let oldConfig = config
        do {
            try secrets.setAPIKey(apiKey, for: instance.instanceId)
            try secrets.setHeaders(instance.extraHeaders, for: instance.instanceId)

            let stored = storageInstance(from: instance)
            config.openAICompatInstances.append(stored)
            try persist()
            try registerInRegistry(instance: stored)
        } catch {
            config = oldConfig
            clearCompatSecrets(instanceId: instance.instanceId, headerNames: instance.extraHeaderNames)
            throw error
        }
    }

    func updateCompatInstance(_ instance: OpenAICompatInstance, apiKey: String?) throws {
        guard let idx = config.openAICompatInstances.firstIndex(where: { $0.instanceId == instance.instanceId }) else {
            return
        }
        let oldConfig = config
        let oldInstance = config.openAICompatInstances[idx]
        let oldAPIKey = try secrets.apiKey(for: instance.instanceId)
        let oldHeaders = try secrets.headers(for: oldInstance)
        do {
            if let apiKey {
                try secrets.setAPIKey(apiKey, for: instance.instanceId)
            }
            try secrets.replaceHeaders(
                instance.extraHeaders,
                previousHeaderNames: oldInstance.extraHeaderNames,
                for: instance.instanceId
            )

            let stored = storageInstance(from: instance)
            config.openAICompatInstances[idx] = stored
            try persist()
            try registerInRegistry(instance: stored)
        } catch {
            config = oldConfig
            restoreCompatSecrets(
                instanceId: instance.instanceId,
                apiKey: oldAPIKey,
                headers: oldHeaders,
                clearing: oldInstance.extraHeaderNames + instance.extraHeaderNames
            )
            throw error
        }
    }

    func deleteCompatInstance(_ instanceId: String) throws {
        guard let instance = config.openAICompatInstances.first(where: { $0.instanceId == instanceId }) else { return }
        let oldConfig = config
        let oldAPIKey = try secrets.apiKey(for: instanceId)
        let oldHeaders = try secrets.headers(for: instance)
        do {
            try secrets.clear(instanceId: instanceId, headerNames: instance.extraHeaderNames)

            config.openAICompatInstances.removeAll { $0.instanceId == instanceId }
            try persist()
        } catch {
            config = oldConfig
            restoreCompatSecrets(
                instanceId: instanceId,
                apiKey: oldAPIKey,
                headers: oldHeaders,
                clearing: instance.extraHeaderNames
            )
            throw error
        }
        ProviderRegistry.shared.unregisterCompatInstance(instanceId)
    }

    func compatAPIKey(for instanceId: String) -> String {
        do {
            return try secrets.apiKey(for: instanceId)
        } catch {
            Self.logger.error("compat api key read failed: \(error.localizedDescription, privacy: .private)")
            return ""
        }
    }

    func hasCompatAPIKey(for instanceId: String) -> Bool {
        secrets.hasAPIKey(for: instanceId)
    }

    func compatExtraHeaderValue(for instanceId: String, headerName: String) -> String {
        do {
            return try secrets.headerValue(for: instanceId, headerName: headerName)
        } catch {
            Self.logger.error("compat header read failed: \(error.localizedDescription, privacy: .private)")
            return ""
        }
    }

    func compatExtraHeaders(for instanceId: String) -> [String: String] {
        guard let instance = config.openAICompatInstances.first(where: { $0.instanceId == instanceId }) else {
            return [:]
        }
        do {
            return try secrets.headers(for: instance)
        } catch {
            Self.logger.error("compat headers read failed: \(error.localizedDescription, privacy: .private)")
            return [:]
        }
    }

    /// Registers all persisted compat instances into the shared registry.
    func registerAllWithRegistry() {
        for instance in config.openAICompatInstances {
            do {
                try registerInRegistry(instance: instance)
            } catch {
                Self.logger.error("provider registry failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    // MARK: - Cloud provider API key

    func cloudAPIKey(for providerID: String) -> String {
        do {
            return try secrets.cloudAPIKey(for: providerID)
        } catch {
            Self.logger.error("cloud api key read failed: \(error.localizedDescription, privacy: .private)")
            return ""
        }
    }

    func setCloudAPIKey(_ key: String, for providerID: String) throws {
        try secrets.setCloudAPIKey(key, for: providerID)
    }

    // MARK: - Private

    private func registerInRegistry(instance: OpenAICompatInstance) throws {
        try ProviderRegistry.shared.registerCompatInstance(runtimeInstance(from: instance))
    }

    private func storageInstance(from instance: OpenAICompatInstance) -> OpenAICompatInstance {
        OpenAICompatInstance(
            instanceId: instance.instanceId,
            displayName: instance.displayName,
            baseURL: instance.baseURL,
            defaultModel: instance.defaultModel,
            extraHeaderNames: instance.extraHeaderNames,
            extraHeaders: [:],
            inputPricePer1k: instance.inputPricePer1k,
            outputPricePer1k: instance.outputPricePer1k
        )
    }

    private func runtimeInstance(from instance: OpenAICompatInstance) -> OpenAICompatInstance {
        OpenAICompatInstance(
            instanceId: instance.instanceId,
            displayName: instance.displayName,
            baseURL: instance.baseURL,
            defaultModel: instance.defaultModel,
            extraHeaderNames: instance.extraHeaderNames,
            extraHeaders: compatExtraHeaders(for: instance.instanceId),
            inputPricePer1k: instance.inputPricePer1k,
            outputPricePer1k: instance.outputPricePer1k
        )
    }

    private func clearCompatSecrets(instanceId: String, headerNames: [String]) {
        do {
            try secrets.clear(instanceId: instanceId, headerNames: headerNames)
        } catch {
            Self.logger.error("compat secret cleanup failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func restoreCompatSecrets(
        instanceId: String,
        apiKey: String,
        headers: [String: String],
        clearing headerNames: [String]
    ) {
        do {
            try secrets.clear(instanceId: instanceId, headerNames: Array(Set(headerNames)))
            try secrets.setAPIKey(apiKey, for: instanceId)
            try secrets.setHeaders(headers, for: instanceId)
        } catch {
            Self.logger.error("compat secret rollback failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func migrateLegacyHeaderValues() {
        var changed = false
        for instance in config.openAICompatInstances where !instance.extraHeaders.isEmpty {
            do {
                try secrets.setHeaders(instance.extraHeaders, for: instance.instanceId)
                changed = true
            } catch {
                Self.logger.error("header secret migration failed: \(error.localizedDescription, privacy: .private)")
            }
        }
        guard changed else { return }
        config.openAICompatInstances = config.openAICompatInstances.map(storageInstance)
        do {
            try persist()
        } catch {
            Self.logger.error("providers.json migration persist failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func persist() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func loadFromDisk(at url: URL) -> ProvidersConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ProvidersConfig(openAICompatInstances: [])
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ProvidersConfig.self, from: data)
        } catch {
            logger.error("providers.json decode failed: \(error.localizedDescription, privacy: .private)")
            return ProvidersConfig(openAICompatInstances: [])
        }
    }

    private static func defaultFileURL() -> URL {
        let base: URL
        do {
            base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            logger.error("application support lookup failed: \(error.localizedDescription, privacy: .private)")
            base = FileManager.default.temporaryDirectory
        }
        return base.appendingPathComponent("TransFlex/providers.json")
    }
}
