import Foundation

/// Shapes a provider's model list for the model picker: drops models that
/// cannot translate text, groups the rest by family and puts the newest first.
/// Pure, so the rules are tested without a provider.
enum ModelFamilies {
    struct Group: Equatable {
        let name: String
        let models: [Model]
    }

    /// Speech, image, embedding, moderation and legacy completion models.
    private static let nonTextMarkers = [
        "embed", "tts", "whisper", "transcribe", "speech", "audio", "realtime",
        "moderation", "dall-e", "image", "imagen", "sora", "veo", "aqa",
        "rerank", "babbage", "davinci",
    ]

    static func isTextModel(_ id: String) -> Bool {
        let id = id.lowercased()
        return !nonTextMarkers.contains { id.contains($0) }
    }

    /// Text models matching every word of `query`, grouped and sorted.
    static func groups(_ models: [Model], matching query: String = "") -> [Group] {
        let terms = query.lowercased().split(whereSeparator: \.isWhitespace)
        let shown = models.filter { model in
            guard isTextModel(model.id) else { return false }
            let haystack = (model.id + " " + model.name).lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
        let byFamily = Dictionary(grouping: shown) { family(of: $0.id) }
        return byFamily
            .map { Group(name: $0.key.name, models: $0.value.sorted(by: newerFirst)) }
            .sorted { lhs, rhs in
                let l = family(of: lhs.models[0].id), r = family(of: rhs.models[0].id)
                if l.brand != r.brand { return l.brand < r.brand }
                return l.major > r.major
            }
    }

    /// The "Use '<typed>' as a custom model ID" row: shown for any typed ID
    /// the list does not already hold.
    static func customID(for query: String, in models: [Model]) -> String? {
        let typed = query.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty, !typed.contains(" "), !models.contains(where: { $0.id == typed }) else {
            return nil
        }
        return typed
    }

    // MARK: - Family and version

    struct Family: Hashable {
        let brand: String
        let major: Int

        /// "GPT-5", "Claude 4", "Gemini 2", "o3", "Llama 3"; no number → brand.
        var name: String {
            let display = brand == "gpt" ? "GPT" : brand.prefix(1).uppercased() + brand.dropFirst()
            guard major >= 0 else { return display }
            if brand == "gpt" { return "GPT-\(major)" }
            return brand.count == 1 ? "\(brand)\(major)" : "\(display) \(major)"
        }
    }

    static func family(of id: String) -> Family {
        let id = bareID(id)
        let brand = String(id.prefix { $0.isLetter })
        return Family(brand: brand.isEmpty ? id : brand, major: version(of: id).first ?? -1)
    }

    /// The first run of numbers in the ID: "gpt-5.2-mini" → [5, 2],
    /// "claude-opus-4-5-20251101" → [4, 5], "gpt-4o" → [4]. A word or a
    /// number of four or more digits (a date stamp) ends the run.
    static func version(of id: String) -> [Int] {
        var parts: [Int] = []
        var digits = ""
        var started = false
        for char in bareID(id) + "-" {
            if char.isNumber {
                digits.append(char)
                continue
            }
            if !digits.isEmpty {
                if digits.count >= 4 { break }
                parts.append(Int(digits) ?? 0)
                digits = ""
                started = true
                if char.isLetter { break }
            } else if started, char.isLetter {
                break
            }
        }
        return parts
    }

    /// Newer version first; for the same version, the plain model before its
    /// variants ("gpt-5.2" before "gpt-5.2-mini"), then the latest date stamp.
    static func newerFirst(_ lhs: Model, _ rhs: Model) -> Bool {
        let l = version(of: lhs.id), r = version(of: rhs.id)
        if l != r { return l.lexicographicallyPrecedes(r) == false }
        if lhs.id.count != rhs.id.count { return lhs.id.count < rhs.id.count }
        return lhs.id > rhs.id
    }

    /// Gemini lists "models/gemini-2.5-pro"; an Ollama tag follows ":".
    private static func bareID(_ id: String) -> String {
        let lower = id.lowercased()
        let name = lower.split(separator: "/").last.map(String.init) ?? lower
        return name.split(separator: ":").first.map(String.init) ?? name
    }
}
