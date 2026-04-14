import StoreKit
import SwiftUI

@Observable
class StoreKitManager {
    static let shared = StoreKitManager()

    // Product ID — must match exactly what you create in App Store Connect
    static let premiumProductID = "com.surprisecard.premium.lifetime"

    private(set) var product: Product?
    private(set) var isPurchased = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var transactionListener: Task<Void, Error>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await updatePurchasedStatus() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [StoreKitManager.premiumProductID])
            await MainActor.run { product = products.first }
        } catch {
            await MainActor.run { errorMessage = "Could not load products." }
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product else {
            errorMessage = "Product not available."
            return
        }
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { @MainActor in isLoading = false } }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedStatus()
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                await MainActor.run { errorMessage = "Purchase is pending approval." }
            @unknown default:
                break
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { @MainActor in isLoading = false } }

        do {
            try await AppStore.sync()
            await updatePurchasedStatus()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Check Current Entitlements

    func updatePurchasedStatus() async {
        var purchased = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == StoreKitManager.premiumProductID,
               transaction.revocationDate == nil {
                purchased = true
            }
        }
        await MainActor.run { isPurchased = purchased }
    }

    // MARK: - Listen for Transactions (handles renewals, refunds, etc.)

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedStatus()
                    await transaction.finish()
                } catch {
                    // Transaction failed verification
                }
            }
        }
    }

    // MARK: - Verification Helper

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
