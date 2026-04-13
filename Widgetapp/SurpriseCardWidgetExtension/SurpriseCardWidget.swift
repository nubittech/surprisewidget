// SurpriseCardWidget.swift
// Widget Extension — AppIntentConfiguration with friend picker

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared Data Models (Widget side)
struct WidgetFriend: Codable {
    let pairId: String
    let partnerName: String
    let partnerNickname: String?
    var displayName: String { partnerNickname ?? partnerName }
}

struct CardData: Codable {
    let background: String
    let senderName: String?
    let elements: [CardElement]
    enum CodingKeys: String, CodingKey {
        case background
        case senderName = "sender_name"
        case elements
    }
}

struct CardElement: Codable, Identifiable {
    let id: String
    let type: String
    let content: String
    let x: Double
    let y: Double
    let fontSize: Double?
    let color: String?
    let size: Double?
    let rotation: Double?

    enum CodingKeys: String, CodingKey {
        case id, type, content, x, y, fontSize, color, size, rotation
    }
}

// MARK: - App Group Access
struct WidgetSharedData {
    static let appGroupId = "group.com.surprisecard.shared"
    static let friendsKey = "friends_list"
    static let cardKeyPrefix = "card_"
    static let tokenKey = "auth_token"
    static let baseURLKey = "api_base_url"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func getFriends() -> [WidgetFriend] {
        guard let defaults,
              let data = defaults.data(forKey: friendsKey),
              let friends = try? JSONDecoder().decode([WidgetFriend].self, from: data)
        else { return [] }
        return friends
    }

    static func getCard(forPairId pairId: String) -> CardData? {
        guard let defaults,
              let data = defaults.data(forKey: cardKeyPrefix + pairId)
        else { return nil }

        // Try direct Codable decode
        if let card = try? JSONDecoder().decode(CardData.self, from: data) { return card }

        // Fallback: JSONSerialization (dict format from main app)
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let bg = dict["background"] as? String ?? "#F3E8FF"
        let sender = dict["sender_name"] as? String
        var elements: [CardElement] = []
        if let elArray = dict["elements"] as? [[String: Any]] {
            for el in elArray {
                elements.append(CardElement(
                    id: el["id"] as? String ?? UUID().uuidString,
                    type: el["type"] as? String ?? "text",
                    content: el["content"] as? String ?? "",
                    x: el["x"] as? Double ?? 0,
                    y: el["y"] as? Double ?? 0,
                    fontSize: el["fontSize"] as? Double,
                    color: el["color"] as? String,
                    size: el["size"] as? Double,
                    rotation: el["rotation"] as? Double
                ))
            }
        }
        return CardData(background: bg, senderName: sender, elements: elements)
    }

    static func saveCard(_ card: CardData, forPairId pairId: String) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(card) {
            defaults.set(data, forKey: cardKeyPrefix + pairId)
        }
    }

    /// Removes any cached card for the given pair. Used when the backend
    /// explicitly reports "no card for this pair" so that a stale cached
    /// entry (e.g. one created before a delete) cannot resurface.
    static func clearCard(forPairId pairId: String) {
        defaults?.removeObject(forKey: cardKeyPrefix + pairId)
    }

    // MARK: Direct backend fetch (used by the widget timeline)

    /// Three-valued result so callers can distinguish "backend said there
    /// is no card" from "we couldn't reach the backend". The timeline
    /// provider must NOT fall back to the stale cache in the `.empty` case —
    /// that is exactly how deleted cards come back to life.
    enum CardFetch {
        case fresh(CardData)
        case empty
        case failed
    }

    /// Fetches the latest card for a pair from the backend using the token
    /// stored in the shared App Group.
    static func fetchLatestCard(forPairId pairId: String) async -> CardFetch {
        guard let defaults,
              let token = defaults.string(forKey: tokenKey),
              let base = defaults.string(forKey: baseURLKey),
              let url = URL(string: "\(base)/cards/latest?pair_id=\(pairId)")
        else { return .failed }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .failed
            }
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failed
            }
            // Explicit "no card" from backend: {"card": null} or missing key
            if !(obj["card"] is [String: Any]) {
                clearCard(forPairId: pairId)
                return .empty
            }
            guard let cardDict = obj["card"] as? [String: Any] else {
                return .failed
            }
            let bg = cardDict["background"] as? String ?? "#F3E8FF"
            let sender = cardDict["sender_name"] as? String
            var elements: [CardElement] = []
            if let elArray = cardDict["elements"] as? [[String: Any]] {
                for el in elArray {
                    elements.append(CardElement(
                        id: el["id"] as? String ?? UUID().uuidString,
                        type: el["type"] as? String ?? "text",
                        content: el["content"] as? String ?? "",
                        x: el["x"] as? Double ?? 0,
                        y: el["y"] as? Double ?? 0,
                        fontSize: el["fontSize"] as? Double,
                        color: el["color"] as? String,
                        size: el["size"] as? Double,
                        rotation: el["rotation"] as? Double
                    ))
                }
            }
            let card = CardData(background: bg, senderName: sender, elements: elements)
            saveCard(card, forPairId: pairId)
            return .fresh(card)
        } catch {
            return .failed
        }
    }
}

// MARK: - AppEntity: Friend
struct FriendEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Arkadaş"
    static var defaultQuery = FriendEntityQuery()

    var id: String          // pairId
    var name: String        // display name

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct FriendEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [FriendEntity] {
        WidgetSharedData.getFriends()
            .filter { identifiers.contains($0.pairId) }
            .map { FriendEntity(id: $0.pairId, name: $0.displayName) }
    }

    func suggestedEntities() async throws -> [FriendEntity] {
        WidgetSharedData.getFriends()
            .map { FriendEntity(id: $0.pairId, name: $0.displayName) }
    }
}

// MARK: - AppIntent: Select Friend
struct SelectFriendIntent: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Arkadaş Seç"
    static var description = IntentDescription("Hangi arkadaşının kartını görmek istiyorsun?")

    @Parameter(title: "Arkadaş")
    var friend: FriendEntity?

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Timeline Entry
struct CardEntry: TimelineEntry {
    let date: Date
    let card: CardData?
    let friendName: String?
    let pairId: String?
    var needsConfiguration: Bool = false
}

// MARK: - Timeline Provider
struct CardTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = SelectFriendIntent
    typealias Entry = CardEntry

    func placeholder(in context: Context) -> CardEntry {
        CardEntry(date: Date(), card: nil, friendName: "Arkadaş", pairId: nil, needsConfiguration: false)
    }

    func snapshot(for configuration: SelectFriendIntent, in context: Context) async -> CardEntry {
        // Snapshots in the widget gallery shouldn't hit the network.
        makeEntryFromCache(for: configuration)
    }

    func timeline(for configuration: SelectFriendIntent, in context: Context) async -> Timeline<CardEntry> {
        // Try to refresh from the backend first — this is how a received card
        // actually reaches the widget without the app being opened.
        let entry = await makeEntryWithRefresh(for: configuration)
        // Come back in ~5 minutes (iOS may coalesce this to its own budget).
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }

    /// Resolves which pairId this widget should show, given the user's configuration.
    private func resolvePairId(for config: SelectFriendIntent) -> (pairId: String, name: String)? {
        if let friend = config.friend {
            return (friend.id, friend.name)
        }
        let all = WidgetSharedData.getFriends()
        if all.count == 1, let only = all.first {
            return (only.pairId, only.displayName)
        }
        return nil
    }

    /// Builds an entry using only the App Group cache (no network).
    private func makeEntryFromCache(for config: SelectFriendIntent) -> CardEntry {
        if let (pairId, name) = resolvePairId(for: config) {
            let card = WidgetSharedData.getCard(forPairId: pairId)
            return CardEntry(date: Date(), card: card, friendName: name, pairId: pairId, needsConfiguration: false)
        }
        if WidgetSharedData.getFriends().count > 1 {
            return CardEntry(date: Date(), card: nil, friendName: nil, pairId: nil, needsConfiguration: true)
        }
        return CardEntry(date: Date(), card: nil, friendName: nil, pairId: nil, needsConfiguration: false)
    }

    /// Builds an entry, refreshing from the backend if we know which pair to ask for.
    /// - `.fresh` → use the new card (already cached by fetchLatestCard)
    /// - `.empty` → backend says no card exists; show empty state and let the
    ///              cleared cache stand so an old card can NEVER resurface
    /// - `.failed` → transient network/auth error; fall back to whatever is
    ///               in the cache so the widget isn't visibly broken offline
    private func makeEntryWithRefresh(for config: SelectFriendIntent) async -> CardEntry {
        guard let (pairId, name) = resolvePairId(for: config) else {
            return makeEntryFromCache(for: config)
        }
        switch await WidgetSharedData.fetchLatestCard(forPairId: pairId) {
        case .fresh(let card):
            return CardEntry(date: Date(), card: card, friendName: name, pairId: pairId, needsConfiguration: false)
        case .empty:
            return CardEntry(date: Date(), card: nil, friendName: name, pairId: pairId, needsConfiguration: false)
        case .failed:
            let cached = WidgetSharedData.getCard(forPairId: pairId)
            return CardEntry(date: Date(), card: cached, friendName: name, pairId: pairId, needsConfiguration: false)
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Empty State View
struct EmptyCardView: View {
    let friendName: String?
    let needsConfiguration: Bool
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#F3E8FF"), Color(hex: "#E9D5FF")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                if needsConfiguration {
                    Text("👆").font(.system(size: 40))
                    Text("Arkadaş Seç")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#2D1E5F"))
                    Text("Widget'a uzun bas →\nDüzenle → Arkadaş")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "#6B7280"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                } else if let name = friendName {
                    Text("✨").font(.system(size: 44))
                    Text(name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#6B7280"))
                    Text("Sürpriz bekleniyor…")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "#9CA3AF"))
                } else {
                    Text("💌").font(.system(size: 40))
                    Text("Önce bir arkadaş ekle")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "#6B7280"))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(8)
        }
    }
}

// MARK: - Filled Card View
//
// The design canvas is a 300×300 square, but widgets come in three very
// different aspect ratios (small 1:1, medium ~2.14:1, large ~0.95:1). To
// avoid wasted space on medium/large and keep the design visually anchored
// on every size we use aspect-**fill** with centered placement: the 300×300
// design is scaled to fully cover the widget bounds and any overflow is
// naturally clipped by the widget container. Elements outside the visible
// area for a given size are simply not shown — the editor exposes a safe
// zone guide so users know where to keep important content.
struct FilledCardView: View {
    let card: CardData
    private let baseCanvasSize: Double = 300.0
    var body: some View {
        GeometryReader { geo in
            let fillScale = max(geo.size.width / baseCanvasSize,
                                geo.size.height / baseCanvasSize)
            let rendered = baseCanvasSize * fillScale
            let offsetX = (geo.size.width - rendered) / 2
            let offsetY = (geo.size.height - rendered) / 2

            ZStack(alignment: .topLeading) {
                // Background: PNG image or solid color
                if card.background.hasPrefix("img:") {
                    Image(String(card.background.dropFirst(4)))
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color(hex: card.background)
                }
                ForEach(card.elements) { el in
                    if el.type == "text" {
                        Text(el.content)
                            .font(.system(size: (el.fontSize ?? 20) * fillScale,
                                          weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: el.color ?? "#1F2937"))
                            .rotationEffect(.degrees(el.rotation ?? 0))
                            .position(x: el.x * fillScale + offsetX,
                                      y: el.y * fillScale + offsetY)
                    } else if el.type == "image" {
                        Image(el.content)
                            .resizable()
                            .scaledToFit()
                            .frame(width: (el.size ?? 40) * fillScale,
                                   height: (el.size ?? 40) * fillScale)
                            .rotationEffect(.degrees(el.rotation ?? 0))
                            .position(x: el.x * fillScale + offsetX,
                                      y: el.y * fillScale + offsetY)
                    } else {
                        Text(el.content)
                            .font(.system(size: (el.size ?? 40) * fillScale))
                            .rotationEffect(.degrees(el.rotation ?? 0))
                            .position(x: el.x * fillScale + offsetX,
                                      y: el.y * fillScale + offsetY)
                    }
                }
                if let sender = card.senderName, !sender.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("💌 \(sender)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(8)
                        }
                    }
                }
            }
            .clipped()
        }
    }
}

// MARK: - Widget Entry View
struct SurpriseCardWidgetEntryView: View {
    var entry: CardEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let card = entry.card {
            FilledCardView(card: card)
                .containerBackground(for: .widget) {
                    if card.background.hasPrefix("img:") {
                        Image(String(card.background.dropFirst(4)))
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(hex: card.background)
                    }
                }
        } else {
            EmptyCardView(friendName: entry.friendName, needsConfiguration: entry.needsConfiguration)
                .containerBackground(for: .widget) { Color(hex: "#F3E8FF") }
        }
    }
}

// MARK: - Widget Configuration
@main
struct SurpriseCardWidget: Widget {
    let kind: String = "SurpriseCardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectFriendIntent.self, provider: CardTimelineProvider()) { entry in
            SurpriseCardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sürpriz Kart")
        .description("Arkadaşından gelen sürpriz kartı göster")
        .supportedFamilies([.systemLarge, .systemMedium, .systemSmall])
    }
}

// MARK: - Preview
#Preview("Empty", as: .systemMedium, widget: {
    SurpriseCardWidget()
}, timeline: {
    CardEntry(date: Date(), card: nil, friendName: "Test Arkadaş", pairId: "test")
})

#Preview("Filled", as: .systemMedium, widget: {
    SurpriseCardWidget()
}, timeline: {
    CardEntry(date: Date(), card: CardData(
        background: "#D8B4E2",
        senderName: "Sevgilin",
        elements: [
            CardElement(id: "1", type: "text", content: "Seni seviyorum! 💕",
                        x: 40, y: 100, fontSize: 24, color: "#FFFFFF", size: nil, rotation: nil),
            CardElement(id: "2", type: "sticker", content: "❤️",
                        x: 130, y: 180, fontSize: nil, color: nil, size: 50, rotation: nil)
        ]
    ), friendName: "Sevgilin", pairId: "test")
})
