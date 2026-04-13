import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case serverError(String)
    case unauthorized           // token expired → force logout
    case invalidCredentials     // wrong email/password → show on login
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "Geçersiz URL"
        case .serverError(let m):       return m
        case .unauthorized:             return "Oturum süresi doldu, lütfen tekrar giriş yapın"
        case .invalidCredentials:       return "E-posta veya şifre hatalı"
        case .unknown(let code):        return "Beklenmeyen hata (\(code))"
        }
    }
}

class APIService {
    static let shared = APIService()
    // Production backend on Railway
    static let baseURL = "https://surprisewidget-production.up.railway.app/api"

    private init() {
        // Always keep the widget's copy of the base URL up-to-date and
        // migrate any legacy token stored only in standard UserDefaults.
        sharedDefaults?.set(APIService.baseURL, forKey: "api_base_url")
        if sharedDefaults?.string(forKey: "auth_token") == nil,
           let legacy = UserDefaults.standard.string(forKey: "auth_token") {
            sharedDefaults?.set(legacy, forKey: "auth_token")
        }
    }

    // App Group suite shared with widget extension so the widget can
    // authenticate against the backend and fetch the latest cards even
    // when the main app isn't running.
    private static let appGroupId = "group.com.surprisecard.shared"
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: APIService.appGroupId)
    }

    var token: String? {
        get { sharedDefaults?.string(forKey: "auth_token") ?? UserDefaults.standard.string(forKey: "auth_token") }
        set {
            if let v = newValue {
                sharedDefaults?.set(v, forKey: "auth_token")
                UserDefaults.standard.set(v, forKey: "auth_token")
                // Keep the base URL in sync so the widget knows where to call.
                sharedDefaults?.set(APIService.baseURL, forKey: "api_base_url")
            } else {
                sharedDefaults?.removeObject(forKey: "auth_token")
                UserDefaults.standard.removeObject(forKey: "auth_token")
            }
        }
    }

    // MARK: - Helpers

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await request(path, method: "GET", body: nil)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(path, method: "POST", body: data)
    }

    func postEmpty<T: Decodable>(_ path: String) async throws -> T {
        try await request(path, method: "POST", body: nil)
    }

    // MARK: - Core

    private func request<T: Decodable>(_ path: String, method: String, body: Data?) async throws -> T {
        guard let url = URL(string: "\(APIService.baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown(0) }

        if http.statusCode == 401 {
            // Check if it's a credential error (login/register) or expired token
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String,
               detail.contains("Geçersiz e-posta") || detail.contains("şifre") {
                throw APIError.invalidCredentials
            }
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let d = json["detail"] as? String { throw APIError.serverError(d) }
                if let arr = json["detail"] as? [[String: Any]] {
                    let msg = arr.compactMap { $0["msg"] as? String }.joined(separator: " ")
                    throw APIError.serverError(msg.isEmpty ? "Hata oluştu" : msg)
                }
            }
            throw APIError.unknown(http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
