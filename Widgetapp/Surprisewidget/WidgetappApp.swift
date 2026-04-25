import SwiftUI
import UIKit
import RevenueCat

// Forces black status bar icons (time, battery, signal) across the whole app.
class FixedDarkStatusBarViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
}

// MARK: - AppDelegate for Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Mixpanel — initialize before anything else
        Analytics.initialize()
        // RevenueCat — configure before anything else
        Purchases.configure(withAPIKey: "appl_BnHqhjCFmbhIeRQYcxBJiAgCumx")
        Purchases.logLevel = .debug

        // If notification permission was previously granted, re-register on
        // every launch. iOS issues `didRegisterForRemoteNotifications` with
        // the current APNs token, which we then ship to the backend so silent
        // pushes (→ widget refresh) keep working after reinstall / token
        // rotation / first login. If the user hasn't granted yet, this is a
        // no-op and won't trigger any prompt.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }

    // Handle background/silent push notifications
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        PushNotificationManager.shared.didReceiveRemoteNotification(
            userInfo: userInfo,
            completion: completionHandler
        )
    }
}

@main
struct WidgetappApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var auth = AuthManager()
    // StoreKit singleton — initialised once, shared via environment
    private let store = StoreKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                // The UI is designed against a fixed light palette (cream
                // backgrounds, dark purple text). Honoring the system dark
                // appearance inverts any element that falls back to Apple's
                // default styling (alerts, sheets, default Text colors),
                // which breaks contrast and hides copy entirely. Lock the
                // whole app to light mode.
                .preferredColorScheme(.light)
        }
    }
}
