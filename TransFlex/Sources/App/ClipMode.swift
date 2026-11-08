import AppKit
import AVFoundation
import OSLog
import SwiftUI

/// `--clips <dir>`: renders the website's looping clips from the app's real
/// views (the popup and the Replace Selection HUD) over a drawn desktop, in
/// light and dark, writes one H.264 MP4 and one poster PNG each and quits.
/// Like `--screenshots`, no provider is called and no hotkey is registered.
@MainActor
enum ClipMode {
    private static let logger = Logger(subsystem: "io.aiaz.transflex", category: "Clips")
    /// Every movie's size in pixels: 16:10, the width the website shows at most.
    static let movieSize = CGSize(width: 1200, height: 750)

    static func outputDirectory(from arguments: [String]) -> URL? {
        guard let flag = arguments.firstIndex(of: "--clips"), flag + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[flag + 1], isDirectory: true)
    }

    static func run(to directory: URL) {
        NSApp.activate(ignoringOtherApps: true)
        guard !ClipScript.sampleTranslation.isEmpty else {
            fail("Clips: SampleText.json is missing from the app bundle; nothing written")
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Task { @MainActor in
            var written = 0
            let scripts = [ClipScript.hero, .replace]
            for script in scripts {
                for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                    let movie = directory.appendingPathComponent("\(script.name)-\(suffix).mp4")
                    let poster = directory.appendingPathComponent("\(script.name)-\(suffix)-poster.png")
                    do {
                        try await render(script, appearance: appearance, movie: movie, poster: poster)
                        written += 1
                    } catch {
                        logger.error("Clip \(movie.lastPathComponent, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                        // A half-written movie or an older poster would pass for a good one.
                        try? FileManager.default.removeItem(at: movie)
                        try? FileManager.default.removeItem(at: poster)
                    }
                }
            }
            let summary = "Clips: \(written) of \(scripts.count * 2) written to \(directory.path)"
            guard written == scripts.count * 2 else { fail(summary) }
            logger.info("\(summary, privacy: .public)")
            print(summary)
            NSApp.terminate(nil)
        }
    }

    /// Exits non-zero, so a script running `--clips` sees the failure.
    private static func fail(_ message: String) -> Never {
        logger.error("\(message, privacy: .public)")
        print(message)
        exit(1)
    }

    /// One window for the whole clip: each frame swaps the scene's state, lets
    /// SwiftUI lay it out, then draws the window into the movie. The app's own
    /// animations are off, so every frame shows exactly what the script says.
    private static func render(_ script: ClipScript, appearance: NSAppearance.Name, movie: URL, poster: URL) async throws {
        let stage = ClipStage()
        let window = KeyableWindow(
            contentRect: NSRect(origin: NSPoint(x: -10_000, y: -10_000), size: script.canvas),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: ClipSceneView(script: script.name, canvas: script.canvas, stage: stage)
            .frame(width: script.canvas.width, height: script.canvas.height)
            .transaction { $0.disablesAnimations = true })
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        try await Task.sleep(nanoseconds: 600_000_000)

        let writer = try ClipWriter(url: movie, size: movieSize, fps: Int32(ClipScript.fps), bitsPerSecond: script.bitsPerSecond)
        var last: CGImage?
        let count = Int(script.duration * Double(ClipScript.fps))
        for index in 0..<count {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                stage.show(script.frame(at: Double(index) / Double(ClipScript.fps)))
            }
            try await Task.sleep(nanoseconds: 40_000_000)
            // No caret: a blinking insertion point would flicker frame to frame.
            window.makeFirstResponder(nil)
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ClipError.captureFailed }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let image = rep.cgImage else { throw ClipError.captureFailed }
            try await writer.append(image)
            last = image
        }
        try await writer.finish()
        guard let last, let png = ClipWriter.scaled(last, to: movieSize).flatMap({
            NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:])
        }) else { throw ClipError.captureFailed }
        try png.write(to: poster)
    }
}

enum ClipError: Error {
    case captureFailed
    case writerFailed
}

// MARK: - Script

/// What one frame of a clip shows. The hero clip uses the popup fields, the
/// Replace Selection clip the document and HUD fields.
struct ClipFrame: Equatable {
    var keycap: [String]?
    var popupOpacity: Double = 0
    var input = ""
    var state: PopupState = .idle
    var cost: String?
    var documentSentence = ""
    var selected = false
    var hud: ReplaceHUD.Phase?
}

/// A clip's timeline as a pure function of time, so tests can read any frame.
struct ClipScript {
    static let fps = 30
    static let sampleSource = "Please review the release notes before Friday and flag anything that blocks the launch."
    static let sampleTranslation = SampleText.vietnamese["translation"] ?? ""
    static let sampleCost = "96 tokens · $0.0004"
    static let presetName = "Natural EN ↔ VI"

    let name: String
    let duration: TimeInterval
    /// The scene in points, drawn at Retina scale and scaled down to the movie:
    /// smaller than the movie, so the app's text stays readable on the page.
    let canvas: CGSize
    /// Chosen so each movie stays under 1 MB.
    let bitsPerSecond: Int
    private let script: (TimeInterval) -> ClipFrame

    func frame(at time: TimeInterval) -> ClipFrame { script(time) }

    /// ⌥T opens the popup, the copied sentence is pasted, ⌘⏎ translates it
    /// and the translation streams in word by word.
    static let hero = ClipScript(name: "hero", duration: 8, canvas: CGSize(width: 960, height: 600), bitsPerSecond: 700_000) { t in
        var frame = ClipFrame()
        if (0.8..<1.6).contains(t) { frame.keycap = ["⌥", "T"] }
        if (3.0..<3.5).contains(t) { frame.keycap = ["⌘", "⏎"] }
        frame.popupOpacity = min(max((t - 1.6) / 0.4, 0), 1)
        if t >= 2.0 { frame.input = sampleSource }
        if t >= 6.5 {
            frame.state = .done(result: sampleTranslation)
            frame.cost = sampleCost
        } else if t >= 3.5 {
            let words = sampleTranslation.split(separator: " ")
            let shown = min(words.count, Int((t - 3.5) / 3.0 * Double(words.count)) + 1)
            frame.state = .streaming(accumulated: words.prefix(shown).joined(separator: " "))
        }
        return frame
    }

    /// The sentence is selected, the user's own shortcut is pressed (there is
    /// no default one), the HUD says it is translating, then the text is swapped.
    static let replace = ClipScript(name: "replace", duration: 5, canvas: CGSize(width: 720, height: 450), bitsPerSecond: 1_100_000) { t in
        var frame = ClipFrame(documentSentence: sampleSource, selected: true)
        if (1.0..<1.8).contains(t) { frame.keycap = ["Your shortcut"] }
        if (1.8..<3.2).contains(t) { frame.hud = .translating(presetName: presetName) }
        if t >= 3.2 {
            frame.documentSentence = sampleTranslation
            frame.selected = false
            frame.hud = .replaced
        }
        return frame
    }
}

/// Sample output in Vietnamese for `--clips`. It lives in
/// SampleText.json because app source stays English (UserFacingEnglishTextTests).
enum SampleText {
    static let vietnamese: [String: String] = {
        guard let url = Bundle.main.url(forResource: "SampleText", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let strings = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return strings
    }()
}

// MARK: - Scene

@MainActor
final class ClipStage: ObservableObject {
    @Published private(set) var frame = ClipFrame()
    let popup: PopupViewModel
    let hud = ReplaceHUD.Model()

    init() {
        popup = PopupViewModel(
            translationService: TranslationService(provider: { _ in throw ProviderError.unknownProvider(id: "clips") }, apiKey: { _ in "" }),
            presetStore: ScreenshotMode.samplePresetStore(),
            isAccessibilityGranted: { false },
            openAccessibilitySettings: {}
        )
    }

    func show(_ next: ClipFrame) {
        guard next != frame else { return }
        frame = next
        if popup.inputText != next.input { popup.inputText = next.input }
        if popup.state != next.state { popup.state = next.state }
        if popup.costEstimate != next.cost { popup.costEstimate = next.cost }
        if let phase = next.hud, hud.phase != phase { hud.phase = phase }
    }
}

/// The drawn part of a clip: desktop, menu bar, a document window and the key
/// being pressed. The popup and the HUD on top are the app's own views.
private struct ClipSceneView: View {
    let script: String
    let canvas: CGSize
    @ObservedObject var stage: ClipStage
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            desktop
            if script == "hero" { heroContent } else { replaceContent }
            VStack(spacing: 0) {
                menuBar
                Spacer()
                if let keys = stage.frame.keycap { keycap(keys).padding(.bottom, 40) }
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }

    private var desktop: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.11, green: 0.14, blue: 0.17), Color(red: 0.19, green: 0.17, blue: 0.21)]
                : [Color(red: 0.78, green: 0.85, blue: 0.88), Color(red: 0.91, green: 0.88, blue: 0.84)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var menuBar: some View {
        HStack(spacing: 18) {
            ForEach(["File", "Edit", "View", "Window"], id: \.self) { Text($0) }
            Spacer()
            Image("MenuBarIcon").renderingMode(.template).resizable().frame(width: 18, height: 18)
            Text("Sun 9:41")
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 18)
        .frame(height: 26)
        .background(colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.5))
    }

    private func keycap(_ keys: [String]) -> some View {
        Keycaps(keys: keys)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
            .background(Capsule().fill(Color(nsColor: .windowBackgroundColor).opacity(0.96)))
            .overlay(Capsule().stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
    }

    private func document<Body: View>(width: CGFloat, height: CGFloat, @ViewBuilder body: () -> Body) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach(0..<3) { _ in Circle().fill(Color.gray.opacity(0.35)).frame(width: 12, height: 12) }
                Spacer()
                Text("Launch checklist").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 52, height: 12)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            Divider()
            VStack(alignment: .leading, spacing: 12) { body() }
                .font(.system(size: 15))
                .padding(32)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: Radius.window, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.window, style: .continuous)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
    }

    private var heroContent: some View {
        ZStack {
            document(width: 700, height: 460) {
                Text("Launch checklist").font(.system(size: 24, weight: .bold))
                Text(ClipScript.sampleSource)
                Text("The build is signed and the download page is ready.").foregroundStyle(.secondary)
            }
            .offset(x: -110, y: -20)
            PopupView(viewModel: stage.popup)
                .frame(width: 760, height: 420)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: Radius.window, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.window, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
                .scaleEffect(0.96 + 0.04 * stage.frame.popupOpacity)
                .opacity(stage.frame.popupOpacity)
                .offset(x: 50, y: 30)
        }
    }

    private var replaceContent: some View {
        document(width: 640, height: 360) {
            Text("Launch checklist").font(.system(size: 24, weight: .bold))
            Text("The build is signed and the download page is ready.")
            Text("Send the notes to the team once the checks pass.")
            // Last, so the HUD below it covers no text: its material draws clear here.
            Text(stage.frame.documentSentence)
                .background(stage.frame.selected ? Color(nsColor: .selectedTextBackgroundColor) : .clear)
                .fixedSize(horizontal: false, vertical: true)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 20))
                        .shadow(color: .black.opacity(0.25), radius: 1)
                        .offset(x: 14, y: 14)
                }
                .overlay(alignment: .topTrailing) {
                    if stage.frame.hud != nil {
                        ReplaceHUDView(model: stage.hud)
                            .fixedSize()
                            .offset(x: 20, y: 48)
                    }
                }
        }
        .offset(y: 14)
    }
}

// MARK: - Writer

/// Writes CGImages, one per frame, into an H.264 MP4 of a fixed size; an
/// image of another size (a Retina capture) is scaled to fit.
@MainActor
final class ClipWriter {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let size: CGSize
    private let fps: Int32
    private var frames: Int64 = 0

    init(url: URL, size: CGSize, fps: Int32, bitsPerSecond: Int) throws {
        try? FileManager.default.removeItem(at: url)
        self.size = size
        self.fps = fps
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitsPerSecond,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2,
            ],
        ])
        input.expectsMediaDataInRealTime = false
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? ClipError.writerFailed }
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ image: CGImage) async throws {
        while !input.isReadyForMoreMediaData {
            // A failed writer is never ready again.
            guard writer.status == .writing else { throw writer.error ?? ClipError.writerFailed }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        var made: CVPixelBuffer?
        guard let pool = adaptor.pixelBufferPool,
              CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made) == kCVReturnSuccess,
              let buffer = made else { throw writer.error ?? ClipError.writerFailed }
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard context != nil,
              adaptor.append(buffer, withPresentationTime: CMTime(value: frames, timescale: fps))
        else { throw writer.error ?? ClipError.writerFailed }
        frames += 1
    }

    func finish() async throws {
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: frames, timescale: fps))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? ClipError.writerFailed }
    }

    static func scaled(_ image: CGImage, to size: CGSize) -> CGImage? {
        let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: size))
        return context?.makeImage()
    }
}
