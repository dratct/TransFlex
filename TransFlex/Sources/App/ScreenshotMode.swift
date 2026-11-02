import AppKit
import OSLog
import SwiftUI

/// `--screenshots <dir>`: renders every screen × state from sample data, in
/// light and dark, writes one PNG each and quits. No provider is called and no
/// hotkey is registered. CI runs it on the macOS versions nobody here owns.
@MainActor
enum ScreenshotMode {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "Screenshots")

    static func outputDirectory(from arguments: [String]) -> URL? {
        guard let flag = arguments.firstIndex(of: "--screenshots"), flag + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[flag + 1], isDirectory: true)
    }

    struct Shot {
        let name: String
        let size: NSSize
        let view: () -> AnyView
    }

    static func run(to directory: URL) {
        NSApp.activate(ignoringOtherApps: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let shots = makeShots()
        Task { @MainActor in
            var written = 0
            for shot in shots {
                for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                    let url = directory.appendingPathComponent("\(shot.name)-\(suffix).png")
                    if await capture(shot, appearance: appearance, to: url) { written += 1 }
                }
            }
            let summary = "Screenshots: \(written) of \(shots.count * 2) written to \(directory.path)"
            logger.info("\(summary, privacy: .public)")
            print(summary)
            NSApp.terminate(nil)
        }
    }

    // MARK: - Screens

    private static func makeShots() -> [Shot] {
        let presets = samplePresetStore()
        let source = "Please review the release notes before Friday and flag anything that blocks the launch."
        let result = "Merci de relire les notes de version avant vendredi et de signaler tout ce qui bloque le lancement."
        let wide = NSSize(width: 832, height: 520)
        let narrow = NSSize(width: 640, height: 520)

        func popup(_ name: String, size: NSSize = wide, input: String = source, cost: String? = nil, _ state: PopupState) -> Shot {
            Shot(name: name, size: size) {
                let vm = PopupViewModel(
                    translationService: TranslationService(provider: { _ in throw ProviderError.unknownProvider(id: "screenshots") }, apiKey: { _ in "" }),
                    presetStore: presets,
                    isAccessibilityGranted: { false },
                    openAccessibilitySettings: {}
                )
                vm.inputText = input
                vm.state = state
                vm.costEstimate = cost
                return AnyView(PopupView(viewModel: vm))
            }
        }

        let history = sampleHistoryStore(presets: presets)
        var shots = [
            popup("popup-idle-empty", input: "", .idle),
            popup("popup-idle", .idle),
            popup("popup-waiting", .streaming(accumulated: "")),
            popup("popup-streaming", .streaming(accumulated: String(result.prefix(40)))),
            popup("popup-done", cost: "96 tokens · $0.0004", .done(result: result)),
            popup("popup-done-narrow", size: narrow, cost: "96 tokens · $0.0004", .done(result: result)),
            popup("popup-partial", .error(message: "The connection closed before the translation finished.", partial: String(result.prefix(40)))),
            popup("popup-error", .error(message: "No internet connection.", partial: nil)),
            popup("popup-missing-key", .missingKey(providerID: "openai")),
            popup("popup-accessibility", input: "", .accessibilityRequired(granted: false)),
        ]
        for tab in [SettingsTab.general, .providers, .presets, .about] {
            shots.append(Shot(name: "settings-\(tab)", size: NSSize(width: 720, height: 552)) {
                let state = SettingsTabState()
                state.selected = tab
                return AnyView(SettingsRoot(tabState: state).environmentObject(presets))
            })
        }
        shots.append(Shot(name: "history", size: HistoryWindowController.defaultContentSize) {
            AnyView(HistorySplitView(store: history, presets: presets))
        })
        // Narrower than the side-by-side width: the columns stack.
        shots.append(Shot(name: "history-narrow", size: NSSize(width: 800, height: 500)) {
            AnyView(HistorySplitView(store: history, presets: presets))
        })
        let imageHistory = sampleImageHistoryStore(presets: presets)
        shots.append(Shot(name: "history-image", size: HistoryWindowController.defaultContentSize) {
            AnyView(HistorySplitView(store: imageHistory, presets: presets))
        })
        for step in WelcomeStep.allCases {
            shots.append(Shot(name: "welcome-\(step)", size: WelcomeView.size) {
                // A fixed shortcut, so the shot does not depend on this Mac's.
                AnyView(WelcomeView(initialStep: step, shortcutKeys: ["⌥", "V"],
                                    provider: ProviderSetupModel(save: { _, _ in }, onSaved: {}),
                                    onClose: { _ in }))
            })
        }
        shots.append(Shot(name: "model-picker", size: NSSize(width: 320, height: 420)) {
            AnyView(ModelPickerPopover(
                selection: .constant("gpt-5.2"),
                models: sampleModels,
                providerName: "OpenAI",
                isBuiltInList: false,
                close: {}
            ))
        })
        for (name, phase) in [
            ("replace-translating", ReplaceHUD.Phase.translating(presetName: "Natural EN ↔ VI")),
            ("replace-done", .replaced),
            ("replace-failed", .failed(message: ReplaceHUD.failureMessage(for: QuickReplaceCoordinator.EmptyResult()))),
        ] {
            shots.append(Shot(name: name, size: NSSize(width: 400, height: 170)) {
                AnyView(ReplaceHUDView(model: ReplaceHUD.Model(phase: phase)).padding(24))
            })
        }
        return shots
    }

    private static let sampleModels: [Model] = [
        "gpt-6-luna", "gpt-5.2", "gpt-5.2-mini", "gpt-5", "gpt-4.1", "gpt-4o", "gpt-4o-mini",
        "o3", "text-embedding-3-large", "tts-1", "whisper-1", "dall-e-3",
    ].map { Model(id: $0, name: $0, supportsVision: false, source: .fetched) }

    private static func samplePresetStore() -> PresetStore {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("transflex-screenshots-\(UUID().uuidString).json")
        let store = PresetStore(fileURL: file)
        try? DefaultPresets.seedIfNeeded(into: store)
        return store
    }

    /// One priced entry, one from a model with no price, one whose preset is gone.
    private static func sampleHistoryStore(presets: PresetStore) -> HistoryStore {
        let store: HistoryStore
        do {
            store = try HistoryStore(inMemory: true)
        } catch {
            fatalError("Cannot create in-memory history: \(error)")
        }
        let now = Date()
        let preset = presets.presets.first?.id ?? UUID()
        let samples: [(String, String, UUID, String, Double?, TimeInterval)] = [
            ("Please review the release notes before Friday.", "Merci de relire les notes de version avant vendredi.",
             preset, "gpt-4o", 0.0004, -600),
            ("See you tomorrow.", "A demain.", preset, "gpt-6-luna", nil, -1_200),
            ("Cette version corrige le bug de connexion.", "This release fixes the sign-in bug.",
             UUID(), "gpt-4o", 0.0004, -86_400),
        ]
        for (input, output, presetID, model, cost, offset) in samples {
            do {
                try store.insert(HistoryEntry(
                    presetID: presetID, providerID: "openai", modelID: model,
                    inputText: input, outputText: output, durationMs: 800, tokenCount: 96,
                    inputTokens: 40, outputTokens: 56, costUSD: cost,
                    createdAt: now.addingTimeInterval(offset)
                ))
            } catch {
                logger.error("Sample history insert failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return store
    }

    /// A translation read from an image: no original text to show.
    private static func sampleImageHistoryStore(presets: PresetStore) -> HistoryStore {
        let store: HistoryStore
        do {
            store = try HistoryStore(inMemory: true)
            try store.insert(HistoryEntry(
                presetID: presets.presets.first?.id ?? UUID(), providerID: "openai", modelID: "gpt-4o",
                inputText: nil, outputText: "Merci de relire les notes de version avant vendredi.",
                hadImage: true, durationMs: 1_400, tokenCount: 880,
                inputTokens: 820, outputTokens: 60, costUSD: 0.0027
            ))
        } catch {
            fatalError("Cannot create in-memory image history: \(error)")
        }
        return store
    }

    // MARK: - Capture

    /// Hosts the view in an off-screen window, lets SwiftUI lay it out, then
    /// draws the window's content into a bitmap. No screen-recording grant needed.
    private static func capture(_ shot: Shot, appearance: NSAppearance.Name, to url: URL) async -> Bool {
        let window = KeyableWindow(
            contentRect: NSRect(origin: NSPoint(x: -10_000, y: -10_000), size: shot.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: shot.view()
            .frame(width: shot.size.width, height: shot.size.height)
            .background(Color(nsColor: .windowBackgroundColor)))
        window.contentView = host
        // Controls draw in their active colours only in the key window.
        window.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 600_000_000)

        defer { window.orderOut(nil) }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return false }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            logger.error("Screenshot write failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}

/// A borderless window that can still be key, so buttons draw as active.
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
