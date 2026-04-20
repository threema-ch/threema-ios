import SwiftUI
import ThreemaFramework

extension EnvironmentValues {
    typealias DeselectEmoji = (() -> Void)?
    
    @Entry var isSearchActive = false
    @Entry var willDeselectEmoji: DeselectEmoji = nil
    @Entry var reactionEntries: [ReactionEntry] = []
    @Entry var selectEmojiVariant: ((EmojiVariant) -> Void)? = nil
}

extension EmojiPicker {
    public static var sections: [EmojiCategory.Section] = EmojiCategory.Section.allCases
    
    public static var scrollSections: [EmojiCategory.Section] = EmojiCategory.Section.allCases.filter {
        $0 != .recent
    }
    
    public static var sortedEmojisPerSection: [EmojiCategory.Section: [Emoji]] = EmojiPicker.sections
        .reduce(into: [:]) { result, section in
            result[section] = section.sortedEmoji.filter { emoji in
                emoji.isAvailable
            }
        }
}

extension EmojiPicker {
    typealias DidSelectEmoji = (Emoji) -> Void
    @UserSetting(\.recentEmojis) static var recentEmojis: [String: Int]
    @UserSetting(\.emojiVariantPreference) static var emojiVariantPreference: [String: String]
    
    static func sheet(
        with delegate: any ReactionsModalDelegate
    ) -> UIViewController {
        let emojiPickerVC = UIHostingController(
            rootView: EmojiPicker(model: .init(delegate))
                .environment(\.selectEmojiVariant) {
                    Task { @MainActor in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    recentEmojis[$0.rawValue, default: 0] += 1
                    
                    if let skintone = $0.skintone {
                        emojiVariantPreference[$0.base.rawValue] = skintone.rawValue
                    }
                    else {
                        emojiVariantPreference.removeValue(forKey: $0.base.rawValue)
                    }
                    
                    return delegate.send($0)
                }
        )
        
        if let sheetController = emojiPickerVC.presentationController as? UISheetPresentationController {
            sheetController.detents = emojiPickerVC.traitCollection.horizontalSizeClass == .regular
                ? [.large()]
                : [.medium(), .large()]
            
            sheetController.prefersGrabberVisible = true
        }
        
        return emojiPickerVC
    }
}
