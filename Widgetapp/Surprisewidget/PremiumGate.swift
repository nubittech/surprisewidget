import SwiftUI

/// Single point of control for presenting the paywall.
///
/// Call `PaywallPresenter.shared.gate { ... }` from any UI handler that wants
/// to run a premium-only action. If the user already has premium, the action
/// runs immediately. Otherwise the paywall sheet is presented and — if the
/// user completes a purchase inside the sheet — the pending action is run
/// when the sheet dismisses.
///
/// For server-side rejections (HTTP 402) call `presentForServerReject()` —
/// APIService wires this automatically, so most call-sites do not need it.
@Observable
@MainActor
final class PaywallPresenter {
    static let shared = PaywallPresenter()

    /// Bound to the ContentView-level sheet.
    var isPresenting = false

    private var pendingAction: (() -> Void)?

    private init() {}

    /// Gate an action behind premium. Runs immediately if already premium,
    /// otherwise opens the paywall and re-runs on successful purchase.
    func gate(_ action: @escaping () -> Void) {
        if StoreKitManager.shared.isPurchased {
            action()
            return
        }
        pendingAction = action
        isPresenting = true
    }

    /// Force-present the paywall without a pending action. Used by APIService
    /// when the backend returns 402 Payment Required.
    func presentForServerReject() {
        pendingAction = nil
        isPresenting = true
    }

    /// Called from the paywall sheet's onDismiss hook. If the user purchased
    /// while the sheet was open, replay the action that triggered the gate.
    func handleDismiss() {
        let action = pendingAction
        pendingAction = nil
        if StoreKitManager.shared.isPurchased, let a = action {
            // Slight delay so the sheet is fully gone before UI changes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { a() }
        }
    }
}
