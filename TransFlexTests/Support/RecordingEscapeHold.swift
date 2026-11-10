@testable import TransFlex

/// Records hold/release calls and lets a test press the held Esc.
@MainActor
final class RecordingEscapeHold: EscapeHold {
    private(set) var log: [String] = []
    private var onPress: (() -> Void)?

    var isHeld: Bool { onPress != nil }

    func hold(onPress: @escaping () -> Void) {
        log.append("hold")
        self.onPress = onPress
    }

    func release() {
        log.append("release")
        onPress = nil
    }

    func press() { onPress?() }
}
