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
    /// ISO-8601 expiration date from RevenueCat, or nil for lifetime / inactive.
    private(set) var expirationISO: String?
    private(set) var productIdentifier: String?
    /// Becomes true the first time we successfully read CustomerInfo from
    /// RevenueCat. Until then, `isPurchased` is just the optimistic default
    /// (false) and we MUST NOT push that to the backend — doing so would
    /// downgrade real paying users every time the app cold-starts before
    /// RevenueCat finishes its first network round-trip.
    private(set) var customerInfoLoaded = false

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
        Analytics.purchaseStarted()
        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            await applyCustomerInfo(result.customerInfo)
            await MainActor.run { isLoading = false }
            await syncEntitlementWithBackend()
            if isPurchased { Analytics.purchaseCompleted(productId: pkg.storeProduct.productIdentifier) }
        } catch {
            Analytics.purchaseFailed(reason: error.localizedDescription)
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        Analytics.restoreTapped()
        do {
            let info = try await Purchases.shared.restorePurchases()
            await applyCustomerInfo(info)
            let active = isPurchased
            Analytics.restoreCompleted(success: active)
            await MainActor.run {
                isLoading = false
                if !active { errorMessage = "No previous purchase found." }
            }
            await syncEntitlementWithBackend()
        } catch {
            Analytics.restoreCompleted(success: false)
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
            await applyCustomerInfo(info)
            // Best-effort backend mirror — no-op if unauthenticated.
            await syncEntitlementWithBackend()
        } catch {
            // Fail silently — user stays on free tier
        }
    }

    // MARK: - Backend Sync

    private func applyCustomerInfo(_ info: CustomerInfo) async {
        let ent = info.entitlements[StoreKitManager.entitlementID]
        let active = ent?.isActive == true
        let iso: String? = {
            guard let date = ent?.expirationDate else { return nil }
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fmt.string(from: date)
        }()
        let pid = ent?.productIdentifier
        await MainActor.run {
            isPurchased = active
            expirationISO = iso
            productIdentifier = pid
            customerInfoLoaded = true
        }
    }

    /// Mirror the current RevenueCat entitlement to the backend so server-side
    /// gates (pair limit, daily cap, content reject) know the user's tier.
    /// Safe to call without an auth token — the request will just fail silently.
    ///
    /// IMPORTANT: never call this with `is_active: false` for a user that
    /// previously purchased — the backend protects against accidental
    /// downgrades, but we shouldn't rely on that as our only safety net.
    /// We only sync when we know with confidence that RevenueCat has
    /// finished its initial customerInfo load.
    func syncEntitlementWithBackend() async {
        guard APIService.shared.token != nil else { return }
        // Don't push optimistic-default state. If we send `is_active: false`
        // before RevenueCat has loaded the customer's actual entitlements,
        // we risk downgrading a real lifetime customer. The backend now
        // rejects downgrades server-side, but we still avoid the noise here.
        guard customerInfoLoaded else { return }
        struct Body: Encodable {
            let is_active: Bool
            let expiration_date: String?
            let product_id: String?
        }
        let body = Body(
            is_active: isPurchased,
            expiration_date: expirationISO,
            product_id: productIdentifier
        )
        // Sync returns the refreshed user. Push it to AuthManager via a
        // notification so any view bound to `auth.user` sees the new
        // is_premium flag immediately — no separate /auth/me needed.
        if let updated: User = try? await APIService.shared.post(
            "/users/me/sync-entitlement",
            body: body
        ) {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .userPremiumDidUpdate,
                    object: updated
                )
            }
        }
    }
}

extension Notification.Name {
    /// Posted with a `User` payload after the backend confirms an entitlement
    /// sync. AuthManager listens and updates its in-memory user.
    static let userPremiumDidUpdate = Notification.Name("userPremiumDidUpdate")
}
