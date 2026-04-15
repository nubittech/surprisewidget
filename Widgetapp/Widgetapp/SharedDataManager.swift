import Foundation
import WidgetKit

// Lightweight friend info stored in App Group for widget access
struct WidgetFriend: Codable {
    let pairId: String
    let partnerName: String
    let partnerNickname: String?
}

class SharedDataManager {
    static let shared = SharedDataManager()
    static let appGroupId = "group.com.nubittech.surprisewidget"
    static let friendsKey = "friends_list"
    static let cardKeyPrefix = "card_"  // card_<pairId>

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedDataManager.appGroupId)
    }

    private init() {}

    // MARK: - Friends List

    func saveFriends(_ friends: [Friend]) {
        let widgets = friends.map { f in
            WidgetFriend(
                pairId: f.pair_id,
                partnerName: f.partner_name,
                partnerNickname: f.partner_nickname
            )
        }
        if let data = try? JSONEncoder().encode(widgets) {
            defaults?.set(data, forKey: SharedDataManager.friendsKey)
        }
        // Purge any cached cards for pair_ids that no longer belong to the
        // user (e.g. after an unpair). Otherwise the widget's `.failed`
        // fallback path could still render a ghost card from a dead pair.
        purgeOrphanCards(keepingPairIds: Set(friends.map { $0.pair_id }))
    }

    /// Removes `card_<pairId>` keys whose pairId isn't in the current friends set.
    private func purgeOrphanCards(keepingPairIds: Set<String>) {
        guard let defaults = defaults else { return }
        for key in defaults.dictionaryRepresentation().keys {
            guard key.hasPrefix(SharedDataManager.cardKeyPrefix) else { continue }
            let pairId = String(key.dropFirst(SharedDataManager.cardKeyPrefix.count))
            if !keepingPairIds.contains(pairId) {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// Explicitly removes the cached card for a specific pair. Call this
    /// immediately after a successful unpair so the widget reflects the
    /// removal before the next backend round-trip.
    func clearCard(forPairId pairId: String) {
        defaults?.removeObject(forKey: SharedDataManager.cardKeyPrefix + pairId)
    }

    func getFriends() -> [WidgetFriend] {
        guard let data = defaults?.data(forKey: SharedDataManager.friendsKey),
              let friends = try? JSONDecoder().decode([WidgetFriend].self, from: data)
        else { return [] }
        return friends
    }

    // MARK: - Per-Friend Card Data

    func saveCard(_ card: Card, forPairId pairId: String) {
        let cardDict: [String: Any] = [
            "background": card.background,
            "sender_name": card.sender_name ?? "",
            "elements": card.elements.map { el -> [String: Any] in
                var dict: [String: Any] = [
                    "id": el.id, "type": el.type, "content": el.content,
                    "x": el.x, "y": el.y
                ]
                if let fs = el.fontSize { dict["fontSize"] = fs }
                if let c = el.color { dict["color"] = c }
                if let s = el.size { dict["size"] = s }
                if let r = el.rotation { dict["rotation"] = r }
                return dict
            }
        ]
        let key = SharedDataManager.cardKeyPrefix + pairId
        if let data = try? JSONSerialization.data(withJSONObject: cardDict) {
            defaults?.set(data, forKey: key)
        }
    }

    func getCard(forPairId pairId: String) -> [String: Any]? {
        let key = SharedDataManager.cardKeyPrefix + pairId
        guard let data = defaults?.data(forKey: key),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return dict
    }

    // MARK: - Reload Widget

    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Background Fetch (called from push handler)

    /// Fetches the latest card for a pair from the backend and caches it in
    /// the App Group so the widget can display it immediately when its
    /// timeline is reloaded.
    func fetchAndCacheCard(forPairId pairId: String) async {
        guard let defaults = defaults,
              let token = defaults.string(forKey: "auth_token"),
              let base = defaults.string(forKey: "api_base_url"),
              let url = URL(string: "\(base)/cards/latest?pair_id=\(pairId)")
        else { return }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cardDict = obj["card"] as? [String: Any]
            else { return }

            // Save directly to App Group as dict (same format widget expects)
            if let cardData = try? JSONSerialization.data(withJSONObject: cardDict) {
                defaults.set(cardData, forKey: SharedDataManager.cardKeyPrefix + pairId)
            }
        } catch {
            print("[Push] fetchAndCacheCard failed: \(error)")
        }
    }
}
