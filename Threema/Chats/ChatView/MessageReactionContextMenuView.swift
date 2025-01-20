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

import Foundation
import SwiftUI
import ThreemaFramework

struct MessageReactionContextMenuView: View {
    typealias config = ChatViewConfiguration.EmojiReactions.ContextMenuView
    typealias animationConfig = ChatViewConfiguration.EmojiReactions.Animation

    static let viewPadding = config.viewPadding
    static let buttonPadding = config.buttonPadding

    static let fontHeight = UIFont.preferredFont(forTextStyle: .title2).lineHeight
    static let frameHeight = 2 * (viewPadding + buttonPadding) + fontHeight
    
    // We calculate the approximate width for the view: 2x padding on both sides, then for each of the 7 elements, the
    // spacing, the padding and the width, which should be approx. the same as the height.
    static let frameWidth = min(
        2 * viewPadding + 7 * (4 + fontHeight + buttonPadding),
        UIScreen.main.bounds.width * config.maxFrameWidthMultiplier
    )
    
    let forHighlighting: Bool
    let isOwnMessage: Bool
    let reactionsManager: ReactionsManager?
    
    private let font: Font = .title2
    
    @State private var opacity = 0.0
    
    var body: some View {
        VStack {
            if let reactionsManager {
                HStack(spacing: config.buttonSpacing) {
                    if reactionsManager.localReactionSupport, !reactionsManager.recipientHasGateWayID() {
                        ForEach(
                            reactionsManager.baseReactionEmojis + reactionsManager
                                .defaultReactionEmojis
                        ) { reaction in
                            Button {
                                reactionsManager.send(EmojiVariant(base: reaction, skintone: nil))
                            } label: {
                                Text(reaction.rawValue)
                                    .padding(MessageReactionContextMenuView.buttonPadding)
                                    .opacity(
                                        reactionsManager.recipientReactionSupport != .none || reactionsManager
                                            .baseReactionEmojis.contains(reaction) ? 1.0 : config.disabledButtonOpacity
                                    )
                                    .background {
                                        if reactionsManager.isCurrentlySelected(emoji: EmojiVariant(
                                            base: reaction,
                                            skintone: nil
                                        )) {
                                            Color(uiColor: Colors.chatReactionBubbleSelected)
                                                .clipShape(Circle())
                                        }
                                    }
                            }
                        }
                    }
                    else {
                        ForEach(reactionsManager.baseReactionEmojis) { reaction in
                            Button {
                                reactionsManager.send(EmojiVariant(base: reaction, skintone: nil))
                            } label: {
                                Text(reaction.rawValue)
                                    .padding(MessageReactionContextMenuView.buttonPadding)
                                    .background {
                                        if reactionsManager.isCurrentlySelected(emoji: EmojiVariant(
                                            base: reaction,
                                            skintone: nil
                                        )) {
                                            Color(uiColor: Colors.chatReactionBubbleSelected)
                                                .clipShape(Circle())
                                        }
                                    }
                            }
                        }
                    }
                    
                    if reactionsManager.pickerButtonVisible() {
                        Button {
                            reactionsManager.showEmojiPickerSheet()
                        } label: {
                            Image(.threemaCustomFaceSmilingBadgePlus)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .offset(y: -1.0)
                                .padding(MessageReactionContextMenuView.buttonPadding / 3)
                                .opacity(
                                    reactionsManager.recipientReactionSupport != .none && reactionsManager
                                        .localReactionSupport ? 1.0 : config.disabledButtonOpacity
                                )
                        }
                    }
                }
                .font(font)
                .padding(MessageReactionContextMenuView.viewPadding)
                .background(.regularMaterial)
                .opacity(opacity)
                .clipShape(Capsule())
                .scaleEffect(opacity, anchor: isOwnMessage ? .bottomTrailing : .bottomLeading)
                .onAppear {
                    if forHighlighting {
                        withAnimation(
                            .smooth.delay(animationConfig.defaultDelay)
                                .speed(animationConfig.defaultSpeed)
                        ) {
                            opacity = 1.0
                        }
                    }
                }
            }
        }
        .padding(isOwnMessage ? .leading : .trailing, 2)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: MessageReactionContextMenuView.frameWidth)
    }
}

typealias MessageReactionContextMenuUIView = UIHostingController<MessageReactionContextMenuView>
extension MessageReactionContextMenuUIView {
    convenience init(forHighlighting: Bool, isOwnMessage: Bool, reactionsManager: ReactionsManager?) {
        self.init(
            rootView: MessageReactionContextMenuView(
                forHighlighting: forHighlighting,
                isOwnMessage: isOwnMessage,
                reactionsManager: reactionsManager
            )
        )
        view.backgroundColor = .clear
        view.clipsToBounds = true
    }
}
