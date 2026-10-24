import XCTest
import AVFoundation
@testable import ZenWaveStudio

final class CallToActionTests: XCTestCase {
    private func bytes(_ image: CGImage) -> Data {
        var data = Data(count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { raw in
            let c = CGContext(data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }; return data
    }
    func testTimingKeywordsAndBackwardCompatibility() throws {
        let old = try JSONDecoder().decode(ExportSettings.self, from: Data(#"{"style":10,"heading":"Daily intention"}"#.utf8))
        XCTAssertFalse(old.callToAction.enabled); XCTAssertEqual(old.headingEmphasis, 1)
        var cta = StudioCallToAction(); XCTAssertEqual(cta.opacity(at: 9), 0)
        cta.enabled = true; cta.keyword = "  abundance  "; cta.delay = 3
        XCTAssertEqual(cta.renderedHeadline, "Comment ABUNDANCE")
        XCTAssertEqual(cta.opacity(at: 2.9), 0); XCTAssertEqual(cta.opacity(at: 3), 0); XCTAssertEqual(cta.opacity(at: 4), 1)
        cta.timing = .recurring; cta.interval = 60; cta.visibleSeconds = 12
        XCTAssertEqual(cta.opacity(at: 4), 1); XCTAssertEqual(cta.opacity(at: 16), 0)
        XCTAssertEqual(cta.opacity(at: 64), 1); XCTAssertEqual(cta.opacity(at: 76), 0)
        XCTAssertEqual(cta.opacity(at: -.infinity), 0); XCTAssertEqual(cta.opacity(at: .nan), 0)
        let receipt = StudioFollowUpReceipt(cta)
        XCTAssertEqual(receipt.commentKeyword, "ABUNDANCE"); XCTAssertFalse(receipt.clickableInVideo); XCTAssertFalse(receipt.automationConnected)
        cta.headline = "Save this for later"; XCTAssertNil(StudioFollowUpReceipt(cta).commentKeyword)
        var settings = ExportSettings(); settings.callToAction = cta
        XCTAssertEqual(try JSONDecoder().decode(ExportSettings.self, from: JSONEncoder().encode(settings)), settings)
    }
    func testCallToActionCaptionBrandAndColumnRegionsNeverIntersect() {
        for format in VideoFormat.allCases {
            let w = CGFloat(format.width), h = CGFloat(format.height)
            let frame = CGRect(x: 0, y: 0, width: w, height: h)
            for style in [10, 33, 34, 35] {
                for placement in StudioCTAPlacement.allCases {
                    for brand in StudioBrandStyle.allCases {
                        var settings = ExportSettings(); settings.style = style; settings.brandStyle = brand
                        settings.logoSize = 0.20; settings.callToAction.enabled = true; settings.callToAction.placement = placement
                        let cta = StudioCallToAction.rect(width: w, height: h, placement: placement, style: style)
                        let caption = StudioCallToAction.captionRect(width: w, height: h, settings: settings)
                        let logo = StudioBranding.logoRect(width: w, height: h, settings: settings)
                        XCTAssertTrue(frame.contains(cta)); XCTAssertTrue(frame.contains(caption))
                        XCTAssertFalse(cta.intersects(caption)); XCTAssertFalse(cta.intersects(logo)); XCTAssertFalse(caption.intersects(logo))
                        if style == 33 {
                            let art = StudioCallToAction.columnArtRect(width: w, height: h, settings: settings)
                            XCTAssertFalse(art.intersects(cta)); XCTAssertFalse(art.intersects(caption)); XCTAssertTrue(frame.contains(art))
                        }
                    }
                }
            }
        }
    }
    func testDisabledCallToActionDoesNotAlterPixelsAndEnabledRendersAllLayouts() throws {
        let renderer = try FrameRenderer(), mantra = try XCTUnwrap(StudioResources.library().first)
        let envelope = AudioEnvelope(silence: 90)
        for format in VideoFormat.allCases {
            for style in [10, 33, 34, 35] {
                var settings = ExportSettings(); settings.style = style; settings.format = format
                func render(_ time: Double) throws -> Data { bytes(try renderer.frame(width: format.width / 5, height: format.height / 5, time: time, audioTime: time, envelope: envelope, mantra: mantra, settings: settings)) }
                let baseline = try render(4)
                settings.callToAction.keyword = "CHAKRA"; settings.callToAction.headline = "Start with {keyword}"
                XCTAssertEqual(try render(4), baseline)
                settings.callToAction.enabled = true
                for placement in StudioCTAPlacement.allCases {
                    for style in StudioCTAStyle.allCases {
                        settings.callToAction.placement = placement; settings.callToAction.style = style
                        XCTAssertNotEqual(try render(4), baseline)
                        XCTAssertEqual(try render(4), try render(4), "Seek/replay must be deterministic")
                    }
                }
            }
        }
    }
    func testBatchExportIncludesPostingCTAAndStructuredFollowUpDetails() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cta-batch-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let library = try StudioResources.library(), mantra = try XCTUnwrap(library.first { $0.id == "career-confidence-morning" })
        var settings = ExportSettings(); settings.style = 34; settings.callToAction.enabled = true
        settings.callToAction.keyword = "CALM"; settings.callToAction.campaign = "Calm test"
        settings.callToAction.destinationURL = "https://example.com/calm"
        let plan = try RandomBatchPlan.make(count: 1, seed: 31, mantras: [mantra.id], styles: [34], palettes: [1], settings: settings, backgroundFile: nil, postFooter: "Daily practice")
        let folder = root.appendingPathComponent("batch")
        _ = try await RandomBatchExporter.export(plan: plan, library: library, background: nil, folder: folder, widthOverride: 168, heightOverride: 300, recordHistory: false) { _, _ in }
        let output = folder.appendingPathComponent(plan.clips[0].fileName)
        let cta = try JSONDecoder().decode(StudioFollowUpReceipt.self, from: Data(contentsOf: output.deletingPathExtension().appendingPathExtension("cta.json")))
        XCTAssertEqual(cta.commentKeyword, "CALM"); XCTAssertEqual(cta.campaign, "Calm test"); XCTAssertEqual(cta.destinationURL, "https://example.com/calm")
        let posting = try String(contentsOf: output.deletingPathExtension().appendingPathExtension("txt"))
        XCTAssertTrue(posting.contains("Comment CALM")); XCTAssertTrue(posting.contains("Daily practice"))
        let receipt = try JSONDecoder().decode(ExportReceipt.self, from: Data(contentsOf: output.deletingPathExtension().appendingPathExtension("json")))
        XCTAssertEqual(receipt.settings.callToAction.keyword, "CALM")
    }
    func testLiveCTAIsCompositedOnceAfterSceneDissolve() throws {
        let library = try StudioResources.library(), mantra = try XCTUnwrap(library.first)
        var plan = LivePlan(); plan.evolving = false; plan.transition = 8
        plan.chapters = [LiveChapter(mantraID: mantra.id, seconds: 45, style: 33), LiveChapter(mantraID: mantra.id, seconds: 45, style: 34)]
        let timeline = try LiveTimeline.make(plan: plan, library: library, lengths: [mantra.id: 10])
        let live = LiveFrameRenderer(), renderer = try FrameRenderer(), envelope = AudioEnvelope(silence: 90)
        var settings = ExportSettings(); settings.callToAction.enabled = true; settings.callToAction.placement = .upper
        settings.callToAction.timing = .always
        let time = 48.0, current = timeline.visual(at: time, base: settings)
        let actual = try live.frame(width: 168, height: 300, time: time, envelope: envelope, timeline: timeline, settings: settings)
        let blend = try XCTUnwrap(timeline.blend(at: time))
        var previous = timeline.visual(at: blend.previousTime, base: settings); previous.heading = current.heading
        let old = try renderer.frame(width: 168, height: 300, time: time, audioTime: time, envelope: envelope, mantra: timeline.mantra, settings: previous, includeCallToAction: false)
        let new = try renderer.frame(width: 168, height: 300, time: time, audioTime: time, envelope: envelope, mantra: timeline.mantra, settings: current, includeCallToAction: false)
        let c = CGContext(data: nil, width: 168, height: 300, bitsPerComponent: 8, bytesPerRow: 168 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let rect = CGRect(x: 0, y: 0, width: 168, height: 300)
        c.draw(old, in: rect); c.setAlpha(blend.alpha); c.draw(new, in: rect)
        let expected = try renderer.overlayCallToAction(on: c.makeImage()!, time: time, settings: current)
        XCTAssertEqual(bytes(actual), bytes(expected))
    }
}
