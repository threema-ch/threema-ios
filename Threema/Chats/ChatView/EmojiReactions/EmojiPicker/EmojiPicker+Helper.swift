//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
            sheetController.detents = UIDevice.current.userInterfaceIdiom == .pad ? [.large()] : [.medium(), .large()]
            
            sheetController.prefersGrabberVisible = true
        }
        
        return emojiPickerVC
    }
}
