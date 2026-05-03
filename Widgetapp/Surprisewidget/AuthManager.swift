import SwiftUI
import AuthenticationServices
import WidgetKit

@Observable
class AuthManager {
    var user: User? {
        didSet { mirrorPremiumToPaywall() }
    }
    var isLoading = true

    var isAuthenticated: Bool { user != nil }

    /// Keep PaywallPresenter's `backendIsPremium` in sync with the latest
    /// user payload so the gate can short-circuit even before RevenueCat
    /// has loaded. Hop to MainActor since PaywallPresenter is @MainActor.
    private func mirrorPremiumToPaywall() {
        let isPremium = user?.isPremium == true
        Task { @MainActor in
            PaywallPresenter.shared.backendIsPremium = isPremium
        }
    }

    /// Token for the userPremiumDidUpdate notification observer so we can
    /// remove it on deinit without leaking.
    @ObservationIgnored private var premiumObserver: NSObjectProtocol?

    init() {
        // Listen for entitlement-sync results from StoreKitManager and update
        // our in-memory user. This lets the UI reflect a successful purchase
        // (or admin-granted premium) without a separate /auth/me round-trip.
        premiumObserver = NotificationCenter.default.addObserver(
            forName: .userPremiumDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let updated = note.object as? User else { return }
            // Mirror onto MainActor — @Observable mutations should happen there.
            Task { @MainActor in
                self?.user = updated
            }
        }
    }

    deinit {
        if let obs = premiumObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func initialize() async {
        guard APIService.shared.token != nil else {
            isLoading = false
            return
        }
        do {
            user = try await APIService.shared.get("/auth/me")
            if let u = user { Analytics.identify(user: u) }
            // We already had a session — make sure the APNs token on record
            // at the backend is current (device-token rotation, new install
            // restoring a previous login, etc).
            PushNotificationManager.shared.registerPendingTokenIfNeeded()
        } catch {
            APIService.shared.token = nil
            user = nil
        }
        isLoading = false
    }

    func login(email: String, password: String) async throws {
        struct Body: Encodable { let email: String; let password: String }
        let resp: TokenResponse = try await APIService.shared.post(
            "/auth/login", body: Body(email: email, password: password))
        APIService.shared.token = resp.access_token
        user = resp.user
        Analytics.identify(user: resp.user)
        Analytics.login(method: "email")
        PushNotificationManager.shared.registerPendingTokenIfNeeded()
        // Use updatePurchasedStatus so RevenueCat loads CustomerInfo BEFORE
        // sync runs — otherwise the sync is a no-op and a real paying user
        // wouldn't get their backend entitlement reconciled until next launch.
        Task { await StoreKitManager.shared.updatePurchasedStatus() }
    }

    func register(email: String, password: String, name: String) async throws {
        struct Body: Encodable { let email: String; let password: String; let name: String }
        let resp: TokenResponse = try await APIService.shared.post(
            "/auth/register", body: Body(email: email, password: password, name: name))
        APIService.shared.token = resp.access_token
        user = resp.user
        Analytics.identify(user: resp.user)
        Analytics.signUp(method: "email")
        PushNotificationManager.shared.registerPendingTokenIfNeeded()
        // Use updatePurchasedStatus so RevenueCat loads CustomerInfo BEFORE
        // sync runs — otherwise the sync is a no-op and a real paying user
        // wouldn't get their backend entitlement reconciled until next launch.
        Task { await StoreKitManager.shared.updatePurchasedStatus() }
    }

    func refreshUser() async {
        guard APIService.shared.token != nil else { return }
        if let updated: User = try? await APIService.shared.get("/auth/me") {
            user = updated
        }
    }

    func loginWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            throw APIError.serverError("Could not retrieve Apple credentials")
        }

        var fullName: String? = nil
        if let fn = credential.fullName {
            let parts = [fn.givenName, fn.familyName].compactMap { $0 }
            if !parts.isEmpty { fullName = parts.joined(separator: " ") }
        }

        struct Body: Encodable {
            let identity_token: String
            let full_name: String?
            let email: String?
        }
        let resp: TokenResponse = try await APIService.shared.post(
            "/auth/apple",
            body: Body(
                identity_token: identityToken,
                full_name: fullName,
                email: credential.email
            )
        )
        APIService.shared.token = resp.access_token
        user = resp.user
        Analytics.identify(user: resp.user)
        Analytics.login(method: "apple")
        PushNotificationManager.shared.registerPendingTokenIfNeeded()
        // Use updatePurchasedStatus so RevenueCat loads CustomerInfo BEFORE
        // sync runs — otherwise the sync is a no-op and a real paying user
        // wouldn't get their backend entitlement reconciled until next launch.
        Task { await StoreKitManager.shared.updatePurchasedStatus() }
    }

    func logout() {
        // Tell the backend to drop this device's push registration BEFORE we
        // clear the auth token — otherwise pushes for the now-logged-out
        // account would keep landing on the device after the next user signs
        // in, refreshing their widget with the previous account's data.
        if let token = UserDefaults.standard.string(forKey: "pending_device_token"),
           APIService.shared.token != nil {
            Task {
                struct Body: Encodable { let device_token: String }
                struct EmptyResponse: Decodable {}
                _ = try? await APIService.shared.post("/devices/unregister",
                                                     body: Body(device_token: token)) as EmptyResponse
            }
        }

        APIService.shared.token = nil
        user = nil
        // Wipe widget-visible state for this account: cached friend list and
        // every per-pair card. Without this, the next account that signs in
        // on the same device sees the previous user's cards on the widget
        // until the next backend round-trip lands.
        WidgetUserScopeReset.clearAll()
        Analytics.reset()
    }
}

/// Helper that wipes everything the widget extension reads from the App Group.
/// Used on logout so account A's data never bleeds into account B on the same
/// device. We can't reach into UserDefaults directly without exposing the
/// App Group suite name in two places, so this wraps it.
@MainActor
enum WidgetUserScopeReset {
    static func clearAll() {
        let appGroupId = "group.com.nubittech.surprisewidget"
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        // Cards: every key beginning with "card_<pairId>" or "music_playing_".
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("card_") || key.hasPrefix("music_playing_") {
                defaults.removeObject(forKey: key)
            }
        }
        // Friends list shown to the widget configuration sheet.
        defaults.removeObject(forKey: "friends_list")
        // Force the widget to re-render the (now-empty) state immediately.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
