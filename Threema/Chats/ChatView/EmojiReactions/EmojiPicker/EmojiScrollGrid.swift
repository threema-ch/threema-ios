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

// MARK: - EmojiPicker.ScrollGrid

extension EmojiPicker {
    typealias config = ChatViewConfiguration.EmojiReactions.Picker
   
    struct ScrollGrid: View {
        @UserSetting(\.recentEmojis) private var recentEmojis: [String: Int]
        @UserSetting(\.emojiVariantPreference) private var emojiVariantPreference: [Emoji: Emoji.SkinTone]
        @Environment(\.reactionEntries) private var reactionEntries: [ReactionEntry]
        
        var body: some View {
            scrollGrid
                .scrollBarCoordinator()
        }

        private var scrollGrid: some View {
            ScrollView {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(
                            .adaptive(
                                minimum: config.minEmojiViewWidth,
                                maximum: config.maxEmojiViewWidth
                            ),
                            spacing: config.rowSpacing
                        ),
                        count: config.columns
                    ),
                    spacing: config.columnSpacing
                ) {
                    if !reactionEntries.isEmpty {
                        Section(
                            header:
                            HStack {
                                Text("emoji_picker_reactionOnMessage")
                                    .font(.headline)
                                    .padding(.horizontal, 10)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        ) {
                            ForEach(reactionEntries, id: \.self) { reaction in
                                if let emojiVariant = EmojiVariant(rawValue: reaction.reaction) {
                                    EquatableEmojiVariantView(
                                        emojiVariant: emojiVariant,
                                        currentSection: nil
                                    )
                                    .background {
                                        if reaction.reactedByMe {
                                            Circle()
                                                .fill(Colors.chatReactionBubbleHighlighted.color)
                                                .padding(.horizontal, 2)
                                        }
                                    }
                                }
                            }
                            .animation(.bouncy, value: reactionEntries)
                        }
                    }
                    let recentEmojis = orderedRecentEmojis()
                    if !recentEmojis.isEmpty {
                        Section(header: sectionHeader(.recent)) {
                            ForEach(recentEmojis, id: \.self) { emoji in
                                EquatableEmojiVariantView(
                                    emojiVariant: emoji,
                                    currentSection: .recent
                                )
                            }
                        }
                        .id(EmojiCategory.Section.recent.id)
                    }
                    ForEach(EmojiPicker.scrollSections, id: \.self) { section in
                        scrollGridSectionItem(section)
                    }
                }
                .padding(.horizontal)
            }
        }
        
        private func scrollGridSectionItem(_ section: EmojiCategory.Section) -> some View {
            Section(header: sectionHeader(section)) {
                ForEach(EmojiPicker.sortedEmojisPerSection[section] ?? [], id: \.self) { emoji in
                    EquatableEmojiVariantView(
                        emojiVariant: EmojiVariant(
                            base: emoji,
                            skintone: emojiVariantPreference[emoji]
                        ),
                        currentSection: section
                    )
                    .equatable()
                    .id(emoji.self)
                }
            }
            .trackSection(section)
        }
        
        @ViewBuilder
        private func sectionHeader(_ section: EmojiCategory.Section) -> some View {
            HStack {
                Text(section.localizedTitle)
                    .font(.headline)
                    .padding(.horizontal, 10)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .id(section.id)
        }
        
        private func orderedRecentEmojis() -> [EmojiVariant] {
            recentEmojis.keys
                .sorted { recentEmojis[$0]! < recentEmojis[$1]! }
                .compactMap { EmojiVariant(rawValue: $0) }
        }
    }
    
    struct EquatableEmojiVariantView: View {
        let emojiVariant: EmojiVariant
        var currentSection: EmojiCategory.Section? = nil
        @EnvironmentObject private var model: SkinTonePicker.ViewModel
        @Environment(\.selectEmojiVariant) private var selectEmojiVariant
        @Environment(\.contentSize) private var contentSize
        @Environment(\.dismiss) private var dismiss
        @State private var highlighted = false
        
        var body: some View {
            Button {
                selectEmojiVariant?(emojiVariant)
                dismiss()
            } label: {
                Text(emojiVariant.rawValue)
                    .font(.largeTitle)
            }
            .frame(
                minWidth: config.minEmojiViewWidth,
                minHeight: config.minEmojiViewWidth
            )
            .onLongPress(
                minimumDuration: config.minimumLongPressDuration,
                coordinateSpace: .global,
                isEnabled: emojiVariant.hasSkinToneOptions,
                {
                    if model.emojiSelection == nil, emojiVariant.hasSkinToneOptions {
                        hapticFeedBack()
                    }
                    model.emojiSelection = emojiVariant.hasSkinToneOptions ? (emojiVariant, currentSection) : nil
                },
                onTouchesBegan: { location in
                    if emojiVariant.hasSkinToneOptions {
                        align(location)
                    }
                    else {
                        highlighted = true
                    }
                    model.emojiSelection = nil
                },
                onTouchesEnded: { _ in
                    if model.emojiSelection?.emoji == nil {
                        selectEmojiVariant?(emojiVariant)
                        dismiss()
                    }
                },
                onTouchesMoved: { _ in
                    highlighted = false
                }
            )
            .background {
                Circle()
                    .fill(Colors.chatReactionBubbleHighlighted.color)
                    .opacity(highlighted ? 1 : 0)
                    .cornerRadius(config.cornerRadius)
            }
            .overlay(
                alignment: calculateAlignment(),
                content: {
                    // we present a properly aligned hidden SkinToneSelectionView to grab the global and local
                    // coordinates
                    // these coordinates are used inside the grid scroll view for drawing a non hidden copy at the exact
                    // same spot
                    // this is required for the SkinToneSelectionView to be on top of everything else. Otherwise other
                    // views like
                    // the search bar or the following emojis (visible on the grid) will overlap with this here.
                    // the implicit correct origin is what we cannot get without this.
                    if model.emojiSelection?.emoji == emojiVariant, model.emojiSelection?.section == currentSection {
                        SkinTonePicker.SkinToneSelectionView(
                            targetEmoji: emojiVariant,
                            alignment: $model.alignment
                        )
                        .hidden()
                        .trackPreference(
                            SkinTonePicker.backgroundPreferenceID,
                            coordinateSpace: .global
                        )
                        .trackPreference(
                            SkinTonePicker.preferenceID,
                            coordinateSpace: .named(SkinTonePicker.coordinateSpaceID)
                        )
                    }
                }
            )
        }
        
        /// Aligns the "T" shaped SkinToneSelectionView to the tap location. It appears as an 90 degree rotated ""L"
        /// shape.
        /// - Parameter tapLocation: The exact location of the tap.
        private func align(_ tapLocation: CGPoint) {
            Task { @MainActor in
                if tapLocation.x < contentSize.width / 3 {
                    model.alignment = .leading
                }
                else if tapLocation.x > 2 * contentSize.width / 3 {
                    model.alignment = .trailing
                }
                else {
                    model.alignment = .center
                }
            }
        }
        
        private func calculateAlignment() -> Alignment {
            switch model.alignment {
            case .leading: .bottomLeading
            case .trailing: .bottomTrailing
            default: .bottom
            }
        }
    }
}

// MARK: - EmojiPicker.EquatableEmojiVariantView + Equatable

extension EmojiPicker.EquatableEmojiVariantView: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.emojiVariant == rhs.emojiVariant
    }
}

nonisolated func hapticFeedBack(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    Task { @MainActor in
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
