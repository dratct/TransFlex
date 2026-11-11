import SwiftUI
import XCTest
@testable import TransFlex

/// `--screenshots` captures feed the website and the CI screenshot run, so a
/// capture must look like the window it renders.
@MainActor
final class ScreenshotModeTests: XCTestCase {
    private struct SidebarWithSelection: View {
        @State private var selection: Int? = 1
        var body: some View {
            List(selection: $selection) {
                ForEach(0..<4) { Text("Row \($0)").tag(Optional($0)) }
            }
            .listStyle(.sidebar)
        }
    }

    /// The Presets tab and History both show a sidebar list with a selected row.
    func testSelectedSidebarRowIsNotBlackInLightCapture() async throws {
        let shot = ScreenshotMode.Shot(name: "sidebar", size: NSSize(width: 240, height: 200)) {
            AnyView(SidebarWithSelection())
        }
        let rendered = await ScreenshotMode.render(shot, appearance: .aqua)
        let rep = try XCTUnwrap(rendered)

        var nearBlack = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                if color.redComponent + color.greenComponent + color.blueComponent < 0.1 { nearBlack += 1 }
            }
        }
        XCTAssertEqual(nearBlack, 0, "a light capture has no near-black pixels; the selected row drew as a black block")
    }
}
