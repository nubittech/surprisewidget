import SwiftUI

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
    }

    func register(email: String, password: String, name: String) async throws {
        struct Body: Encodable { let email: String; let password: String; let name: String }
        let resp: TokenResponse = try await APIService.shared.post(
            "/auth/register", body: Body(email: email, password: password, name: name))
        APIService.shared.token = resp.access_token
        user = resp.user
    }

    func refreshUser() async {
        guard APIService.shared.token != nil else { return }
        if let updated: User = try? await APIService.shared.get("/auth/me") {
            user = updated
        }
    }

    func logout() {
        APIService.shared.token = nil
        user = nil
    }
}
