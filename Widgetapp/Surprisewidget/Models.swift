import Foundation

struct User: Codable, Sendable {
    let id: String
    let email: String
    let name: String
    let pair_ids: [String]?
}

struct TokenResponse: Codable, Sendable {
    let user: User
    let access_token: String
}

struct CanvasElement: Codable, Identifiable, Sendable {
    var id: String
    var type: String   // "text" | "sticker" | "image"
    var content: String
    var x: Double
    var y: Double
    var fontSize: Double?
    var color: String?
    var size: Double?
    var fontFamily: String?
    var rotation: Double?   // degrees
}

struct Card: Codable, Identifiable, Sendable {
    let id: String
    let pair_id: String?
    let background: String
    let elements: [CanvasElement]
    let sender_name: String?
    let created_at: String?
}

// A single friend/partner
struct Friend: Codable, Identifiable, Sendable {
    let pair_id: String
    let partner_id: String
    let partner_name: String
    let partner_nickname: String?
    let relationship: String?
    let status: String  // "paired" | "pending"

    var id: String { pair_id }
    var displayName: String { partner_nickname ?? partner_name }
}

// Backward-compat status response (also contains full friends list)
struct PairStatus: Codable, Sendable {
    let status: String
    let partner_name: String?
    let partner_nickname: String?
    let pair_id: String?
    let invite_code: String?
    let friends: [Friend]?
}

struct LimitsStatus: Codable, Sendable {
    let used: Int
    let limit: Int
    let remaining: Int
}

struct InviteCodeResponse: Codable, Sendable {
    let invite_code: String
}

struct UnpairRequest: Encodable {
    let pair_id: String
}

struct EmptyBody: Encodable {}

// MARK: - Constants
let BACKGROUNDS = ["#D8B4E2", "#2DD4BF", "#F472B6", "#FDE047", "#FFFFFF",
                   "#A5F3FC", "#BBF7D0", "#FED7AA", "#E9D5FF", "#FECDD3"]
// PNG image backgrounds — stored as "img:bg_N" in the background field
let BG_IMAGES = (1...9).map { "img:bg_\($0)" }
let TEXT_COLORS  = ["#1F2937", "#FFFFFF", "#F472B6", "#9D4CDD", "#2DD4BF"]

// MARK: - Background helpers
/// Returns true when the background string references an image asset
func bgIsImage(_ bg: String) -> Bool { bg.hasPrefix("img:") }
/// Strips the "img:" prefix to get the asset name
func bgAssetName(_ bg: String) -> String { String(bg.dropFirst(4)) }
