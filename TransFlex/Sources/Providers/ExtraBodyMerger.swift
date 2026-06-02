import Foundation

enum ExtraBodyMerger {
    static func merge(_ base: inout [String: Any], withJSON json: String) {
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let extra = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        deepMerge(&base, extra)
    }

    private static func deepMerge(_ base: inout [String: Any], _ overlay: [String: Any]) {
        for (key, value) in overlay {
            if let existingDict = base[key] as? [String: Any],
               let newDict = value as? [String: Any] {
                var merged = existingDict
                deepMerge(&merged, newDict)
                base[key] = merged
            } else {
                base[key] = value
            }
        }
    }
}
