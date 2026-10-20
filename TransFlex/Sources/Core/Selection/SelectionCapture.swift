import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Reads and replaces the frontmost app's text selection by synthesizing
/// ⌘C / ⌘V, then puts the user's clipboard back.
///
/// Keystrokes instead of `kAXSelectedTextAttribute`: the AX attribute is
/// missing in Chrome, Electron and many other apps, while every text field
/// honours ⌘C. Both paths need the Accessibility permission anyway.
@MainActor
final class SelectionCapture {
    enum Failure: Error, Equatable {
        case accessibilityNotGranted
        case noSelection
    }

    typealias KeyPoster = @MainActor (_ keyCode: CGKeyCode) -> Void

    private let pasteboard: NSPasteboard
    private let isTrusted: () -> Bool
    private let modifiersHeld: () -> Bool
    private let postCommandKey: KeyPoster
    private let pollInterval: UInt64
    private let copyTimeout: UInt64
    private let restoreDelay: UInt64

    init(
        pasteboard: NSPasteboard = .general,
        isTrusted: @escaping () -> Bool = AccessibilityPermission.isGranted,
        modifiersHeld: @escaping () -> Bool = SelectionCapture.physicalModifiersHeld,
        postCommandKey: @escaping KeyPoster = SelectionCapture.postCommandKey,
        pollInterval: UInt64 = 20_000_000,
        copyTimeout: UInt64 = 500_000_000,
        restoreDelay: UInt64 = 400_000_000
    ) {
        self.pasteboard = pasteboard
        self.isTrusted = isTrusted
        self.modifiersHeld = modifiersHeld
        self.postCommandKey = postCommandKey
        self.pollInterval = pollInterval
        self.copyTimeout = copyTimeout
        self.restoreDelay = restoreDelay
    }

    /// Copies the current selection and returns it as plain text. The
    /// clipboard is restored before returning, whether or not a copy happened.
    func copySelection() async throws -> String {
        guard isTrusted() else { throw Failure.accessibilityNotGranted }
        await waitForModifierRelease()

        let snapshot = takeSnapshot()
        let before = pasteboard.changeCount
        defer { restore(snapshot) }

        postCommandKey(CGKeyCode(kVK_ANSI_C))

        // An app with nothing selected leaves the clipboard untouched.
        var waited: UInt64 = 0
        while pasteboard.changeCount == before, waited < copyTimeout {
            try? await Task.sleep(nanoseconds: pollInterval)
            waited += pollInterval
        }
        guard pasteboard.changeCount != before,
              let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw Failure.noSelection
        }
        return text
    }

    /// Pastes `text` over the current selection, then restores the previous
    /// clipboard unless something else wrote to it in the meantime.
    func paste(_ text: String) async throws {
        guard isTrusted() else { throw Failure.accessibilityNotGranted }
        await waitForModifierRelease()

        let snapshot = takeSnapshot()
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let written = pasteboard.changeCount

        postCommandKey(CGKeyCode(kVK_ANSI_V))

        // The target app reads the clipboard asynchronously after ⌘V.
        try? await Task.sleep(nanoseconds: restoreDelay)
        if pasteboard.changeCount == written {
            restore(snapshot)
        }
    }

    // MARK: - Clipboard snapshot

    private typealias Snapshot = [[NSPasteboard.PasteboardType: Data]]

    private func takeSnapshot() -> Snapshot {
        (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { entry[type] = data }
            }
            return entry
        }
    }

    private func restore(_ snapshot: Snapshot) {
        pasteboard.clearContents()
        let items = snapshot.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    /// The hotkey fires while its modifiers are still down; a ⌥ still held
    /// when ⌘C lands turns it into ⌥⌘C in some apps. Capped so a user who
    /// keeps holding the keys still gets the copy.
    private func waitForModifierRelease() async {
        var waited: UInt64 = 0
        while modifiersHeld(), waited < 300_000_000 {
            try? await Task.sleep(nanoseconds: pollInterval)
            waited += pollInterval
        }
    }

    // MARK: - System defaults

    nonisolated static func physicalModifiersHeld() -> Bool {
        let held = CGEventSource.flagsState(.hidSystemState)
        return !held.intersection([.maskAlternate, .maskShift, .maskControl, .maskCommand]).isEmpty
    }

    static func postCommandKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
