import RevenueCat
import SwiftUI

@Observable
class StoreKitManager {
    static let shared = StoreKitManager()

    // RevenueCat entitlement identifier
    static let entitlementID = "Surprisewidget Unlimited"

    private(set) var isPurchased = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // The lifetime package fetched from RevenueCat offerings
    private(set) var lifetimePackage: Package?

    // Formatted price string e.g. "$5.99"
    var priceString: String {
        lifetimePackage?.storeProduct.localizedPriceString ?? "$5.99"
    }

    private init() {
        Task {
            await fetchOfferings()
            await updatePurchasedStatus()
        }
    }

    // MARK: - Fetch Offerings

    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            // Look for a package with packageType .lifetime in current offering
            if let current = offerings.current {
                let pkg = current.availablePackages.first {
                    $0.packageType == .lifetime
                }
                await MainActor.run { lifetimePackage = pkg }
            }
        } catch {
            await MainActor.run { errorMessage = "Could not load products." }
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let pkg = lifetimePackage else {
            await MainActor.run { errorMessage = "Product not available. Try again." }
            return
        }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            let active = result.customerInfo.entitlements[StoreKitManager.entitlementID]?.isActive == true
            await MainActor.run {
                isPurchased = active
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let info = try await Purchases.shared.restorePurchases()
            let active = info.entitlements[StoreKitManager.entitlementID]?.isActive == true
            await MainActor.run {
                isPurchased = active
                isLoading = false
                if !active { errorMessage = "No previous purchase found." }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Clear Error

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Check Entitlement

    func updatePurchasedStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            let active = info.entitlements[StoreKitManager.entitlementID]?.isActive == true
            await MainActor.run { isPurchased = active }
        } catch {
            // Fail silently — user stays on free tier
        }
    }
}
