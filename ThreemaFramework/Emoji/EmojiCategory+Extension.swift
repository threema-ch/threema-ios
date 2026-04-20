import Foundation
import ThreemaMacros

extension EmojiCategory {

    public enum Section: String, CaseIterable, Identifiable, Hashable {
        case recent
        case smileysEmotion
        case animalsNature
        case food
        case activities
        case travelPlaces
        case objects
        case symbols
        case flags
        
        public var id: Self { self }
        
        public var icon: String {
            switch self {
            case .recent:
                "clock"
            case .smileysEmotion:
                "face.smiling"
            case .animalsNature:
                "cat"
            case .food:
                "birthday.cake"
            case .activities:
                "soccerball"
            case .travelPlaces:
                "car"
            case .objects:
                "lightbulb"
            case .symbols:
                if #available(iOS 18.0, *) {
                    "xmark.triangle.circle.square"
                }
                else {
                    "checkmark.square"
                }
            case .flags:
                "flag"
            }
        }
        
        public var emoji: [Emoji] {
            switch self {
            case .recent:
                [Emoji]()
            case .smileysEmotion:
                EmojiCategory.smileysEmotion.emojis + EmojiCategory.peopleBody.emojis
            case .animalsNature:
                EmojiCategory.animalsNature.emojis
            case .food:
                EmojiCategory.foodDrink.emojis
            case .activities:
                EmojiCategory.activities.emojis
            case .travelPlaces:
                EmojiCategory.travelPlaces.emojis
            case .objects:
                EmojiCategory.objects.emojis
            case .symbols:
                EmojiCategory.symbols.emojis
            case .flags:
                EmojiCategory.flags.emojis
            }
        }
        
        public var sortedEmoji: [Emoji] {
            emoji.sorted()
        }
        
        public var localizedTitle: String {
            switch self {
            case .activities:
                #localize("emoji_category_activities")
            case .animalsNature:
                #localize("emoji_category_animalsNature")
            case .flags:
                #localize("emoji_category_flags")
            case .food:
                #localize("emoji_category_foodDrink")
            case .objects:
                #localize("emoji_category_objects")
            case .smileysEmotion:
                #localize("emoji_category_smileysEmotion")
            case .symbols:
                #localize("emoji_category_symbols")
            case .travelPlaces:
                #localize(
                    "emoji_category_travelPlaces"
                )
            case .recent:
                #localize("emoji_category_recent")
            }
        }
    }
}
