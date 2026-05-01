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
    /// Tracks what caused the paywall to open — read by ContentView.onAppear.
    private(set) var currentTrigger: PaywallTrigger = .serverReject

    /// Last-known backend premium state. Mirrored from AuthManager so this
    /// singleton can answer "is the user premium?" without taking an
    /// AuthManager dependency. Updated whenever auth.user changes.
    var backendIsPremium = false

    private var pendingAction: (() -> Void)?

    private init() {}

    /// True when the user is premium by EITHER source — RevenueCat (paid via
    /// App Store) or backend (admin-granted, or paid but RevenueCat hasn't
    /// caught up yet). Either signal is sufficient to skip the paywall.
    var hasPremium: Bool {
        StoreKitManager.shared.isPurchased || backendIsPremium
    }

    /// Gate an action behind premium. Runs immediately if already premium,
    /// otherwise opens the paywall and re-runs on successful purchase.
    func gate(_ action: @escaping () -> Void,
              trigger: PaywallTrigger = .serverReject) {
        if hasPremium {
            action()
            return
        }
        pendingAction = action
        currentTrigger = trigger
        isPresenting = true
    }

    /// Force-present the paywall without a pending action.
    func presentForServerReject(trigger: PaywallTrigger = .serverReject) {
        pendingAction = nil
        currentTrigger = trigger
        isPresenting = true
    }

    /// Called from the paywall sheet's onDismiss hook. If the user purchased
    /// while the sheet was open, replay the action that triggered the gate.
    func handleDismiss() {
        let action = pendingAction
        pendingAction = nil
        if hasPremium, let a = action {
            // Slight delay so the sheet is fully gone before UI changes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { a() }
        }
    }

    /// Used by the post-purchase success screen when the desired destination is
    /// the home screen instead of replaying the premium action that opened it.
    func cancelPendingAction() {
        pendingAction = nil
    }
}
