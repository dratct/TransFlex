import SwiftUI

struct HistoryExportSheet: View {
    @Binding var isPresented: Bool
    /// Called with the chosen format; the save panel opens once this sheet has closed.
    let onExport: (ExportFormat) -> Void

    @State private var selectedFormat: ExportFormat = .json

    var body: some View {
        VStack(spacing: 16) {
            Text("Export History")
                .font(.headline)

            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Export…") {
                    onExport(selectedFormat)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 320)
    }
}
