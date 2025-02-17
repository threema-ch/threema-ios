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
    
    let forHighlighting: Bool
    let isOwnMessage: Bool
    let reactionsManager: ReactionsManager?
    
    private let font: Font = .title
    
    @State private var opacity = 0.0
    
    var body: some View {
        VStack {
            if let reactionsManager {
                HStack(spacing: config.buttonSpacing) {
                    if !reactionsManager.recipientHasGateWayID() {
                        ForEach(
                            ReactionsManager.baseReactionEmojis + ReactionsManager
                                .defaultReactionEmojis
                        ) { reaction in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                reactionsManager.send(reaction)
                            } label: {
                                Text(reaction.rawValue)
                                    .padding(config.buttonPadding)
                                    .opacity(
                                        reactionsManager.recipientReactionSupport != .none || ReactionsManager
                                            .baseReactionEmojis.contains(reaction) ? 1.0 : config.disabledButtonOpacity
                                    )
                                    .background {
                                        if reactionsManager.isCurrentlySelected(emoji: reaction) {
                                            Color(uiColor: Colors.chatReactionBubbleSelected)
                                                .clipShape(Circle())
                                        }
                                    }
                            }
                        }
                    }
                    else {
                        ForEach(ReactionsManager.baseReactionEmojis) { reaction in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                reactionsManager.send(reaction)
                            } label: {
                                Text(reaction.rawValue)
                                    .padding(config.buttonPadding)
                                    .background {
                                        if reactionsManager.isCurrentlySelected(emoji: reaction) {
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
                                .foregroundStyle(Colors.chatReactionBubbleTextColor.color)
                                .imageScale(.small)
                                .offset(y: -1.0)
                                .padding(config.buttonPadding)
                                .opacity(
                                    reactionsManager.recipientReactionSupport != .none ? 1.0 : config
                                        .disabledButtonOpacity
                                )
                        }
                    }
                }
                .font(font)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .padding(config.viewPadding)
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
