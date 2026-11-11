import AppKit
import SwiftUI

/// The Model row's control: a button naming the model that opens a searchable
/// popover (DESIGN.md › Components › ModelPicker).
struct ModelPicker: View {
    @Binding var modelID: String
    let models: [Model]
    let providerName: String
    /// True when `models` is the built-in list because no key is saved.
    var isBuiltInList = false
    /// Why a provider with a key shows only the built-in list.
    var failureReason: String?

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(modelID.isEmpty ? "Choose a model" : modelID)
                    .foregroundStyle(modelID.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Model, \(modelID.isEmpty ? "none" : modelID)")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            ModelPickerPopover(
                selection: $modelID,
                models: models,
                providerName: providerName,
                isBuiltInList: isBuiltInList,
                failureReason: failureReason,
                close: { isOpen = false }
            )
        }
    }
}

struct ModelPickerPopover: View {
    @Binding var selection: String
    let models: [Model]
    let providerName: String
    let isBuiltInList: Bool
    let failureReason: String?
    let close: () -> Void

    @State private var query = ""
    @State private var highlighted: String?
    @State private var keyMonitor: Any?
    @FocusState private var searchFocused: Bool

    private var groups: [ModelFamilies.Group] { ModelFamilies.groups(models, matching: query) }
    private var customID: String? { ModelFamilies.customID(for: query, in: models) }

    /// Every pickable row in display order, the custom ID last.
    private var rows: [String] {
        groups.flatMap { $0.models.map(\.id) } + (customID.map { [$0] } ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search models", text: $query)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
                    .focused($searchFocused)
                    .onSubmit { pick(highlighted ?? rows.first) }
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .padding(Spacing.s)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if groups.isEmpty {
                            EmptyState(
                                symbol: "magnifyingglass",
                                title: query.isEmpty ? "No models to show" : "No \(providerName) model matches",
                                message: "Use it as a custom ID if your account has it."
                            )
                            .frame(height: 180)
                        }
                        ForEach(groups, id: \.name) { group in
                            Text(group.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, Spacing.m)
                                .padding(.top, Spacing.s)
                                .padding(.bottom, 2)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(group.models, id: \.id) { model in
                                row(id: model.id, title: model.id, symbol: model.id == selection ? "checkmark" : nil)
                            }
                        }
                    }
                    .padding(.bottom, Spacing.xs)
                }
                .onChange(of: highlighted) { id in
                    if let id { proxy.scrollTo(id) }
                }
            }
            .frame(height: 300)

            if let customID {
                Divider()
                row(id: customID, title: "Use “\(customID)” as a custom model ID", symbol: "plus")
                    .padding(.vertical, Spacing.xs)
            }

            if isBuiltInList {
                Divider()
                HStack(spacing: Spacing.xs) {
                    if let failureReason {
                        Text("Built-in list. \(failureReason)")
                    } else {
                        Text("Built-in list.")
                        Button("Add a key in Providers") {
                            close()
                            AppCommands.openSettings(tab: .providers)
                        }
                        .buttonStyle(.link)
                        Text("to load every model.")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(Spacing.s)
            }
        }
        .frame(width: 320)
        .onAppear {
            searchFocused = true
            highlighted = models.contains { $0.id == selection } ? selection : nil
            installArrowKeys()
        }
        .onDisappear {
            removeArrowKeys()
            // Otherwise AppKit hands focus to the Settings tab bar and rings it.
            DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
        }
        .onChange(of: query) { _ in highlighted = rows.first }
    }

    private func row(id: String, title: String, symbol: String?) -> some View {
        Button {
            pick(id)
        } label: {
            HStack(spacing: Spacing.s) {
                Image(systemName: symbol ?? "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 14)
                    .opacity(symbol == nil ? 0 : 1)
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 4)
            .foregroundStyle(highlighted == id ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: Radius.control)
                    .fill(highlighted == id ? Color.accentColor : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.xs)
        .id(id)
        .onHover { if $0 { highlighted = id } }
        .accessibilityAddTraits(id == selection ? .isSelected : [])
    }

    private func pick(_ id: String?) {
        guard let id else { return }
        selection = id
        close()
    }

    /// ↑↓ move the highlight while the search field keeps focus. A local
    /// monitor, because `onKeyPress` needs macOS 14.
    private func installArrowKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let step: Int
            switch event.keyCode {
            case 125: step = 1
            case 126: step = -1
            default: return event
            }
            let list = rows
            guard !list.isEmpty else { return nil }
            let current = highlighted.flatMap { list.firstIndex(of: $0) } ?? (step > 0 ? -1 : list.count)
            highlighted = list[min(max(current + step, 0), list.count - 1)]
            return nil
        }
    }

    private func removeArrowKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
