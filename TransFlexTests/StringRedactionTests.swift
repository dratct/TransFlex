import XCTest
@testable import TransFlex

final class StringRedactionTests: XCTestCase {
    func testOpenAIClassicKey() {
        let input = "error from sk-AbCdEfGhIjKlMnOpQrStUv1234567890ZZ in body"
        XCTAssertFalse(input.redactingSecrets().contains("sk-AbCdEf"))
        XCTAssertTrue(input.redactingSecrets().contains("[REDACTED]"))
    }

    func testOpenAIProjectKey() {
        let input = "Bearer sk-proj-abcdefghijklmnopqrstuvwxyz_1234"
        XCTAssertTrue(input.redactingSecrets().contains("[REDACTED]"))
        XCTAssertFalse(input.redactingSecrets().contains("sk-proj-"))
    }

    func testAnthropicKey() {
        let input = "sk-ant-api03-abcdefghijklmnopqrstuvwxyz1234"
        XCTAssertTrue(input.redactingSecrets().contains("[REDACTED]"))
    }

    func testGeminiKey() {
        let input = "key: AIzaSyAbcdefghijklmnopqrstuvwxyz12345678"
        XCTAssertTrue(input.redactingSecrets().contains("[REDACTED]"))
        XCTAssertFalse(input.redactingSecrets().contains("AIza"))
    }

    func testBearerHeader() {
        let input = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig"
        let out = input.redactingSecrets()
        XCTAssertTrue(out.contains("Authorization"))
        XCTAssertTrue(out.contains("[REDACTED]"))
        XCTAssertFalse(out.contains("eyJhbGciOiJIUzI1NiJ9"))
    }

    func testCleanTextUnchanged() {
        let input = "regular log line, nothing secret"
        XCTAssertEqual(input.redactingSecrets(), input)
    }

    func testMultipleSecretsRedacted() {
        let input = "key1=sk-abcdefghijklmnopqrstuvwxyz12 key2=AIzaAbcdefghijklmnopqrstuvwxyz1234"
        let out = input.redactingSecrets()
        XCTAssertEqual(out.components(separatedBy: "[REDACTED]").count - 1, 2)
    }

    func testURLUserinfoRedacted() {
        let input = "failed: https://user:supersecret@api.example.com/v1/foo"
        let out = input.redactingSecrets()
        XCTAssertFalse(out.contains("supersecret"))
        XCTAssertFalse(out.contains("user:"))
        XCTAssertTrue(out.contains("https://[REDACTED]@api.example.com/v1/foo"))
    }

    func testURLWithoutUserinfoUnchanged() {
        let input = "GET https://api.example.com/v1/models"
        XCTAssertEqual(input.redactingSecrets(), input)
    }
}
