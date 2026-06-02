import Foundation

/// Resolves a `providerID` (string form used in presets / settings) to a
/// concrete `LLMProvider`. Cloud IDs are flat (`"openai"`, `"anthropic"`,
/// `"gemini"`); OpenAI-compat instances use `"openai-compatible:<instanceId>"`
/// so a single setting can address multiple user-configured endpoints.
public final class ProviderRegistry: @unchecked Sendable {
    public static let shared = ProviderRegistry()

    private static let allowedSchemes: Set<String> = ["http", "https"]
    private static let localHTTPHosts: Set<String> = ["localhost", "127.0.0.1", "::1"]

    private let lock = NSLock()
    private let cloud: [String: LLMProvider]
    private var compatInstances: [String: OpenAICompatInstance] = [:]
    private var compatProviders: [String: OpenAICompatibleProvider] = [:]
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
        self.cloud = [
            "openai": OpenAIProvider(session: session),
            "anthropic": AnthropicProvider(session: session),
            "gemini": GeminiProvider(session: session),
        ]
    }

    public func registerCompatInstance(_ instance: OpenAICompatInstance) throws {
        try Self.validateBaseURL(instance.baseURL)
        lock.lock()
        defer { lock.unlock() }
        compatInstances[instance.instanceId] = instance
        compatProviders[instance.instanceId] = OpenAICompatibleProvider(
            instance: instance,
            session: session
        )
    }

    public func unregisterCompatInstance(_ instanceId: String) {
        lock.lock()
        defer { lock.unlock() }
        compatInstances.removeValue(forKey: instanceId)
        compatProviders.removeValue(forKey: instanceId)
    }

    public func provider(for id: String) throws -> LLMProvider {
        if let cloud = cloud[id] { return cloud }
        if id.hasPrefix("openai-compatible:") {
            let instanceId = String(id.dropFirst("openai-compatible:".count))
            lock.lock()
            defer { lock.unlock() }
            if let provider = compatProviders[instanceId] { return provider }
        }
        throw ProviderError.unknownProvider(id: id)
    }

    public func compatInstance(_ instanceId: String) -> OpenAICompatInstance? {
        lock.lock()
        defer { lock.unlock() }
        return compatInstances[instanceId]
    }

    /// All resolvable provider IDs — cloud + registered compat instances.
    public var allProviderIDs: [String] {
        lock.lock()
        defer { lock.unlock() }
        let compatIDs = compatInstances.keys.map { "openai-compatible:\($0)" }
        return cloud.keys.sorted() + compatIDs.sorted()
    }

    static func validateBaseURL(_ url: URL) throws {
        let scheme = url.scheme?.lowercased() ?? ""
        guard allowedSchemes.contains(scheme) else {
            throw ProviderError.invalidConfiguration("baseURL scheme must be http or https; got '\(url.scheme ?? "<none>")'")
        }
        guard scheme != "http" || isLocalHTTPURL(url) else {
            throw ProviderError.invalidConfiguration("http baseURL is allowed only for localhost")
        }
    }

    private static func isLocalHTTPURL(_ url: URL) -> Bool {
        guard let host = url.host(percentEncoded: false)?.lowercased() else { return false }
        return localHTTPHosts.contains(host)
    }
}
