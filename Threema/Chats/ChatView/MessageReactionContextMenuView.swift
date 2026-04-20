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
                                .apply { view in
                                    if #available(iOS 26.0, *) {
                                        view
                                            .foregroundStyle(Color.primary)
                                    }
                                    else {
                                        view
                                            .foregroundStyle(Colors.chatReactionBubbleTextColor.color)
                                    }
                                }
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
                .apply { view in
                    if #available(iOS 26.0, *) {
                        view
                            .glassEffect(.regular.interactive())
                    }
                    else {
                        view
                            .background(.regularMaterial)
                    }
                }
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
