import SwiftUI
import AuthenticationServices

@Observable
class AuthManager {
    var user: User?
    var isLoading = true

    var isAuthenticated: Bool { user != nil }

    func initialize() async {
        guard APIService.shared.token != nil else {
            isLoading = false
            return
        }
        do {
            user = try await APIService.shared.get("/auth/me")
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
        PushNotificationManager.shared.registerPendingTokenIfNeeded()
        // Mirror any existing RevenueCat entitlement to the backend for this
        // session — keeps server-side premium gates in sync after a fresh
        // login on a device that already owns the lifetime unlock.
        Task { await StoreKitManager.shared.syncEntitlementWithBackend() }
    }

    func register(email: String, password: String, name: String) async throws {
        struct Body: Encodable { let email: String; let password: String; let name: String }
        let resp: TokenResponse = try await APIService.shared.post(
            "/auth/register", body: Body(email: email, password: password, name: name))
        APIService.shared.token = resp.access_token
        user = resp.user
        PushNotificationManager.shared.registerPendingTokenIfNeeded()
        // Mirror any existing RevenueCat entitlement to the backend for this
        // session — keeps server-side premium gates in sync after a fresh
        // login on a device that already owns the lifetime unlock.
        Task { await StoreKitManager.shared.syncEntitlementWithBackend() }
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
        PushNotificationManager.shared.registerPendingTokenIfNeeded()
        // Mirror any existing RevenueCat entitlement to the backend for this
        // session — keeps server-side premium gates in sync after a fresh
        // login on a device that already owns the lifetime unlock.
        Task { await StoreKitManager.shared.syncEntitlementWithBackend() }
    }

    func logout() {
        APIService.shared.token = nil
        user = nil
    }
}
