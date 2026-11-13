import XCTest
@testable import TransFlex

/// Every sample is assembled at run time, so this file holds nothing that
/// looks like a real credential to a repository scanner.
final class SecretScannerTests: XCTestCase {
    static let githubToken = "ghp_" + "AAAA" + String(repeating: "m", count: 28) + "ZZZZ"

    private func kind(_ text: String) -> String? {
        SecretScanner.firstMatch(in: text)?.kind
    }

    private func filler(_ count: Int) -> String {
        String(repeating: "a1B2", count: count / 4 + 1).prefix(count).description
    }

    func testGitHubTokenIsFoundAndMaskedToItsEnds() {
        let match = SecretScanner.firstMatch(in: "token: \(Self.githubToken) in the README")
        XCTAssertEqual(match?.kind, "GitHub token")
        XCTAssertEqual(match?.masked, "ghp_…ZZZZ")
        XCTAssertFalse(match?.masked.contains("mmmm") ?? true)
    }

    func testGitHubFineGrainedToken() {
        XCTAssertEqual(kind("github_pat_" + filler(82)), "GitHub token")
    }

    func testAnthropicKey() {
        XCTAssertEqual(kind("sk-ant-" + "api03-" + filler(93) + "AA"), "Anthropic API key")
    }

    func testOpenAIProjectKey() {
        XCTAssertEqual(kind("sk-" + "proj-" + filler(58) + "T3BlbkFJ" + filler(58)), "OpenAI API key")
    }

    func testOpenAIClassicKey() {
        XCTAssertEqual(kind("sk-" + filler(20) + "T3BlbkFJ" + filler(20)), "OpenAI API key")
    }

    func testGoogleKey() {
        XCTAssertEqual(kind("AI" + "za" + filler(35)), "Google API key")
    }

    func testAWSAccessKey() {
        XCTAssertEqual(kind("AK" + "IA" + String(repeating: "Q2", count: 8)), "AWS access key")
    }

    func testSlackBotToken() {
        XCTAssertEqual(kind("xo" + "xb-" + "1234567890-1234567890-" + filler(24)), "Slack token")
    }

    func testStripeKey() {
        XCTAssertEqual(kind("sk_" + "live_" + filler(24)), "Stripe key")
    }

    func testPrivateKeyBlockHasNoMaskedValue() {
        let match = SecretScanner.firstMatch(in: "-----BEGIN RSA " + "PRIVATE KEY-----\nMIIEow\n")
        XCTAssertEqual(match?.kind, "Private key")
        XCTAssertEqual(match?.masked, "")
    }

    func testURLWithPasswordShowsOnlySchemeAndHost() {
        let match = SecretScanner.firstMatch(in: "clone https://deploy:" + "hunter2secret" + "@example.com/repo.git")
        XCTAssertEqual(match?.kind, "URL with a password")
        XCTAssertEqual(match?.masked, "https://••••@example.com")
    }

    func testOrdinaryTextAndNearMissesAreNotFound() {
        XCTAssertNil(SecretScanner.firstMatch(in: "Xin chào, hôm nay trời đẹp quá."))
        XCTAssertNil(SecretScanner.firstMatch(in: "git clone https://git@github.com/a/b.git"))
        XCTAssertNil(SecretScanner.firstMatch(in: "sk-short"))
        XCTAssertNil(SecretScanner.firstMatch(in: "ghp_" + filler(10)))
    }

    func testTheEarliestSecretInTheTextWins() {
        let text = "first sk_" + "live_" + filler(24) + " then " + Self.githubToken
        XCTAssertEqual(kind(text), "Stripe key")
    }
}
