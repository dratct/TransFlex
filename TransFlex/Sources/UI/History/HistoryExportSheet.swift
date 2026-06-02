import SwiftUI

struct HistoryExportSheet: View {
    let store: HistoryStore
    @Binding var isPresented: Bool

    @State private var selectedFormat: ExportFormat = .json
    @State private var isExporting = false

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
                Button("Export") { performExport() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isExporting)
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func performExport() {
        isExporting = true
        do {
            let entries = try store.allEntries()
            HistoryExporter.export(entries: entries, as: selectedFormat)
        } catch {
            // Exporter logs the error
        }
        isExporting = false
        isPresented = false
    }
}
