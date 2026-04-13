import Foundation

// A sticker is either a plain emoji or a named image asset
enum StickerItem: Hashable, Sendable {
    case emoji(String)
    case image(String) // asset catalog name (e.g. "stk_love_heart")

    // The string stored in CanvasElement.content
    var content: String {
        switch self {
        case .emoji(let e): return e
        case .image(let n): return n
        }
    }

    // The type stored in CanvasElement.type
    var elementType: String {
        switch self {
        case .emoji: return "sticker"
        case .image: return "image"
        }
    }
}

struct StickerCategory: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let icon: String          // Emoji used as category tab icon
    let items: [StickerItem]

    // Backwards-compat: old emoji-only categories
    init(name: String, icon: String, stickers: [String]) {
        self.name = name
        self.icon = icon
        self.items = stickers.map { .emoji($0) }
    }

    init(name: String, icon: String, items: [StickerItem]) {
        self.name = name
        self.icon = icon
        self.items = items
    }
}

let STICKER_CATEGORIES: [StickerCategory] = [
    StickerCategory(
        name: "Layer",
        icon: "paintpalette.fill",
        items: [
            .image("stk_layer_9"),
            .image("stk_layer_10"),
            .image("stk_layer_11"),
            .image("stk_layer_12"),
            .image("stk_layer_13"),
            .image("stk_layer_14"),
            .image("stk_layer_15"),
            .image("stk_layer_16"),
            .image("stk_layer_18"),
            .image("stk_layer_20"),
        ]
    ),
    StickerCategory(
        name: "Uzay",
        icon: "moon.stars.fill",
        items: [
            .image("stk_space_1"),
            .image("stk_space_2"),
            .image("stk_space_3"),
            .image("stk_space_4"),
            .image("stk_space_5"),
            .image("stk_space_6"),
            .image("stk_space_7"),
            .image("stk_space_8"),
            .image("stk_space_9"),
            .image("stk_space_10"),
            .image("stk_space_11"),
            .image("stk_space_12"),
            .image("stk_space_13"),
        ]
    ),
    StickerCategory(
        name: "Kediler",
        icon: "pawprint.fill",
        items: [
            .image("stk_cat_cat"),
            .image("stk_cat_surprise"),
            .image("stk_cat2_1"),
            .image("stk_cat2_2"),
            .image("stk_cat2_3"),
            .image("stk_cat2_4"),
            .image("stk_cat2_5"),
            .image("stk_cat2_6"),
            .image("stk_cat2_7"),
            .image("stk_cat2_8"),
            .image("stk_cat2_9"),
            .image("stk_cat2_10"),
            .image("stk_cat2_11"),
            .image("stk_cat2_12"),
            .image("stk_cat2_13"),
            .image("stk_cat2_14"),
            .image("stk_cat2_15"),
            .image("stk_cat2_16"),
            .image("stk_cat2_17"),
            .image("stk_cat2_18"),
            .image("stk_cat2_19"),
            .image("stk_cat2_20"),
            .image("stk_cat2_21"),
            .image("stk_cat2_22"),
            .image("stk_cat2_cat"),
            .image("stk_cat2_cat-animal"),
            .image("stk_cat2_surprise"),
        ]
    ),
    StickerCategory(
        name: "Yaz",
        icon: "sun.max.fill",
        items: [
            .image("stk_sum_sun"),
            .image("stk_sum_beach"),
            .image("stk_sum_coconut"),
            .image("stk_sum_icecream"),
            .image("stk_sum_pineapple"),
            .image("stk_sum_pool"),
            .image("stk_sum_surfing"),
            .image("stk_sum_sunbathing"),
            .image("stk_sum_turtle"),
            .image("stk_sum_picnic"),
            .image("stk_sum_holiday"),
            .image("stk_sum_suitcase"),
            .image("stk_sum_summertime"),
            .image("stk_sum2_1"),
            .image("stk_sum2_2"),
            .image("stk_sum2_3"),
            .image("stk_sum2_4"),
            .image("stk_sum2_5"),
            .image("stk_sum2_6"),
            .image("stk_sum2_7"),
        ]
    ),
    StickerCategory(
        name: "Doğum Günü",
        icon: "gift.fill",
        items: [
            .image("stk_bday_happy"),
            .image("stk_bday_happy2"),
            .image("stk_bday_happy3"),
            .image("stk_bday_cake"),
            .image("stk_bday_cake2"),
            .image("stk_bday_partyhat"),
            .image("stk_bday_birthday"),
            .image("stk_bday_garland"),
            .image("stk_bday_cheers"),
            .image("stk_bday_girl"),
            .image("stk_bday_girl2"),
            .image("stk_bday_panda"),
            .image("stk_bday_dog"),
            .image("stk_bday_ghost"),
        ]
    ),
    StickerCategory(
        name: "Aşk",
        icon: "heart.fill",
        items: [
            .image("stk_love_heart"),
            .image("stk_love_heart2"),
            .image("stk_love_iloveyou"),
            .image("stk_love_loveyou"),
            .image("stk_love_love"),
            .image("stk_love_love2"),
            .image("stk_love_love3"),
            .image("stk_love_couple"),
            .image("stk_love_couple2"),
            .image("stk_love_couple3"),
            .image("stk_love_kiss"),
            .image("stk_love_kiss2"),
            .image("stk_love_blushing"),
            .image("stk_love_flirty"),
            .image("stk_love_letter"),
            .image("stk_love_romance"),
            .image("stk_love_mom"),
            .image("stk_love_duck"),
            .image("stk_love_hand"),
            .image("stk_love_panda"),
            .image("stk_love_rabbit"),
            .image("stk_love_smile"),
            .image("stk_love_unicorn"),
            .image("stk_love_valentines"),
        ]
    ),
    StickerCategory(
        name: "Doğa",
        icon: "leaf.fill",
        items: [
            .image("stk_nature_autumn"),
            .image("stk_nature_birds"),
            .image("stk_nature_buterflies"),
            .image("stk_nature_chamomile"),
            .image("stk_nature_flower1"),
            .image("stk_nature_flower"),
            .image("stk_nature_frog"),
            .image("stk_nature_landscape"),
            .image("stk_nature_leaf"),
            .image("stk_nature_moon"),
            .image("stk_nature_mushroom"),
            .image("stk_nature_palm-tree1"),
            .image("stk_nature_palm-tree"),
            .image("stk_nature_rain1"),
            .image("stk_nature_rain"),
            .image("stk_nature_rainbow1"),
            .image("stk_nature_rainbow"),
            .image("stk_nature_summer"),
            .image("stk_nature_sunflower"),
            .image("stk_nature_thunderstorm"),
            .image("stk_nature_tree1"),
            .image("stk_nature_tree2"),
            .image("stk_nature_tree3"),
            .image("stk_nature_tree4"),
            .image("stk_nature_tree5"),
            .image("stk_nature_tree"),
            .image("stk_nature_tulips"),
            .image("stk_nature_windy"),
        ]
    ),
    StickerCategory(
        name: "Hayvanlar",
        icon: "hare.fill",
        items: [
            .image("stk_animal_angry"),
            .image("stk_animal_animals"),
            .image("stk_animal_cobra"),
            .image("stk_animal_duck1"),
            .image("stk_animal_duck2"),
            .image("stk_animal_duck3"),
            .image("stk_animal_duck4"),
            .image("stk_animal_duck"),
            .image("stk_animal_fish"),
            .image("stk_animal_good"),
            .image("stk_animal_koala1"),
            .image("stk_animal_koala2"),
            .image("stk_animal_koala"),
            .image("stk_animal_love1"),
            .image("stk_animal_love"),
            .image("stk_animal_pandakopyas"),
            .image("stk_animal_panda"),
            .image("stk_animal_parrot1"),
            .image("stk_animal_parrot"),
            .image("stk_animal_penguin"),
            .image("stk_animal_perch"),
            .image("stk_animal_please"),
            .image("stk_animal_rich"),
            .image("stk_animal_seashell"),
            .image("stk_animal_shark1"),
            .image("stk_animal_shark"),
            .image("stk_animal_unicorn"),
            .image("stk_animal_yoga"),
        ]
    )
]
