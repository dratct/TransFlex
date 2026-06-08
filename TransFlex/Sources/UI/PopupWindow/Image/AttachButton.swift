import SwiftUI

/// Header attach menu for file and clipboard images.
struct AttachButton: View {
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
        .help("Attach image")
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
