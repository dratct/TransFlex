import Foundation
import OSLog

actor ModelCatalogCache {
    struct Entry: Codable, Equatable {
        let models: [Model]
        let fetchedAt: Date
    }

    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "ModelCatalogCache")
    private let ttl: TimeInterval = 24 * 3600
    private let fileURL: URL
    private let now: () -> Date
    private var store: [String: Entry]

    init(fileURL: URL? = nil, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.now = now
        self.store = Self.loadFromDisk(at: self.fileURL)
    }

    func cached(for id: String) -> [Model]? {
        guard let entry = store[id] else { return nil }
        guard now().timeIntervalSince(entry.fetchedAt) < ttl else { return nil }
        return entry.models
    }

    func put(_ models: [Model], for id: String) {
        store[id] = Entry(models: models, fetchedAt: now())
        persist()
    }

    func invalidate(_ id: String) {
        store.removeValue(forKey: id)
        persist()
    }

    private func persist() {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(store)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            Self.logger.error("cache persist failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private static func loadFromDisk(at url: URL) -> [String: Entry] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: Entry].self, from: data)
        } catch {
            logger.error("cache decode failed: \(error.localizedDescription, privacy: .private)")
            return [:]
        }
    }

    private static func defaultFileURL() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("TransFlex/model-catalog-cache.json")
    }
}
