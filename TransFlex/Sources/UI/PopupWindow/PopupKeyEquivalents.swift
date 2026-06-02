import SwiftUI

/// View modifier that catches ESC to cancel stream or hide popup.
struct PopupEscapeModifier: ViewModifier {
    @ObservedObject var viewModel: PopupViewModel
    let onEscape: () -> Void

    func body(content: Content) -> some View {
        content.onExitCommand {
            if case .streaming = viewModel.state {
                viewModel.cancelStream()
            } else {
                onEscape()
            }
        }
    }
}
