//
//  GamificationManager.swift
//  DigitalDrug
//

import Foundation

enum GamificationCompletionKind: String, Codable, CaseIterable {
    case generator
    case ritualPreset
    case guidedGateway
    case quantumCode
    case manifestation
    case chakra
    case chakraProgression
    case challenge
    case journal
}

struct GamificationCompletionEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let kind: GamificationCompletionKind
    let title: String
    let ritualID: String?
    let module: String?
}

struct AstralRank: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let requirement: String
}

struct PracticeBadge: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let isPremium: Bool
    let requirement: String
}

struct GamificationState: Codable, Hashable {
    var completions: [GamificationCompletionEvent] = []
    var earnedBadgeIDs: Set<String> = []
    var challengeProgress: [String: Int] = [:]
    var activeChallengeID: String?
    var hasMigratedLegacyChallengeProgress = false
    var hasOfferedReminderSetup = false
    var completedJourneyStepIDs: Set<String> = []
    var journeyStartedAt: Date?

    init(
        completions: [GamificationCompletionEvent] = [],
        earnedBadgeIDs: Set<String> = [],
        challengeProgress: [String: Int] = [:],
        activeChallengeID: String? = nil,
        hasMigratedLegacyChallengeProgress: Bool = false,
        hasOfferedReminderSetup: Bool = false,
        completedJourneyStepIDs: Set<String> = [],
        journeyStartedAt: Date? = nil
    ) {
        self.completions = completions
        self.earnedBadgeIDs = earnedBadgeIDs
        self.challengeProgress = challengeProgress
        self.activeChallengeID = activeChallengeID
        self.hasMigratedLegacyChallengeProgress = hasMigratedLegacyChallengeProgress
        self.hasOfferedReminderSetup = hasOfferedReminderSetup
        self.completedJourneyStepIDs = completedJourneyStepIDs
        self.journeyStartedAt = journeyStartedAt
    }

    private enum CodingKeys: String, CodingKey {
        case completions, earnedBadgeIDs, challengeProgress, activeChallengeID
        case hasMigratedLegacyChallengeProgress, hasOfferedReminderSetup
        case completedJourneyStepIDs, journeyStartedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            completions: try container.decodeIfPresent([GamificationCompletionEvent].self, forKey: .completions) ?? [],
            earnedBadgeIDs: try container.decodeIfPresent(Set<String>.self, forKey: .earnedBadgeIDs) ?? [],
            challengeProgress: try container.decodeIfPresent([String: Int].self, forKey: .challengeProgress) ?? [:],
            activeChallengeID: try container.decodeIfPresent(String.self, forKey: .activeChallengeID),
            hasMigratedLegacyChallengeProgress: try container.decodeIfPresent(Bool.self, forKey: .hasMigratedLegacyChallengeProgress) ?? false,
            hasOfferedReminderSetup: try container.decodeIfPresent(Bool.self, forKey: .hasOfferedReminderSetup) ?? false,
            completedJourneyStepIDs: try container.decodeIfPresent(Set<String>.self, forKey: .completedJourneyStepIDs) ?? [],
            journeyStartedAt: try container.decodeIfPresent(Date.self, forKey: .journeyStartedAt)
        )
    }
}

struct PracticeJourneyStep: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let ritualID: String
    let systemImage: String
}

@MainActor
final class GamificationManager: ObservableObject {
    static let storageKey = "zenwaveGamificationState"

    @Published private(set) var state: GamificationState
    @Published var shouldOfferReminderSetup = false

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(GamificationState.self, from: data) {
            state = decoded
        } else {
            state = GamificationState()
        }

        refreshEarnedBadges()
        shouldOfferReminderSetup = !state.hasOfferedReminderSetup && !state.completions.isEmpty
    }

    var totalSessions: Int {
        state.completions.filter { $0.kind != .journal }.count
    }

    var generatorSessions: Int {
        state.completions.filter { $0.kind == .generator }.count
    }

    var premiumRitualSessions: Int {
        state.completions.filter { [.ritualPreset, .guidedGateway, .quantumCode, .manifestation, .chakra, .chakraProgression, .challenge].contains($0.kind) }.count
    }

    var journalEntries: Int {
        state.completions.filter { $0.kind == .journal }.count
    }

    var completedRitualIDs: Set<String> {
        Set(state.completions.compactMap(\.ritualID))
    }

    var currentStreak: Int {
        streakStats.current
    }

    var longestStreak: Int {
        streakStats.longest
    }

    var currentRank: AstralRank {
        Self.ranks.last(where: { isRankUnlocked($0) }) ?? Self.ranks[0]
    }

    var nextRank: AstralRank? {
        Self.ranks.first(where: { !isRankUnlocked($0) })
    }

    var earnedBadges: [PracticeBadge] {
        Self.badges.filter { state.earnedBadgeIDs.contains($0.id) }
    }

    var lockedBadges: [PracticeBadge] {
        Self.badges.filter { !state.earnedBadgeIDs.contains($0.id) }
    }

    var activeChallengeProgressLabel: String? {
        guard let activeChallengeID = state.activeChallengeID,
              let completed = state.challengeProgress[activeChallengeID],
              completed > 0 else {
            return nil
        }

        let title = Self.challengeTitle(for: activeChallengeID)
        return "\(title): \(completed) day\(completed == 1 ? "" : "s") complete"
    }

    var recommendedNextPracticeTitle: String {
        if !completedRitualIDs.contains("focus-10") {
            return "Focus 10"
        }
        if !completedRitualIDs.contains("focus-12") {
            return "Focus 12"
        }
        if !completedRitualIDs.contains("energy-shield") {
            return "Energy Shield"
        }
        if !completedRitualIDs.contains("pattern-builder") {
            return "Pattern Builder"
        }
        return "Astral Projection Prep"
    }

    var gatewayFoundationSteps: [PracticeJourneyStep] {
        Self.gatewayFoundationSteps
    }

    var gatewayFoundationCompletedCount: Int {
        Self.gatewayFoundationSteps.filter { state.completedJourneyStepIDs.contains($0.id) }.count
    }

    var gatewayFoundationProgress: Double {
        guard !Self.gatewayFoundationSteps.isEmpty else { return 0 }
        return Double(gatewayFoundationCompletedCount) / Double(Self.gatewayFoundationSteps.count)
    }

    var nextGatewayFoundationStep: PracticeJourneyStep? {
        Self.gatewayFoundationSteps.first { !state.completedJourneyStepIDs.contains($0.id) }
    }

    func gatewayFoundationReward(for ritualID: String) -> (completedDay: Int, nextStep: PracticeJourneyStep?)? {
        guard let index = Self.gatewayFoundationSteps.firstIndex(where: { $0.ritualID == ritualID }),
              !state.completedJourneyStepIDs.contains(Self.gatewayFoundationSteps[index].id) else {
            return nil
        }
        return (index + 1, Self.gatewayFoundationSteps[safe: index + 1])
    }

    func recordCompletion(
        kind: GamificationCompletionKind,
        title: String,
        ritualID: String? = nil,
        module: String? = nil,
        date: Date = Date()
    ) {
        let event = GamificationCompletionEvent(
            id: UUID(),
            date: date,
            kind: kind,
            title: title,
            ritualID: ritualID,
            module: module
        )

        state.completions.insert(event, at: 0)
        state.completions = Array(state.completions.prefix(500))
        refreshEarnedBadges()
        persist()

        AppLog.info("Gamification completion recorded: kind=\(kind.rawValue), title=\(title), total=\(totalSessions)")

        if totalSessions == 1 && !state.hasOfferedReminderSetup {
            shouldOfferReminderSetup = true
        }
    }

    func recordGatewayFoundationCompletion(ritualID: String) {
        guard let step = Self.gatewayFoundationSteps.first(where: { $0.ritualID == ritualID }),
              !state.completedJourneyStepIDs.contains(step.id) else {
            return
        }

        state.completedJourneyStepIDs.insert(step.id)
        state.journeyStartedAt = state.journeyStartedAt ?? Date()
        persist()
        AppLog.info("Gateway Foundations advanced: \(step.title), day=\(gatewayFoundationCompletedCount)")
    }

    func recordChallengeProgress(challengeID: String, completedDays: Int, dayCount: Int, title: String) {
        let previous = state.challengeProgress[challengeID, default: 0]
        state.activeChallengeID = challengeID
        state.challengeProgress[challengeID] = max(previous, completedDays)

        if completedDays > previous {
            recordCompletion(
                kind: .challenge,
                title: "\(title) Day \(min(completedDays, dayCount))",
                ritualID: challengeID,
                module: "Challenge"
            )
        } else {
            refreshEarnedBadges()
            persist()
        }
    }

    func migrateChallengeProgressIfNeeded(from legacyProgress: [String: Int]) {
        guard !state.hasMigratedLegacyChallengeProgress else { return }

        for (challengeID, completedDays) in legacyProgress where completedDays > 0 {
            state.challengeProgress[challengeID] = max(state.challengeProgress[challengeID, default: 0], completedDays)
        }

        state.hasMigratedLegacyChallengeProgress = true
        refreshEarnedBadges()
        persist()
    }

    func markReminderOfferHandled() {
        state.hasOfferedReminderSetup = true
        shouldOfferReminderSetup = false
        persist()
    }

    func resetProgress() {
        state = GamificationState(hasMigratedLegacyChallengeProgress: true, hasOfferedReminderSetup: true)
        shouldOfferReminderSetup = false
        persist()
        AppLog.info("Gamification progress reset")
    }

    func isRankUnlocked(_ rank: AstralRank) -> Bool {
        switch rank.id {
        case "seeker":
            return true
        case "resonant-breather":
            return totalSessions >= 3 || completedRitualIDs.contains("resonant-breath-reset")
        case "focus-10-initiate":
            return completedRitualIDs.contains("focus-10")
        case "focus-12-explorer":
            return completedRitualIDs.contains("focus-12")
        case "boundary-builder":
            return completedRitualIDs.contains("energy-shield")
        case "pattern-weaver":
            return completedRitualIDs.contains("pattern-builder") || completedRitualIDs.contains("abundance-code")
        case "astral-adept":
            return completedRitualIDs.contains("astral-projection-prep-guided") && premiumRitualSessions >= 12
        default:
            return false
        }
    }

    private func refreshEarnedBadges() {
        var earned = Set<String>()
        for badge in Self.badges where isBadgeUnlocked(badge) {
            earned.insert(badge.id)
        }
        state.earnedBadgeIDs = earned
    }

    private func isBadgeUnlocked(_ badge: PracticeBadge) -> Bool {
        switch badge.id {
        case "first-signal":
            return totalSessions >= 1
        case "three-day-streak":
            return longestStreak >= 3
        case "seven-night-theta":
            return state.challengeProgress["seven-nights-theta", default: 0] >= 7
        case "focus-10-complete":
            return completedRitualIDs.contains("focus-10")
        case "release-box-complete":
            return completedRitualIDs.contains("release-box")
        case "energy-shield-complete":
            return completedRitualIDs.contains("energy-shield")
        case "dream-journaler":
            return journalEntries >= 1
        case "chakra-grounded":
            return completedRitualIDs.contains("chakra-root") || completedRitualIDs.contains("root-chakra-grounding") || completedRitualIDs.contains("seven-days-root")
        case "quantum-reflection":
            return state.completions.contains { $0.kind == .quantumCode }
        case "intention-in-motion":
            return state.completions.contains { $0.kind == .manifestation }
        default:
            return false
        }
    }

    private var streakStats: (current: Int, longest: Int) {
        let calendar = Calendar.current
        let days = Set(state.completions.filter { $0.kind != .journal }.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return (0, 0) }

        let sortedDays = days.sorted()
        var longest = 1
        var run = 1

        for index in sortedDays.indices.dropFirst() {
            let previous = sortedDays[sortedDays.index(before: index)]
            let current = sortedDays[index]
            if calendar.dateComponents([.day], from: previous, to: current).day == 1 {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        guard let lastDay = sortedDays.last,
              lastDay == today || lastDay == yesterday else {
            return (0, longest)
        }

        var currentStreak = 0
        var cursor = lastDay
        while days.contains(cursor) {
            currentStreak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return (currentStreak, longest)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func challengeTitle(for id: String) -> String {
        switch id {
        case "seven-nights-theta": return "7 Nights of Theta"
        case "seven-days-root": return "7 Days Root Grounding"
        case "astral-prep-three": return "3-Day Astral Projection Prep"
        default: return "Active Challenge"
        }
    }

    static let ranks: [AstralRank] = [
        AstralRank(id: "seeker", title: "Seeker", subtitle: "You opened the practice path.", requirement: "Start any ZenWave session."),
        AstralRank(id: "resonant-breather", title: "Resonant Breather", subtitle: "You are building consistency.", requirement: "Complete 3 sessions or Resonant Breath Reset."),
        AstralRank(id: "focus-10-initiate", title: "Focus 10 Initiate", subtitle: "Mind awake, body relaxed.", requirement: "Complete Focus 10."),
        AstralRank(id: "focus-12-explorer", title: "Focus 12 Explorer", subtitle: "Practice expanded awareness.", requirement: "Complete Focus 12."),
        AstralRank(id: "boundary-builder", title: "Boundary Builder", subtitle: "Create a calm practice container.", requirement: "Complete Energy Shield."),
        AstralRank(id: "pattern-weaver", title: "Pattern Weaver", subtitle: "Pair visualization with action.", requirement: "Complete Pattern Builder or Abundance Pattern."),
        AstralRank(id: "astral-adept", title: "Astral Adept", subtitle: "A steady inner exploration practice.", requirement: "Complete Astral Projection Prep and 12 premium rituals.")
    ]

    static let badges: [PracticeBadge] = [
        PracticeBadge(id: "first-signal", title: "First Signal", subtitle: "Completed your first session.", systemImage: "waveform.circle.fill", isPremium: false, requirement: "Complete any session."),
        PracticeBadge(id: "three-day-streak", title: "Three-Day Streak", subtitle: "Returned three days in a row.", systemImage: "flame.fill", isPremium: false, requirement: "Complete sessions on 3 consecutive days."),
        PracticeBadge(id: "seven-night-theta", title: "Seven-Night Theta", subtitle: "Finished the theta challenge.", systemImage: "moon.stars.fill", isPremium: true, requirement: "Complete 7 Nights of Theta."),
        PracticeBadge(id: "focus-10-complete", title: "Focus 10 Complete", subtitle: "Practiced mind awake, body relaxed.", systemImage: "circle.dotted", isPremium: true, requirement: "Complete Focus 10."),
        PracticeBadge(id: "release-box-complete", title: "Release Box", subtitle: "Set down a distraction loop.", systemImage: "shippingbox.fill", isPremium: true, requirement: "Complete Release Box."),
        PracticeBadge(id: "energy-shield-complete", title: "Energy Shield", subtitle: "Built a calm boundary.", systemImage: "shield.lefthalf.filled", isPremium: true, requirement: "Complete Energy Shield."),
        PracticeBadge(id: "dream-journaler", title: "Dream Journaler", subtitle: "Saved a ritual reflection.", systemImage: "book.closed.fill", isPremium: true, requirement: "Save any ritual journal entry."),
        PracticeBadge(id: "chakra-grounded", title: "Chakra Grounded", subtitle: "Practiced a root grounding signal.", systemImage: "circle.hexagongrid.fill", isPremium: true, requirement: "Use Root Chakra or Root Grounding."),
        PracticeBadge(id: "quantum-reflection", title: "Quantum Reflection", subtitle: "Completed a code ritual.", systemImage: "number.circle.fill", isPremium: true, requirement: "Complete any Quantum Code ritual."),
        PracticeBadge(id: "intention-in-motion", title: "Intention in Motion", subtitle: "Paired an affirmation with action.", systemImage: "sparkles.rectangle.stack.fill", isPremium: true, requirement: "Complete a manifestation ritual.")
    ]

    static let gatewayFoundationSteps: [PracticeJourneyStep] = [
        PracticeJourneyStep(id: "foundation-breath", title: "Resonant Breath", subtitle: "Create a calm starting point.", ritualID: "resonant-breath-reset", systemImage: "wind"),
        PracticeJourneyStep(id: "foundation-focus-10", title: "Focus 10", subtitle: "Practice relaxed awareness.", ritualID: "focus-10", systemImage: "circle.dotted"),
        PracticeJourneyStep(id: "foundation-release", title: "Release Box", subtitle: "Set down a distraction loop.", ritualID: "release-box", systemImage: "shippingbox.fill"),
        PracticeJourneyStep(id: "foundation-focus-12", title: "Focus 12", subtitle: "Explore a wider field of attention.", ritualID: "focus-12", systemImage: "sparkles"),
        PracticeJourneyStep(id: "foundation-boundary", title: "Energy Shield", subtitle: "Build a grounded practice container.", ritualID: "energy-shield", systemImage: "shield.lefthalf.filled"),
        PracticeJourneyStep(id: "foundation-pattern", title: "Pattern Builder", subtitle: "Pair a visualization with one real action.", ritualID: "pattern-builder", systemImage: "point.3.connected.trianglepath.dotted"),
        PracticeJourneyStep(id: "foundation-return", title: "Return + Reflect", subtitle: "Close with a grounded reflection.", ritualID: "astral-projection-prep-guided", systemImage: "moon.stars.fill")
    ]
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
