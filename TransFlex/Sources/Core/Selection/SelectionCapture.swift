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
        /// The app, field or selection the text was copied from was gone at
        /// paste time and could not be brought back, so no ⌘V was sent. The
        /// text to paste is left on the clipboard.
        case targetLost
    }

    /// Where a selection was copied from, so a paste can go back there.
    struct TextTarget {
        let pid: pid_t
        /// The focused element, kept only when the app returns the same
        /// element on repeated queries, so it can be compared later.
        let element: AXUIElement?
        let range: AXValue?
        /// The element's selected text matched the copy, so it can be
        /// compared again before pasting.
        let checksSelection: Bool
    }

    /// The selection's text and where it came from.
    struct CopiedSelection {
        let text: String
        let target: TextTarget?
    }

    /// The Accessibility calls made on the app being edited.
    struct Focus {
        var capture: @MainActor (_ selection: String) -> TextTarget?
        var isInPlace: @MainActor (_ target: TextTarget, _ selection: String) -> Bool
        var restore: @MainActor (_ target: TextTarget) async -> Void
        /// The text of the target's element, or of the focused element when
        /// there is no target.
        var text: @MainActor (_ target: TextTarget?) -> String?

        static let none = Focus(capture: { _ in nil }, isInPlace: { _, _ in true }, restore: { _ in }, text: { _ in nil })
    }

    typealias KeyPoster = @MainActor (_ keyCode: CGKeyCode) -> Void

    private let pasteboard: NSPasteboard
    private let isTrusted: () -> Bool
    private let modifiersHeld: () -> Bool
    private let postCommandKey: KeyPoster
    private let focus: Focus
    private let pasteConfirmTimeout: UInt64
    private let pollInterval: UInt64
    private let copyTimeout: UInt64
    private let restoreDelay: UInt64

    init(
        pasteboard: NSPasteboard = .general,
        isTrusted: @escaping () -> Bool = AccessibilityPermission.isGranted,
        modifiersHeld: @escaping () -> Bool = SelectionCapture.physicalModifiersHeld,
        postCommandKey: @escaping KeyPoster = SelectionCapture.postCommandKey,
        focus: Focus = .accessibility,
        pollInterval: UInt64 = 20_000_000,
        copyTimeout: UInt64 = 500_000_000,
        restoreDelay: UInt64 = 400_000_000,
        pasteConfirmTimeout: UInt64 = 1_000_000_000
    ) {
        self.pasteboard = pasteboard
        self.isTrusted = isTrusted
        self.modifiersHeld = modifiersHeld
        self.postCommandKey = postCommandKey
        self.focus = focus
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
        _ = focus.text(nil)

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

    /// Copies the selection like `copySelection`, and notes the app, field
    /// and selection range it came from.
    func copyForReplace() async throws -> CopiedSelection {
        let text = try await copySelection()
        return CopiedSelection(text: text, target: focus.capture(text))
    }

    /// Whether `copied` is still what is selected where it came from, for a
    /// paste that comes long after the copy. The app it came from is brought
    /// back first. Where the field can be compared, `paste` does that; where
    /// it cannot (a browser), the selection is copied again there, and never
    /// from another app.
    func isStillSelected(_ copied: CopiedSelection) async -> Bool {
        guard let target = copied.target else { return false }
        if !focus.isInPlace(target, copied.text) {
            await focus.restore(target)
            guard focus.isInPlace(target, copied.text) else { return false }
        }
        if target.element != nil, target.checksSelection { return true }
        // A cancelled copy does not wait for the app to answer, so its text
        // would land on the clipboard after the old one was put back.
        guard !Task.isCancelled else { return false }
        return (try? await copySelection()) == copied.text
    }

    /// Puts `text` on the clipboard for the user to paste, when it cannot be
    /// pasted for them.
    func leaveOnClipboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Pastes `text` over the selection `copied` came from, then restores
    /// the previous clipboard unless something else wrote to it meanwhile.
    ///
    /// If that app, field or selection is no longer in front, it is brought
    /// back first; when that fails this throws `targetLost` without sending
    /// ⌘V. When the field's text can be read and contains the selection, it
    /// must change after ⌘V or this throws `pasteNotApplied`. Both leave
    /// `text` on the clipboard.
    func paste(_ text: String, over copied: CopiedSelection) async throws {
        guard isTrusted() else { throw Failure.accessibilityNotGranted }
        await waitForModifierRelease()

        if let target = copied.target, !focus.isInPlace(target, copied.text) {
            await focus.restore(target)
            guard focus.isInPlace(target, copied.text) else {
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                throw Failure.targetLost
            }
        }

        let fieldBefore = Self.fieldToVerify(focus.text(copied.target), replacing: copied.text, with: text)
        let snapshot = takeSnapshot()
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let written = pasteboard.changeCount

        postCommandKey(CGKeyCode(kVK_ANSI_V))

        if let fieldBefore, !(await fieldChanges(copied.target, from: fieldBefore)) {
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

    private func fieldChanges(_ target: TextTarget?, from before: String) async -> Bool {
        var waited: UInt64 = 0
        while waited < pasteConfirmTimeout {
            if focus.text(target) != before { return true }
            try? await Task.sleep(nanoseconds: pollInterval)
            waited += pollInterval
        }
        return focus.text(target) != before
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

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func focusedElement(ofApp pid: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        // Chromium turns on its web-content accessibility for a client that
        // reads the app's role; without it a page's fields are invisible.
        _ = copyAttribute(appElement, kAXRoleAttribute)
        guard let focused = copyAttribute(appElement, kAXFocusedUIElementAttribute),
              CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        return (focused as! AXUIElement)
    }

    private static var frontmostPID: pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    private static func copyAttribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    struct KeyStroke: Equatable {
        let keyCode: CGKeyCode
        let isDown: Bool
        let flags: CGEventFlags
    }

    /// ⌘ goes down first and comes up last with no flags. A key that only
    /// carries the ⌘ flag leaves macOS reporting ⌘ as held afterwards, so
    /// the user's next Tab becomes ⌘Tab.
    static func commandKeyStrokes(_ keyCode: CGKeyCode) -> [KeyStroke] {
        let command = CGKeyCode(kVK_Command)
        return [
            KeyStroke(keyCode: command, isDown: true, flags: .maskCommand),
            KeyStroke(keyCode: keyCode, isDown: true, flags: .maskCommand),
            KeyStroke(keyCode: keyCode, isDown: false, flags: .maskCommand),
            KeyStroke(keyCode: command, isDown: false, flags: []),
        ]
    }

    static func postCommandKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        for stroke in commandKeyStrokes(keyCode) {
            let event = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: stroke.isDown)
            event?.flags = stroke.flags
            event?.post(tap: .cghidEventTap)
        }
    }
}

extension SelectionCapture.Focus {
    /// The real calls, through the Accessibility API.
    static var accessibility: SelectionCapture.Focus { SelectionCapture.Focus(
        capture: { selection in
            guard let pid = SelectionCapture.frontmostPID else { return nil }
            guard let element = SelectionCapture.focusedElement(ofApp: pid),
                  let again = SelectionCapture.focusedElement(ofApp: pid),
                  CFEqual(element, again)
            else {
                return SelectionCapture.TextTarget(pid: pid, element: nil, range: nil, checksSelection: false)
            }
            let range = SelectionCapture.copyAttribute(element, kAXSelectedTextRangeAttribute)
            let selected = SelectionCapture.copyAttribute(element, kAXSelectedTextAttribute) as? String
            return SelectionCapture.TextTarget(
                pid: pid,
                element: element,
                range: range.map { $0 as! AXValue },
                checksSelection: selected.map(SelectionCapture.trimmed) == SelectionCapture.trimmed(selection)
            )
        },
        isInPlace: { target, selection in
            guard SelectionCapture.frontmostPID == target.pid else { return false }
            guard let element = target.element else { return true }
            guard let focused = SelectionCapture.focusedElement(ofApp: target.pid),
                  CFEqual(focused, element)
            else { return false }
            guard target.checksSelection else { return true }
            let selected = SelectionCapture.copyAttribute(element, kAXSelectedTextAttribute) as? String
            return selected.map(SelectionCapture.trimmed) == SelectionCapture.trimmed(selection)
        },
        restore: { target in
            NSRunningApplication(processIdentifier: target.pid)?.activate()
            for _ in 0..<25 where SelectionCapture.frontmostPID != target.pid {
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            if let element = target.element {
                AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                if let range = target.range {
                    AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, range)
                }
            }
            // Let the app apply the focus and selection before it is checked.
            try? await Task.sleep(nanoseconds: 150_000_000)
        },
        text: { target in
            let element = target?.element
                ?? SelectionCapture.frontmostPID.flatMap(SelectionCapture.focusedElement(ofApp:))
            return element.flatMap { SelectionCapture.copyAttribute($0, kAXValueAttribute) as? String }
        }
    ) }
}
