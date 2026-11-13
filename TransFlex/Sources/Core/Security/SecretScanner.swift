import Foundation

/// What the Secret check found: the kind to name and a masked form to show.
/// It never holds the value itself.
public struct SecretMatch: Equatable, Sendable {
    public let kind: String
    /// The value's first four and last four characters; empty when there is
    /// nothing safe to show (a private key block).
    public let masked: String

    public init(kind: String, masked: String) {
        self.kind = kind
        self.masked = masked
    }
}

/// Finds credentials with a fixed, known shape in text about to be sent to a
/// provider. Not a redactor: `String.redactingSecrets()` serves logs and has
/// its own rules.
public enum SecretScanner {
    /// The match that starts earliest in `text`, or `nil`.
    public static func firstMatch(in text: String) -> SecretMatch? {
        let whole = NSRange(text.startIndex..., in: text)
        var earliest: (location: Int, match: SecretMatch)?
        for rule in rules {
            guard let found = rule.regex.firstMatch(in: text, options: [], range: whole),
                  found.range.location < (earliest?.location ?? Int.max)
            else { continue }
            earliest = (found.range.location, SecretMatch(kind: rule.kind, masked: rule.mask(found, text)))
        }
        return earliest?.match
    }

    private struct Rule {
        let kind: String
        let regex: NSRegularExpression
        let mask: (NSTextCheckingResult, String) -> String
    }

    private static func ends(_ found: NSTextCheckingResult, _ text: String) -> String {
        guard let range = Range(found.range, in: text) else { return "" }
        let value = text[range]
        return "\(value.prefix(4))…\(value.suffix(4))"
    }

    private static func nothing(_: NSTextCheckingResult, _: String) -> String { "" }

    private static func schemeAndHost(_ found: NSTextCheckingResult, _ text: String) -> String {
        guard let scheme = Range(found.range(at: 1), in: text),
              let host = Range(found.range(at: 2), in: text)
        else { return "" }
        return "\(text[scheme])://••••@\(text[host])"
    }

    // Patterns follow the gitleaks default rules (config/gitleaks.toml),
    // without their trailing-delimiter groups and entropy thresholds. The
    // URL rule is this project's own: it needs both a user and a password,
    // so `https://git@host` passes.
    private static let rules: [Rule] = {
        typealias Mask = (NSTextCheckingResult, String) -> String
        let raw: [(String, String, Mask)] = [
            ("Anthropic API key", #"\bsk-ant-(?:api03|admin01)-[A-Za-z0-9_\-]{93}AA"#, ends),
            ("OpenAI API key", #"\bsk-(?:proj|svcacct|admin)-[A-Za-z0-9_-]{58,74}T3BlbkFJ[A-Za-z0-9_-]{58,74}"#, ends),
            ("OpenAI API key", #"\bsk-[A-Za-z0-9]{20}T3BlbkFJ[A-Za-z0-9]{20}"#, ends),
            ("Google API key", #"\bAIza[\w-]{35}"#, ends),
            ("GitHub token", #"\b(?:ghp|gho|ghu|ghs|ghr)_[0-9A-Za-z]{36}"#, ends),
            ("GitHub token", #"\bgithub_pat_\w{82}"#, ends),
            ("AWS access key", #"\b(?:A3T[A-Z0-9]|AKIA|ASIA|ABIA|ACCA)[A-Z2-7]{16}\b"#, ends),
            ("Slack token", #"xoxb-[0-9]{10,13}-[0-9]{10,13}[A-Za-z0-9-]*"#, ends),
            ("Slack token", #"xox[pe](?:-[0-9]{10,13}){3}-[A-Za-z0-9-]{28,34}"#, ends),
            ("Slack token", #"xapp-\d-[A-Z0-9]+-\d+-[A-Za-z0-9]+"#, ends),
            ("Stripe key", #"\b(?:sk|rk)_(?:test|live|prod)_[A-Za-z0-9]{10,99}"#, ends),
            ("Private key", #"-----BEGIN[ A-Z0-9_-]{0,100}PRIVATE KEY(?: BLOCK)?-----"#, nothing),
            ("URL with a password", #"(https?)://[^\s/:@]+:[^\s/@]+@([^\s/:?#]+)"#, schemeAndHost),
        ]
        return raw.compactMap { kind, pattern, mask in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return Rule(kind: kind, regex: regex, mask: mask)
        }
    }()
}
