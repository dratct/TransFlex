import Foundation

struct OpenAICompatSecretStore {
    private let keychain: KeychainStore

    init(keychain: KeychainStore) {
        self.keychain = keychain
    }

    func apiKey(for instanceId: String) throws -> String {
        try keychain.get(apiKeyKey(for: instanceId)) ?? ""
    }

    func hasAPIKey(for instanceId: String) -> Bool {
        keychain.exists(apiKeyKey(for: instanceId))
    }

    func setAPIKey(_ apiKey: String, for instanceId: String) throws {
        try keychain.set(apiKey.isEmpty ? nil : apiKey, forKey: apiKeyKey(for: instanceId))
    }

    func headerValue(for instanceId: String, headerName: String) throws -> String {
        try keychain.get(headerKey(instanceId: instanceId, headerName: headerName)) ?? ""
    }

    func headers(for instance: OpenAICompatInstance) throws -> [String: String] {
        var headers: [String: String] = [:]
        for name in instance.extraHeaderNames {
            let value = try headerValue(for: instance.instanceId, headerName: name)
            if !value.isEmpty {
                headers[name] = value
            }
        }
        return headers
    }

    func setHeaders(_ headers: [String: String], for instanceId: String) throws {
        for (name, value) in headers {
            try keychain.set(value.isEmpty ? nil : value, forKey: headerKey(instanceId: instanceId, headerName: name))
        }
    }

    func replaceHeaders(
        _ headers: [String: String],
        previousHeaderNames: [String],
        for instanceId: String
    ) throws {
        for name in previousHeaderNames where headers[name] == nil {
            try keychain.delete(headerKey(instanceId: instanceId, headerName: name))
        }
        try setHeaders(headers, for: instanceId)
    }

    func clear(instanceId: String, headerNames: [String]) throws {
        try keychain.delete(apiKeyKey(for: instanceId))
        for name in headerNames {
            try keychain.delete(headerKey(instanceId: instanceId, headerName: name))
        }
    }

    func cloudAPIKey(for providerID: String) throws -> String {
        try keychain.get("provider.\(providerID).apiKey") ?? ""
    }

    func setCloudAPIKey(_ key: String, for providerID: String) throws {
        try keychain.set(key.isEmpty ? nil : key, forKey: "provider.\(providerID).apiKey")
    }

    private func apiKeyKey(for instanceId: String) -> String {
        "provider.openai-compatible.\(instanceId).apiKey"
    }

    private func headerKey(instanceId: String, headerName: String) -> String {
        "provider.openai-compatible.\(instanceId).header.\(headerName.lowercased())"
    }
}
