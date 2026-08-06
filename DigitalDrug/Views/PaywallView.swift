//
//  PaywallView.swift
//  DigitalDrug
//

import StoreKit
import SwiftUI

struct PaywallFeature: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String

    static let premiumRituals = PaywallFeature(
        title: "Unlock Premium Rituals",
        subtitle: "Chakras, Gateway-inspired sessions, Quantum Code rituals, guided voice, challenges, and journaling are included with ZenWave Premium."
    )
}

struct PaywallView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let feature: PaywallFeature

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroCard
                        productCard
                        legacyCard
                        restoreCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle("ZenWave Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await storeManager.refresh()
            }
            .onChange(of: storeManager.isPremiumUnlocked) { _, isUnlocked in
                if isUnlocked {
                    dismiss()
                }
            }
        }
    }

    private var heroCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Premium", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ZenWavePalette.electricPurple)

                Text(feature.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(feature.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    premiumRow("Chakra tones and timed progression", icon: "circle.hexagongrid.fill")
                    premiumRow("Gateway-inspired guided rituals", icon: "sparkles")
                    premiumRow("Quantum Code ritual sessions", icon: "number")
                    premiumRow("Challenges, journal, and guided voice", icon: "book.closed.fill")
                }
                .padding(.top, 4)
            }
        }
    }

    private var productCard: some View {
        LiquidGlassCard(cornerRadius: 34, showParticles: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose Premium")
                    .font(.title3.weight(.semibold))

                if storeManager.products.isEmpty {
                    if storeManager.errorMessage == nil {
                        ProgressView("Loading premium options...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tint(ZenWavePalette.electricPurple)
                    } else {
                        Button {
                            Task { await storeManager.refresh() }
                        } label: {
                            Label("Try Loading Again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ZenWavePalette.electricPurple)
                    }
                } else {
                    if let monthly = storeManager.monthlyProduct {
                        purchaseButton(product: monthly, label: "Monthly", detail: "Flexible access")
                    }

                    if let annual = storeManager.annualProduct {
                        purchaseButton(product: annual, label: "Annual", detail: "Best value")
                    }
                }

                if let errorMessage = storeManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Subscriptions renew automatically until canceled in your App Store account settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Link("Privacy Policy", destination: URL(string: "https://www.hyperlabsai.com/privacypolicy")!)
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.cyan)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var legacyCard: some View {
        LiquidGlassCard(cornerRadius: 28, showParticles: false) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Already paid for ZenWave?", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("If you bought ZenWave before version 2.0, premium access is unlocked automatically from your App Store purchase history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var restoreCard: some View {
        LiquidGlassCard(cornerRadius: 28, showParticles: false) {
            VStack(spacing: 12) {
                Button {
                    Task {
                        await storeManager.restorePurchases()
                    }
                } label: {
                    Label(storeManager.isRestoring ? "Restoring..." : "Restore Purchases", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(storeManager.isRestoring || storeManager.isPurchasing)

                Text("Premium rituals are designed to support reflection, visualization, and repeatable sound practice. They are not medical advice or treatment.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func purchaseButton(product: Product, label: String, detail: String) -> some View {
        Button {
            Task {
                await storeManager.purchase(product)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.74))
                }

                Spacer()

                if storeManager.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(product.displayPrice)
                        .font(.headline.monospacedDigit())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ZenWavePalette.toolbarGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(storeManager.isPurchasing || storeManager.isRestoring)
    }

    private func premiumRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(ZenWavePalette.electricPurple)
                .frame(width: 22)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
    }
}
