import Foundation
import UIKit
import UserNotifications
import WidgetKit

// MARK: - Push Notification Manager
//
// Handles:
// 1. Requesting notification permission
// 2. Registering device token with the backend
// 3. Receiving silent pushes → reloading widget timelines
//
// The backend sends a silent push (content-available: 1) whenever a new
// card is created for the user. iOS wakes the app in the background, we
// reload all widget timelines, and the widget's timeline provider fetches
// the latest card from the backend.

class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    var deviceToken: String?

    override private init() {
        super.init()
    }

    // MARK: - Request Permission & Register

    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error {
                print("[Push] Permission error: \(error)")
                return
            }
            print("[Push] Permission granted: \(granted)")
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Handle Token

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        print("[Push] Device token: \(token)")
        sendTokenToBackend(token)
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[Push] Registration failed: \(error.localizedDescription)")
    }

    // MARK: - Handle Incoming Push

    func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        completion: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("[Push] Received notification: \(userInfo)")

        // Check if this is a card notification
        let type = userInfo["type"] as? String
        if type == "new_card" {
            // Reload all widget timelines — the timeline provider will
            // fetch the latest card from the backend automatically.
            WidgetCenter.shared.reloadAllTimelines()
            print("[Push] Widget timelines reloaded")

            // Also try to pre-cache the card via the main app's SharedDataManager
            if let pairId = userInfo["pair_id"] as? String {
                Task {
                    await SharedDataManager.shared.fetchAndCacheCard(forPairId: pairId)
                    completion(.newData)
                }
                return
            }

            completion(.newData)
        } else {
            completion(.noData)
        }
    }

    // MARK: - Send Token to Backend

    private func sendTokenToBackend(_ token: String) {
        guard let authToken = APIService.shared.token else {
            print("[Push] No auth token, skipping device token registration")
            return
        }

        Task {
            do {
                struct TokenBody: Encodable {
                    let device_token: String
                    let platform: String
                }
                struct EmptyResponse: Decodable {}
                let _: EmptyResponse = try await APIService.shared.post(
                    "/devices/register",
                    body: TokenBody(device_token: token, platform: "ios")
                )
                print("[Push] Device token registered with backend")
            } catch {
                print("[Push] Failed to register token: \(error)")
            }
        }
    }
}
