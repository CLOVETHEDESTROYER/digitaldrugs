import Foundation
import CoreGraphics

enum StudioCTAStyle: String, CaseIterable, Codable, Identifiable {
    case pill, card
    var id: String { rawValue }
    var title: String { self == .pill ? "Outlined pill" : "Filled card" }
}
enum StudioCTAPlacement: String, CaseIterable, Codable, Identifiable {
    case lower, upper
    var id: String { rawValue }
    var title: String { self == .lower ? "Below captions" : "Above captions" }
}
enum StudioCTATiming: String, CaseIterable, Codable, Identifiable {
    case always, delayed, recurring
    var id: String { rawValue }
    var title: String { switch self { case .always: "Throughout clip"; case .delayed: "After a delay"; case .recurring: "Repeat during live session" } }
}

struct StudioCallToAction: Codable, Equatable {
    var enabled = false
    var headline = "Comment {keyword}"
    var detail = "Share your intention below"
    var keyword = "CALM"
    var style: StudioCTAStyle = .card
    var placement: StudioCTAPlacement = .lower
    var timing: StudioCTATiming = .delayed
    var delay = 3.0
    var interval = 60.0
    var visibleSeconds = 12.0
    /// Exported for a future comment-to-destination integration. Never opened or sent automatically.
    var destinationURL = ""
    var campaign = ""
    var usesKeyword: Bool { headline.contains("{keyword}") && !normalizedKeyword.isEmpty }
    var renderedHeadline: String { headline.replacingOccurrences(of: "{keyword}", with: normalizedKeyword) }
    var normalizedKeyword: String { keyword.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    var postingText: String { [renderedHeadline, detail].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n") }
    func opacity(at time: Double) -> Double {
        guard enabled, time.isFinite, time >= 0, !renderedHeadline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 0 }
        if timing == .always { return 1 }
        let start = min(120, max(0, delay)), elapsed = time - start
        guard elapsed >= 0 else { return 0 }
        if timing == .delayed { return min(1, elapsed / 0.35) }
        let cycle = min(300, max(15, interval)), span = min(cycle - 1, max(3, visibleSeconds))
        let phase = elapsed.truncatingRemainder(dividingBy: cycle)
        guard phase < span else { return 0 }
        return min(1, phase / 0.35, (span - phase) / 0.35)
    }
    static func rect(width: CGFloat, height: CGFloat, placement: StudioCTAPlacement, style: Int = 0) -> CGRect {
        let h = height * 0.095
        return CGRect(x: width * 0.12, y: height * (placement == .lower ? 0.30 : style == 33 ? 0.80 : 0.665), width: width * 0.76, height: h)
    }
    /// Preserve the existing caption layout when CTA is off. Enabled layouts reserve a separate band.
    static func captionRect(width: CGFloat, height: CGFloat, settings: ExportSettings) -> CGRect {
        let on = settings.callToAction.enabled
        if settings.style == 33 {
            let lower = on && settings.callToAction.placement == .lower
            return CGRect(x: width * 0.12, y: height * (lower ? 0.405 : 0.21), width: width * 0.76, height: height * (lower ? 0.12 : 0.13))
        }
        return CGRect(x: width * 0.12, y: height * (on ? 0.42 : 0.32), width: width * 0.76, height: height * (on ? 0.21 : 0.32))
    }
    static func columnArtRect(width: CGFloat, height: CGFloat, settings: ExportSettings) -> CGRect {
        let on = settings.callToAction.enabled, upper = settings.callToAction.placement == .upper
        let y: CGFloat, h: CGFloat
        if on && upper { y = settings.captions ? 0.36 : 0.22; h = settings.captions ? 0.42 : 0.56 }
        else if on { y = settings.captions ? 0.54 : 0.42; h = settings.captions ? 0.39 : 0.51 }
        else { y = settings.captions ? 0.35 : 0.22; h = settings.captions ? 0.59 : 0.70 }
        return CGRect(x: width * 0.04, y: height * y, width: width * 0.92, height: height * h)
    }

}

struct StudioFollowUpReceipt: Codable, Equatable {
    var schemaVersion = 1
    let campaign: String
    let commentKeyword: String?
    let headline: String
    let supportingText: String
    let destinationURL: String
    var clickableInVideo = false
    var automationConnected = false
    init(_ cta: StudioCallToAction) {
        campaign = cta.campaign
        commentKeyword = cta.usesKeyword ? cta.normalizedKeyword : nil
        headline = cta.renderedHeadline; supportingText = cta.detail; destinationURL = cta.destinationURL
    }
}
