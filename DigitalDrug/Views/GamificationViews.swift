//
//  GamificationViews.swift
//  DigitalDrug
//

import SwiftUI

struct ReminderSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gamificationManager: GamificationManager
    @EnvironmentObject private var notificationManager: RitualNotificationManager
    @State private var reminderTime = Date()
    @State private var includeChallengeReminder = true
    @State private var isRequesting = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()

                VStack(spacing: 22) {
                    LiquidGlassCard(cornerRadius: 34, showParticles: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Keep your ritual path alive", systemImage: "bell.badge.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)

                            Text("Choose a reminder time for calm practice, visualization, and consistency. You can change this anytime in Settings.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)

                            Toggle("Include challenge continuation reminders", isOn: $includeChallengeReminder)
                                .toggleStyle(SwitchToggleStyle(tint: ZenWavePalette.electricPurple))
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            gamificationManager.markReminderOfferHandled()
                            dismiss()
                        } label: {
                            Text("Not Now")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            isRequesting = true
                            Task { @MainActor in
                                await notificationManager.requestPermissionAndSchedule(
                                    date: reminderTime,
                                    includeChallengeReminder: includeChallengeReminder
                                )
                                gamificationManager.markReminderOfferHandled()
                                isRequesting = false
                                dismiss()
                            }
                        } label: {
                            Label(isRequesting ? "Requesting" : "Enable", systemImage: "bell.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ZenWavePalette.electricPurple)
                        .disabled(isRequesting)
                    }
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Ritual Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                reminderTime = notificationManager.selectedReminderDate
            }
        }
    }
}

struct AstralPathSummaryCard: View {
    @ObservedObject var gamificationManager: GamificationManager
    let isPremiumUnlocked: Bool
    var showsPrimaryAction = true
    let onPrimaryAction: () -> Void

    var body: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Astral Path", systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ZenWavePalette.electricPurple)

                        Text(gamificationManager.currentRank.title)
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text(gamificationManager.currentRank.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(gamificationManager.currentStreak)")
                            .font(.title.bold())
                        Text("day streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    statPill("\(gamificationManager.totalSessions)", "sessions")
                    statPill("\(gamificationManager.generatorSessions)", "free signals")
                    statPill("\(gamificationManager.earnedBadges.count)", "badges")
                }

                if let active = gamificationManager.activeChallengeProgressLabel, isPremiumUnlocked {
                    Text(active)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }

                if let nextRank = gamificationManager.nextRank {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Next: \(nextRank.title)")
                            .font(.subheadline.weight(.semibold))
                        Text(nextRank.requirement)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if showsPrimaryAction {
                    Button(action: onPrimaryAction) {
                        Label(
                            isPremiumUnlocked ? "Practice \(gamificationManager.recommendedNextPracticeTitle)" : "Preview Premium Path",
                            systemImage: isPremiumUnlocked ? "play.fill" : "lock.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ZenWavePalette.electricPurple)
                }
            }
        }
    }

    private func statPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }
}

struct GatewayFoundationsMapView: View {
    @ObservedObject var gamificationManager: GamificationManager
    let isPremiumUnlocked: Bool
    let onSelectNext: () -> Void
    let onOpenConstellation: () -> Void

    private var steps: [PracticeJourneyStep] {
        gamificationManager.gatewayFoundationSteps
    }

    var body: some View {
        LiquidGlassCard(cornerRadius: 30, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("GATEWAY FOUNDATIONS", systemImage: "point.3.connected.trianglepath.dotted")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ZenWavePalette.electricPurple)
                        Text("Your practice constellation")
                            .font(.title3.weight(.semibold))
                        Text("Seven return points. Progress stays when life gets busy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(gamificationManager.gatewayFoundationCompletedCount)/\(steps.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                }

                ProgressView(value: gamificationManager.gatewayFoundationProgress, total: 1)
                    .tint(ZenWavePalette.electricPurple)

                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        constellationNode(step, index: index)
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: 2, height: 18)
                                .padding(.leading, index.isMultiple(of: 2) ? 28 : 72)
                        }
                    }
                }

                Button(action: onOpenConstellation) {
                    Label(
                        isPremiumUnlocked ? "Enter Constellation" : "View Constellation",
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ZenWavePalette.electricPurple)
            }
        }
    }

    private func constellationNode(_ step: PracticeJourneyStep, index: Int) -> some View {
        let isComplete = gamificationManager.state.completedJourneyStepIDs.contains(step.id)
        let isNext = gamificationManager.nextGatewayFoundationStep?.id == step.id
        let offset: CGFloat = index.isMultiple(of: 2) ? 0 : 44

        return Button {
            if isNext {
                onSelectNext()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isComplete ? ZenWavePalette.electricPurple.opacity(0.32) : Color.white.opacity(isNext ? 0.18 : 0.08))
                    Circle()
                        .strokeBorder(isComplete || isNext ? ZenWavePalette.electricPurple : Color.white.opacity(0.20), lineWidth: isNext ? 2 : 1)
                    Image(systemName: isComplete ? "checkmark" : step.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isComplete || isNext ? .white : .white.opacity(0.45))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Day \(index + 1) · \(step.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(isComplete || isNext ? 1 : 0.58))
                    Text(isComplete ? "Node revealed" : isNext ? step.subtitle : "Complete the previous node first")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if isNext {
                    Image(systemName: isPremiumUnlocked ? "play.fill" : "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ZenWavePalette.electricPurple)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isNext ? ZenWavePalette.electricPurple.opacity(0.12) : Color.clear))
        }
        .buttonStyle(.plain)
        .disabled(!isNext)
        .padding(.leading, offset)
    }
}

struct GatewayConstellationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var gamificationManager: GamificationManager
    let isPremiumUnlocked: Bool
    let onStartNext: () -> Void

    private var steps: [PracticeJourneyStep] {
        gamificationManager.gatewayFoundationSteps
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Image("GatewayConstellation")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.58)

            LinearGradient(
                colors: [Color.black.opacity(0.74), Color.clear, Color.black.opacity(0.86)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                let canvasSize = min(geometry.size.width - 18, geometry.size.height - 270)

                VStack(spacing: 12) {
                    header
                        .padding(.horizontal, 24)

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            .frame(width: canvasSize * 0.92, height: canvasSize * 0.92)

                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 8]))
                            .foregroundStyle(ZenWavePalette.electricPurple.opacity(0.26))
                            .frame(width: canvasSize * 0.72, height: canvasSize * 0.72)

                        constellationLines(size: canvasSize)

                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            constellationNode(step, index: index, canvasSize: canvasSize)
                        }
                    }
                    .frame(width: canvasSize, height: canvasSize)

                    footer
                        .padding(.horizontal, 24)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .padding(.top, 10)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .simultaneousGesture(edgeDismissGesture)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 86, height: 44)
                    .background(Capsule().fill(Color.black.opacity(0.42)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.22)))
            }
            .foregroundStyle(.white)
            .accessibilityHint("Returns to the previous screen")

            VStack(spacing: 5) {
                Text("GATEWAY FOUNDATIONS")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.cyan)
                Text("Your Constellation")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("\(gamificationManager.gatewayFoundationCompletedCount) of \(steps.count) stars awakened")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ZenWavePalette.electricPurple)
            }
            .frame(maxWidth: .infinity)

            Color.clear
                .frame(width: 86, height: 44)
                .accessibilityHidden(true)
        }
    }

    private var edgeDismissGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                let horizontalTravel = value.translation.width
                let verticalTravel = abs(value.translation.height)
                guard value.startLocation.x <= 30,
                      horizontalTravel >= 80,
                      horizontalTravel > verticalTravel else { return }
                dismiss()
            }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let next = gamificationManager.nextGatewayFoundationStep {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT")
                        .font(.caption2.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.cyan)
                    Text(next.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(next.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Button {
                    guard isPremiumUnlocked else { return }
                    dismiss()
                    DispatchQueue.main.async {
                        onStartNext()
                    }
                } label: {
                    Label(
                        isPremiumUnlocked ? "Continue Journey" : "Unlock Gateway Foundations",
                        systemImage: isPremiumUnlocked ? "play.fill" : "lock.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.48, green: 0.17, blue: 0.75))
            } else {
                Label("Constellation complete", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private func constellationLines(size: CGFloat) -> some View {
        let positions = steps.indices.map { nodePoint(for: $0, size: size) }
        ZStack {
            Path { path in
                guard let first = positions.first else { return }
                path.move(to: first)
                for point in positions.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 7]))

            if gamificationManager.gatewayFoundationCompletedCount > 1 {
                Path { path in
                    let completedPositions = positions.prefix(gamificationManager.gatewayFoundationCompletedCount)
                    guard let first = completedPositions.first else { return }
                    path.move(to: first)
                    for point in completedPositions.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    LinearGradient(colors: [.cyan, ZenWavePalette.electricPurple], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .shadow(color: .cyan.opacity(0.65), radius: 8)
            }
        }
    }

    private func constellationNode(_ step: PracticeJourneyStep, index: Int, canvasSize: CGFloat) -> some View {
        let isComplete = gamificationManager.state.completedJourneyStepIDs.contains(step.id)
        let isNext = gamificationManager.nextGatewayFoundationStep?.id == step.id
        let point = nodePoint(for: index, size: canvasSize)
        let nodeColor: Color = isComplete ? .cyan : isNext ? ZenWavePalette.electricPurple : .white

        return Button {
            guard isNext, isPremiumUnlocked else { return }
            dismiss()
            DispatchQueue.main.async {
                onStartNext()
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isNext && !reduceMotion {
                        Circle()
                            .fill(nodeColor.opacity(0.23))
                            .frame(width: 66, height: 66)
                    }
                    Circle()
                        .fill(Color.black.opacity(0.62))
                        .frame(width: 42, height: 42)
                        .overlay(Circle().strokeBorder(nodeColor.opacity(isComplete || isNext ? 0.95 : 0.30), lineWidth: isNext ? 2 : 1))
                    Image(systemName: isComplete ? "checkmark" : isNext ? "sparkle" : "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isComplete || isNext ? nodeColor : .white.opacity(0.42))
                }

                Text("\(index + 1). \(step.title)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(isComplete || isNext ? 0.95 : 0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(width: 110)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isNext || !isPremiumUnlocked)
        .position(x: point.x, y: point.y)
    }

    private func nodePoint(for index: Int, size: CGFloat) -> CGPoint {
        let points: [(CGFloat, CGFloat)] = [
            (0.28, 0.52), (0.50, 0.52), (0.72, 0.52),
            (0.72, 0.25), (0.28, 0.25), (0.72, 0.75), (0.50, 0.88)
        ]
        let point = points[min(index, points.count - 1)]
        return CGPoint(x: size * point.0, y: size * point.1)
    }
}

struct AstralBadgeGrid: View {
    @ObservedObject var gamificationManager: GamificationManager
    let isPremiumUnlocked: Bool

    private var badges: [PracticeBadge] {
        Array((gamificationManager.earnedBadges + gamificationManager.lockedBadges).prefix(6))
    }

    var body: some View {
        LiquidGlassCard(cornerRadius: 30, showParticles: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Practice Badges")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(badges) { badge in
                        badgeCell(badge)
                    }
                }
            }
        }
    }

    private func badgeCell(_ badge: PracticeBadge) -> some View {
        let unlocked = gamificationManager.state.earnedBadgeIDs.contains(badge.id)
        let gated = badge.isPremium && !isPremiumUnlocked

        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: gated ? "lock.fill" : badge.systemImage)
                .font(.title3)
                .foregroundStyle(unlocked ? ZenWavePalette.electricPurple : .white.opacity(0.48))

            Text(badge.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(unlocked ? badge.subtitle : badge.requirement)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(unlocked ? ZenWavePalette.electricPurple.opacity(0.18) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(unlocked ? ZenWavePalette.electricPurple.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct AstralRankPathView: View {
    @ObservedObject var gamificationManager: GamificationManager
    let isPremiumUnlocked: Bool
    let onSelectLockedNode: (AstralRank) -> Void

    var body: some View {
        LiquidGlassCard(cornerRadius: 30, showParticles: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Skill Path")
                    .font(.headline)

                VStack(spacing: 10) {
                    ForEach(GamificationManager.ranks) { rank in
                        rankRow(rank)
                    }
                }
            }
        }
    }

    private func rankRow(_ rank: AstralRank) -> some View {
        let unlocked = gamificationManager.isRankUnlocked(rank)
        let isPremiumNode = rank.id != "seeker" && rank.id != "resonant-breather"
        let gated = isPremiumNode && !isPremiumUnlocked

        return Button {
            guard !unlocked else { return }
            onSelectLockedNode(rank)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: unlocked ? "checkmark.seal.fill" : gated ? "lock.fill" : "circle")
                    .foregroundStyle(unlocked ? ZenWavePalette.electricPurple : .white.opacity(0.54))
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text(rank.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(unlocked ? rank.subtitle : rank.requirement)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if !unlocked {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.40))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(unlocked ? ZenWavePalette.electricPurple.opacity(0.16) : Color.white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
        .disabled(unlocked)
    }
}
