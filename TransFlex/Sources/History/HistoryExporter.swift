import AppKit
import Foundation
import OSLog

public enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case markdown = "Markdown"
}

@MainActor
final class HistoryExporter {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "HistoryExporter")

    static func export(entries: [HistoryEntry], as format: ExportFormat) {
        guard let window = NSApp.keyWindow else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = format.contentType
        panel.nameFieldStringValue = "transflex-history.\(format.fileExtension)"
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try format.encode(entries)
                try data.write(to: url, options: .atomic)
            } catch {
                Self.logger.error("Export failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }
}

extension ExportFormat {
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .markdown: return "md"
        }
    }

    var contentType: [UTType] {
        switch self {
        case .json: return [.json]
        case .markdown: return [.plainText]
        }
    }

    func encode(_ entries: [HistoryEntry]) throws -> Data {
        switch self {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(entries)
        case .markdown:
            var md = "# TransFlex Translation History\n\n"
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            for entry in entries {
                let date = formatter.string(from: entry.createdAt)
                md += "### \(date)\n\n"
                if let input = entry.inputText {
                    md += "**Input:**\n\n\(input)\n\n"
                }
                md += "**Output:**\n\n\(entry.outputText)\n\n"
                md += "---\n\n"
            }
            guard let data = md.data(using: .utf8) else {
                throw ExportError.encodingFailed
            }
            return data
        }
    }
}

private enum ExportError: Error {
    case encodingFailed
}

import UniformTypeIdentifiers
