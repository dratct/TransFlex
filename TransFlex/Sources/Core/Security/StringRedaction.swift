import Foundation

public extension String {
    /// Replaces known-secret formats with `[REDACTED]`. Use as the chokepoint
    /// before any provider response body, error string, or URL is logged or
    /// surfaced in UI / crash reports.
    func redactingSecrets() -> String {
        SecretRedactor.shared.redact(self)
    }
}

private struct SecretRedactor {
    static let shared = SecretRedactor()

    private struct Rule {
        let regex: NSRegularExpression
        let template: String
    }

    private let rules: [Rule]

    init() {
        let raw: [(String, String)] = [
            (#"sk-ant-[A-Za-z0-9\-_]{20,}"#, "[REDACTED]"),
            (#"sk-proj-[A-Za-z0-9\-_]{20,}"#, "[REDACTED]"),
            (#"sk-[A-Za-z0-9\-_]{20,}"#, "[REDACTED]"),
            (#"AIza[A-Za-z0-9\-_]{30,}"#, "[REDACTED]"),
            (#"lk_[A-Za-z0-9]{20,}"#, "[REDACTED]"),
            // Bearer header — keep the `Authorization: Bearer ` prefix.
            (#"(?i)(authorization:\s*bearer\s+)[A-Za-z0-9\-_\.]+"#, "$1[REDACTED]"),
            // URL userinfo (`https://user:pass@host/...`). Keep scheme; redact
            // credentials. Defense-in-depth for any error text that surfaces a
            // request URL with embedded auth.
            (#"(?i)(https?://)[^@\s/]+@"#, "$1[REDACTED]@"),
        ]
        rules = raw.compactMap { pattern, template in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return Rule(regex: regex, template: template)
        }
    }

    func redact(_ input: String) -> String {
        var output = input
        for rule in rules {
            let range = NSRange(output.startIndex..., in: output)
            output = rule.regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: rule.template
            )
        }
        return output
    }
}
