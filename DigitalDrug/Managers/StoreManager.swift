//
//  StoreManager.swift
//  DigitalDrug
//

import Foundation
import StoreKit
import UIKit

@MainActor
final class StoreManager: ObservableObject {
    enum AccessLevel: Equatable {
        case loading
        case free
        case premium
        case legacyPremium
        
        var title: String {
            switch self {
            case .loading: return "Checking Access"
            case .free: return "Free"
            case .premium: return "Premium"
            case .legacyPremium: return "Legacy Premium"
            }
        }
        
        var subtitle: String {
            switch self {
            case .loading: return "Confirming your App Store access."
            case .free: return "Generator access is free. Premium rituals are locked."
            case .premium: return "All premium rituals and guided sessions are unlocked."
            case .legacyPremium: return "Unlocked because you purchased ZenWave before version 2.0."
            }
        }
    }
    
    static let monthlyProductID = "com.hyperlabsAI.DigitalDrug.premium.monthly"
    static let annualProductID = "com.hyperlabsAI.DigitalDrug.premium.annual"
    static let premiumProductIDs = [monthlyProductID, annualProductID]
    static let legacyCutoffVersion = "2.0"
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published private(set) var accessLevel: AccessLevel = .loading
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var errorMessage: String?
    
    private var transactionUpdatesTask: Task<Void, Never>?
    private var hasLoadedProducts = false
    
    var isPremiumUnlocked: Bool {
        accessLevel == .premium || accessLevel == .legacyPremium
    }
    
    var isLegacyPaidUser: Bool {
        accessLevel == .legacyPremium
    }
    
    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }
    
    var annualProduct: Product? {
        products.first { $0.id == Self.annualProductID }
    }
    
    init() {
        transactionUpdatesTask = observeTransactionUpdates()
        Task {
            await refresh()
        }
    }
    
    deinit {
        transactionUpdatesTask?.cancel()
    }
    
    func refresh() async {
        AppLog.info("StoreManager refresh requested")
        await loadProductsIfNeeded()
        await updateAccessLevel()
    }
    
    func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        AppLog.info("StoreManager purchase requested: \(product.id)")
        
        defer {
            isPurchasing = false
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                await updateAccessLevel()
                AppLog.info("StoreManager purchase succeeded: \(transaction.productID)")
            case .userCancelled:
                AppLog.info("StoreManager purchase cancelled: \(product.id)")
            case .pending:
                errorMessage = "Your purchase is pending approval."
                AppLog.info("StoreManager purchase pending: \(product.id)")
            @unknown default:
                errorMessage = "The purchase could not be completed."
                AppLog.error("StoreManager purchase returned an unknown result: \(product.id)")
            }
        } catch {
            errorMessage = error.localizedDescription
            AppLog.error("StoreManager purchase failed: \(product.id), error=\(error.localizedDescription)")
        }
    }
    
    func restorePurchases() async {
        isRestoring = true
        errorMessage = nil
        AppLog.info("StoreManager restore requested")
        
        defer {
            isRestoring = false
        }
        
        do {
            try await AppStore.sync()
            await updateAccessLevel()
        } catch {
            errorMessage = error.localizedDescription
            AppLog.error("StoreManager restore failed: \(error.localizedDescription)")
        }
    }
    
    func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }
    
    private func loadProductsIfNeeded() async {
        guard !hasLoadedProducts else { return }
        
        do {
            let loadedProducts = try await Product.products(for: Self.premiumProductIDs)
            products = loadedProducts.sorted { lhs, rhs in
                Self.premiumProductIDs.firstIndex(of: lhs.id) ?? 99 < Self.premiumProductIDs.firstIndex(of: rhs.id) ?? 99
            }
            hasLoadedProducts = true
            AppLog.info("StoreManager loaded products: \(products.map(\.id).joined(separator: ", "))")
        } catch {
            errorMessage = "Unable to load premium options. Please try again."
            AppLog.error("StoreManager failed to load products: \(error.localizedDescription)")
        }
    }
    
    private func updateAccessLevel() async {
        let legacyPaidUser = await checkLegacyPaidUser()
        var activeProductIDs = Set<String>()
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard Self.premiumProductIDs.contains(transaction.productID) else { continue }
                activeProductIDs.insert(transaction.productID)
            } catch {
                AppLog.error("StoreManager entitlement verification failed: \(error.localizedDescription)")
            }
        }
        
        purchasedProductIDs = activeProductIDs
        
        if legacyPaidUser {
            accessLevel = .legacyPremium
        } else if !activeProductIDs.isEmpty {
            accessLevel = .premium
        } else {
            accessLevel = .free
        }
        
        AppLog.info("StoreManager access updated: \(accessLevel.title), activeProducts=\(activeProductIDs.joined(separator: ", "))")
    }
    
    private func checkLegacyPaidUser() async -> Bool {
        do {
            let result = try await AppTransaction.shared
            let appTransaction = try checkVerified(result)
            let originalVersion = appTransaction.originalAppVersion
            let isLegacy = Self.isVersion(originalVersion, earlierThan: Self.legacyCutoffVersion)
            AppLog.info("StoreManager legacy check: originalVersion=\(originalVersion), cutoff=\(Self.legacyCutoffVersion), legacy=\(isLegacy)")
            return isLegacy
        } catch {
            AppLog.error("StoreManager legacy check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                do {
                    guard let self else { return }
                    let transaction = try await self.checkVerified(result)
                    await transaction.finish()
                    await self.updateAccessLevel()
                } catch {
                    await MainActor.run {
                        self?.errorMessage = "A purchase update could not be verified."
                    }
                    AppLog.error("StoreManager transaction update failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }
    
    private static func isVersion(_ version: String, earlierThan cutoff: String) -> Bool {
        let versionParts = version.split(separator: ".").map { Int($0) ?? 0 }
        let cutoffParts = cutoff.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(versionParts.count, cutoffParts.count)
        
        for index in 0..<count {
            let versionValue = index < versionParts.count ? versionParts[index] : 0
            let cutoffValue = index < cutoffParts.count ? cutoffParts[index] : 0
            
            if versionValue < cutoffValue { return true }
            if versionValue > cutoffValue { return false }
        }
        
        return false
    }
}
