import Foundation
import OSLog

/// Validation failures rejected before persisting preset changes.
public enum PresetStoreError: Error, Equatable {
    case duplicateHotkey(KeyCombo, presetNames: [String])
}

extension PresetStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .duplicateHotkey(_, let names):
            return "Hotkey conflict between presets: \(names.joined(separator: ", "))."
        }
    }
}

/// JSON-backed preset persistence. Atomic writes via temp-file + rename so a
/// crash mid-save can never produce a partial file. Decode failures move the
/// corrupt file aside and start with an empty in-memory list — caller decides
/// whether to re-seed builtins.
@MainActor
public final class PresetStore: ObservableObject {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "PresetStore")

    @Published public private(set) var presets: [Preset]

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil) {
        let resolved = fileURL ?? Self.defaultFileURL()
        self.fileURL = resolved

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        self.presets = Self.loadFromDisk(at: resolved, decoder: dec)
    }

    public func add(_ preset: Preset) throws {
        var next = presets
        next.append(preset)
        try replaceAll(with: next)
    }

    public func append(contentsOf newPresets: [Preset]) throws {
        guard !newPresets.isEmpty else { return }
        var next = presets
        next.append(contentsOf: newPresets)
        try replaceAll(with: next)
    }

    public func update(_ preset: Preset) throws {
        guard let idx = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        var next = presets
        var bumped = preset
        bumped.updatedAt = Date()
        next[idx] = bumped
        try replaceAll(with: next)
    }

    public func delete(id: UUID) throws {
        let next = presets.filter { $0.id != id }
        guard next.count != presets.count else { return }
        try replaceAll(with: next)
    }

    public func replaceAll(with newPresets: [Preset]) throws {
        try validateHotkeyUniqueness(newPresets)
        try persist(newPresets)
        presets = newPresets
    }



    /// Returns true when the preset references a provider id no longer
    /// resolvable by `registry`. Used by Settings UI for an `⚠ provider
    /// missing` badge and by `TranslationService` to short-circuit before
    /// making a request.
    public func isOrphaned(_ preset: Preset, in registry: ProviderRegistry) -> Bool {
        (try? registry.provider(for: preset.providerID)) == nil
    }

    // MARK: - Validation

    private func validateHotkeyUniqueness(_ presets: [Preset]) throws {
        var seen: [KeyCombo: [String]] = [:]
        for preset in presets {
            guard let combo = preset.hotkey else { continue }
            seen[combo, default: []].append(preset.name)
        }
        if let (combo, names) = seen.first(where: { $0.value.count > 1 }) {
            throw PresetStoreError.duplicateHotkey(combo, presetNames: names)
        }
    }

    // MARK: - Persistence

    private func persist(_ items: [Preset]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func loadFromDisk(at url: URL, decoder: JSONDecoder) -> [Preset] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([Preset].self, from: data)
        } catch {
            logger.error("decode failed; backing up corrupt file: \(error.localizedDescription, privacy: .private)")
            backupCorruptFile(at: url)
            return []
        }
    }

    private static func backupCorruptFile(at url: URL) {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = url.appendingPathExtension("bak.\(stamp)")
        do {
            try FileManager.default.moveItem(at: url, to: backup)
        } catch {
            logger.error("backup move failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private static func defaultFileURL() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("TransFlex/presets.json")
    }
}
