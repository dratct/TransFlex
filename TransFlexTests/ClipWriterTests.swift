import AppKit
import AVFoundation
import XCTest
@testable import TransFlex

@MainActor
final class ClipWriterTests: XCTestCase {
    private func solidImage(width: Int, height: Int) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
    }

    func testOneSecondAtThirtyFramesIsAOneSecondH264Movie() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        let size = CGSize(width: 160, height: 100)
        let writer = try ClipWriter(url: url, size: size, fps: 30, bitsPerSecond: 400_000)
        // Bigger than the movie, as a Retina capture is: the writer scales it down.
        let image = try solidImage(width: 320, height: 200)
        for _ in 0..<30 { try await writer.append(image) }
        try await writer.finish()

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, 1, accuracy: 0.5 / 30, "all 30 frames, each 1/30 s")
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let (naturalSize, formats) = try await track.load(.naturalSize, .formatDescriptions)
        XCTAssertEqual(naturalSize, size)
        XCTAssertEqual(formats.first.map(CMFormatDescriptionGetMediaSubType), kCMVideoCodecType_H264)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let frame = try generator.copyCGImage(at: CMTime(value: 15, timescale: 30), actualTime: nil)
        let color = try XCTUnwrap(NSBitmapImageRep(cgImage: frame).colorAt(x: 80, y: 50)?.usingColorSpace(.sRGB))
        // Channels in order, not a black frame. Exact levels are not compared:
        // the image generator decodes this movie about 0.1 lighter than written,
        // while Chromium shows it within 2% of the PNG it was made from.
        XCTAssertGreaterThan(color.greenComponent, color.blueComponent + 0.05)
        XCTAssertGreaterThan(color.blueComponent, color.redComponent + 0.1)
        XCTAssertGreaterThan(color.redComponent, 0.1)
    }
}
