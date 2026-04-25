import Foundation
import Mixpanel

/// Central analytics hub. Call `Analytics.track(...)` from anywhere.
/// User identity is set on login/register and cleared on logout.
enum Analytics {

    private static let token = "6ff0f375079986385add3d37a83ecd4a"

    static func initialize() {
        Mixpanel.initialize(token: token, serverURL: "https://api-eu.mixpanel.com")
        Mixpanel.mainInstance().loggingEnabled = false
    }

    // MARK: - Identity

    static func identify(user: User) {
        let mp = Mixpanel.mainInstance()
        mp.identify(distinctId: user.id)
        mp.people.set(properties: [
            "$name":       user.name,
            "$email":      user.email,
            "is_premium":  user.isPremium,
            "pair_count":  user.pair_ids?.count ?? 0,
        ])
    }

    static func reset() {
        Mixpanel.mainInstance().reset()
    }

    // MARK: - Auth

    static func signUp(method: String = "email") {
        track("sign_up", props: ["method": method])
    }

    static func login(method: String = "email") {
        track("login", props: ["method": method])
    }

    // MARK: - Card

    static func cardSendSuccess(backgroundType: String,
                                stickerCount: Int,
                                hasText: Bool,
                                hasTextBox: Bool) {
        track("card_send_success", props: [
            "background_type": backgroundType,   // "color" | "image"
            "sticker_count":   stickerCount,
            "has_text":        hasText,
            "has_text_box":    hasTextBox,
        ])
        // Increment lifetime send counter on the user profile
        Mixpanel.mainInstance().people.increment(property: "cards_sent", by: 1)
    }

    static func dailyLimitHit() {
        track("daily_limit_hit")
    }

    // MARK: - Paywall

    /// Call this every time the paywall sheet becomes visible.
    /// `trigger` describes what action caused it to appear.
    static func paywallShown(trigger: PaywallTrigger) {
        track("paywall_shown", props: ["trigger": trigger.rawValue])
    }

    static func paywallDismissed(converted: Bool) {
        track("paywall_dismissed", props: ["converted": converted])
    }

    // MARK: - Purchase

    static func purchaseStarted() {
        track("purchase_started")
    }

    static func purchaseCompleted(productId: String?) {
        track("purchase_completed", props: ["product_id": productId ?? "unknown"])
        Mixpanel.mainInstance().people.set(properties: ["is_premium": true])
        Mixpanel.mainInstance().people.set(properties: ["purchase_date": Date().ISO8601Format()])
    }

    static func purchaseFailed(reason: String) {
        track("purchase_failed", props: ["reason": reason])
    }

    static func restoreTapped() {
        track("restore_tapped")
    }

    static func restoreCompleted(success: Bool) {
        track("restore_completed", props: ["success": success])
        if success {
            Mixpanel.mainInstance().people.set(properties: ["is_premium": true])
        }
    }

    // MARK: - Friends

    static func friendAdded() {
        track("friend_added")
        Mixpanel.mainInstance().people.increment(property: "total_friends_added", by: 1)
    }

    static func friendRemoved() {
        track("friend_removed")
    }

    // MARK: - Content Discovery

    static func stickerCategoryViewed(name: String, isPremium: Bool) {
        track("sticker_category_viewed", props: [
            "category_name": name,
            "is_premium":    isPremium,
        ])
    }

    static func premiumBackgroundTapped() {
        track("premium_background_tapped")
    }

    // MARK: - Private

    private static func track(_ event: String,
                               props: [String: MixpanelType] = [:]) {
        Mixpanel.mainInstance().track(event: event,
                                      properties: props.isEmpty ? nil : props)
    }
}

// MARK: - PaywallTrigger

enum PaywallTrigger: String {
    case dailyLimit        = "daily_limit"
    case friendLimit       = "friend_limit"
    case premiumSticker    = "premium_sticker"
    case premiumBackground = "premium_background"
    case serverReject      = "server_reject"
}
