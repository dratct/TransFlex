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
        /// The focused field showed the same text before and after ⌘V: the
        /// app ignored it (read-only field, a page that blocks paste, focus
        /// gone). The text to paste is left on the clipboard.
        case pasteNotApplied
    }

    typealias KeyPoster = @MainActor (_ keyCode: CGKeyCode) -> Void

    private let pasteboard: NSPasteboard
    private let isTrusted: () -> Bool
    private let modifiersHeld: () -> Bool
    private let postCommandKey: KeyPoster
    private let focusedText: @MainActor () -> String?
    private let pasteConfirmTimeout: UInt64
    private let pollInterval: UInt64
    private let copyTimeout: UInt64
    private let restoreDelay: UInt64

    init(
        pasteboard: NSPasteboard = .general,
        isTrusted: @escaping () -> Bool = AccessibilityPermission.isGranted,
        modifiersHeld: @escaping () -> Bool = SelectionCapture.physicalModifiersHeld,
        postCommandKey: @escaping KeyPoster = SelectionCapture.postCommandKey,
        focusedText: @escaping @MainActor () -> String? = SelectionCapture.focusedFieldText,
        pollInterval: UInt64 = 20_000_000,
        copyTimeout: UInt64 = 500_000_000,
        restoreDelay: UInt64 = 400_000_000,
        pasteConfirmTimeout: UInt64 = 1_000_000_000
    ) {
        self.pasteboard = pasteboard
        self.isTrusted = isTrusted
        self.modifiersHeld = modifiersHeld
        self.postCommandKey = postCommandKey
        self.focusedText = focusedText
        self.pollInterval = pollInterval
        self.copyTimeout = copyTimeout
        self.restoreDelay = restoreDelay
        self.pasteConfirmTimeout = pasteConfirmTimeout
    }

    /// Copies the current selection and returns it as plain text. The
    /// clipboard is restored before returning, whether or not a copy happened.
    func copySelection() async throws -> String {
        guard isTrusted() else { throw Failure.accessibilityNotGranted }
        await waitForModifierRelease()

        // Browsers build their accessibility tree on the first query and
        // answer it empty; asking now leaves it ready for `paste`.
        _ = focusedText()

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
    ///
    /// `original` is the selection being replaced. When the focused field's
    /// text can be read and contains it, the text must change after ⌘V or
    /// this throws `pasteNotApplied` and leaves `text` on the clipboard.
    /// Anything else (no readable field, an element that is not the field)
    /// is not checked.
    func paste(_ text: String, replacing original: String) async throws {
        guard isTrusted() else { throw Failure.accessibilityNotGranted }
        await waitForModifierRelease()

        let fieldBefore = Self.fieldToVerify(focusedText(), replacing: original, with: text)
        let snapshot = takeSnapshot()
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let written = pasteboard.changeCount

        postCommandKey(CGKeyCode(kVK_ANSI_V))

        if let fieldBefore, !(await fieldChanges(from: fieldBefore)) {
            throw Failure.pasteNotApplied
        }

        // The target app reads the clipboard asynchronously after ⌘V.
        try? await Task.sleep(nanoseconds: restoreDelay)
        if pasteboard.changeCount == written {
            restore(snapshot)
        }
    }

    /// The field's text when it is worth checking after the paste: it shows
    /// the selection, and the paste would change it.
    static func fieldToVerify(_ field: String?, replacing original: String, with text: String) -> String? {
        let selected = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let field, text != original, !selected.isEmpty, field.contains(selected) else { return nil }
        return field
    }

    private func fieldChanges(from before: String) async -> Bool {
        var waited: UInt64 = 0
        while waited < pasteConfirmTimeout {
            if focusedText() != before { return true }
            try? await Task.sleep(nanoseconds: pollInterval)
            waited += pollInterval
        }
        return focusedText() != before
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

    /// The text of the frontmost app's focused element, or nil when the app
    /// does not expose it.
    static func focusedFieldText() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        // Chromium turns on its web-content accessibility for a client that
        // reads the app's role; without it a page's fields are invisible.
        _ = copyAttribute(appElement, kAXRoleAttribute)
        guard let focused = copyAttribute(appElement, kAXFocusedUIElementAttribute),
              CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        return copyAttribute(focused as! AXUIElement, kAXValueAttribute) as? String
    }

    private static func copyAttribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
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
