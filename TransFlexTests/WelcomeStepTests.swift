import XCTest
@testable import TransFlex

/// Welcome runs intro → provider → shortcut → done (docs/design/mockups.html).
final class WelcomeStepTests: XCTestCase {
    func testStepsRunIntroProviderShortcutDone() {
        XCTAssertEqual(WelcomeStep.allCases, [.intro, .provider, .shortcut, .done])
    }

    func testStepLabelCountsAllFourSteps() {
        XCTAssertEqual(WelcomeStep.intro.stepLabel, "Step 1 of 4")
        XCTAssertEqual(WelcomeStep.provider.stepLabel, "Step 2 of 4")
        XCTAssertEqual(WelcomeStep.done.stepLabel, "Step 4 of 4")
    }

    func testFooterButtonsPerStep() {
        XCTAssertEqual(WelcomeStep.allCases.map(\.primaryTitle), ["Get Started", "Continue", "Continue", "Open Translator"])
        XCTAssertEqual(WelcomeStep.allCases.map(\.showsBack), [false, true, true, true])
        XCTAssertEqual(WelcomeStep.allCases.map(\.showsSkip), [false, true, false, false])
    }
}
