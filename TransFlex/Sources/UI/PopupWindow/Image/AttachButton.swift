import SwiftUI

/// Header attach menu for file and clipboard images.
struct AttachButton: View {
    /// False when the selected preset has Supports Vision off. The menu stays
    /// usable so picking an item explains why nothing was attached.
    let canAttach: Bool
    let onChooseFile: () -> Void
    let onPaste: () -> Void

    var body: some View {
        Menu {
            Button {
                onChooseFile()
            } label: {
                Label("Choose File…", systemImage: "folder")
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button {
                onPaste()
            } label: {
                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .opacity(canAttach ? 1 : 0.45)
        .help(canAttach ? "Attach image" : "This preset can't read images. Turn on Supports Vision in Settings → Presets.")
        .background {
            // Menu buttons register shortcuts only after the menu opens.
            Button("", action: onChooseFile)
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
            Button("", action: onPaste)
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}
