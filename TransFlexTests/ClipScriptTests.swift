import KeyboardShortcuts
import XCTest
@testable import TransFlex

/// The website's clips must show what the app does, in the order it does it.
final class ClipScriptTests: XCTestCase {
    private let hero = ClipScript.hero
    private let replace = ClipScript.replace

    private func times(_ script: ClipScript) -> [TimeInterval] {
        stride(from: 0, to: script.duration, by: 1.0 / Double(ClipScript.fps)).map { $0 }
    }

    private func translation(_ state: PopupState) -> String? {
        switch state {
        case .streaming(let text): return text
        case .done(let text): return text
        default: return nil
        }
    }

    func testHeroLastsSixToTenSeconds() {
        XCTAssertGreaterThanOrEqual(hero.duration, 6)
        XCTAssertLessThanOrEqual(hero.duration, 10)
    }

    @MainActor
    func testHeroShowsTheReleaseBuildsPopupShortcutAndFirstPreset() {
        let releaseDefault = ShortcutKeys.symbols(for: KeyboardShortcuts.Name.defaultPopupShortcut(debugBuild: false))
        XCTAssertEqual(hero.frame(at: 1.2).keycap, releaseDefault)
        XCTAssertEqual(ClipScript.presetName, DefaultPresets.builtins.first?.name, "the popup opens on the first preset")
    }

    func testHeroOpensThePopupOnlyAfterTheShortcut() {
        XCTAssertEqual(hero.frame(at: 0.4).popupOpacity, 0, "nothing is open before the shortcut")
        XCTAssertEqual(hero.frame(at: 0.4).keycap, nil)
        XCTAssertEqual(hero.frame(at: 1.2).popupOpacity, 0)
        XCTAssertEqual(hero.frame(at: 2.5).popupOpacity, 1)
    }

    func testHeroTranslationOnlyGrowsAndEndsDoneWithCost() throws {
        var previous = ""
        var sawPartial = false
        for t in times(hero) {
            guard let text = translation(hero.frame(at: t).state) else {
                XCTAssertTrue(previous.isEmpty, "the translation never disappears once shown (t=\(t))")
                continue
            }
            XCTAssertTrue(text.hasPrefix(previous), "the translation never shrinks (t=\(t))")
            XCTAssertTrue(ClipScript.sampleTranslation.hasPrefix(text), "only the sample translation streams (t=\(t))")
            if !text.isEmpty && text != ClipScript.sampleTranslation { sawPartial = true }
            previous = text
        }
        XCTAssertTrue(sawPartial, "the translation streams in word by word")

        let last = hero.frame(at: hero.duration - 0.01)
        XCTAssertEqual(last.state, .done(result: ClipScript.sampleTranslation))
        XCTAssertNotNil(last.cost, "the finished popup shows tokens and cost")
        XCTAssertEqual(last.input, ClipScript.sampleSource)
    }

    func testReplaceSwapsTheTextOnlyAfterTranslating() {
        var translatingSeen = false
        for t in times(replace) {
            let frame = replace.frame(at: t)
            if case .translating = frame.hud { translatingSeen = true }
            if frame.documentSentence == ClipScript.sampleTranslation {
                XCTAssertTrue(translatingSeen, "the text changes only after the HUD said it was translating (t=\(t))")
            }
        }
        XCTAssertEqual(replace.frame(at: replace.duration - 0.01).documentSentence, ClipScript.sampleTranslation)
        XCTAssertEqual(replace.frame(at: replace.duration - 0.01).hud, .replaced)
        XCTAssertEqual(replace.frame(at: 0.2).documentSentence, ClipScript.sampleSource)
    }

    /// Replace Selection has no default shortcut, so the clip must not show one.
    func testReplaceKeycapNamesNoKeyCombination() {
        let keycaps = times(replace).compactMap { replace.frame(at: $0).keycap }
        XCTAssertFalse(keycaps.isEmpty, "the clip shows the shortcut being pressed")
        for keys in keycaps { XCTAssertEqual(keys, ["Your shortcut"]) }
    }
}
