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

import Combine
import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct EmojiReactionModal: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @Namespace private var menuItemTransition
    @State private var selectedIndex = 0
    
    @StateObject var model: ReactionModel
    
    var body: some View {
        if selectedIndex <= model.reactionEntries.count - 1 {
            let reaction = model.reactionEntries[selectedIndex]
            VStack(spacing: 0) {
                Spacer(minLength: 8)
                if model.showInfoBox {
                    infoBox
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }
                reactionsRow
                userList(
                    reaction.userReactionEntries,
                    for: reaction
                )
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .padding(.top, 10)
        }
        else {
            VStack(spacing: 0) {
                Text(verbatim: "Error loading reactions. Try again later.")
            }
            .onAppear {
                dismiss()
            }
        }
    }
    
    private var menuItems: some View {
        ForEach(model.reactionEntries) { reactionEntry in
            let index = model.reactionEntries.firstIndex(of: reactionEntry) ?? 0
            VStack {
                MenuBarItem(
                    namespace: menuItemTransition,
                    isSelected: reactionEntry.reactedByMe,
                    value: Double(model.prevCountPerReaction[reactionEntry.reaction] ?? 0), content: .init(
                        emoji: reactionEntry.displayValue,
                        count: model.countPerReaction[reactionEntry.reaction] ?? 0
                    )
                )
                .padding(.top, 6)
                .padding(.bottom, 4)
                
                ZStack {
                    if selectedIndex == index {
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(Colors.chatReactionBubbleTextColor.color)
                            .matchedGeometryEffect(id: "menuItemTransition", in: menuItemTransition)
                    }
                
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.clear)
                }
            }
            .id(reactionEntry)
            .frame(width: UIScreen.main.bounds.width / 5.5)
            .onTapGesture {
                withAnimation {
                    selectedIndex = index
                }
            }
        }
    }
    
    private var reactionsRow: some View {
        ScrollViewReader { scrollView in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    menuItems
                }
            }
            .onChange(of: selectedIndex) { index in
                Task { @MainActor in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                withAnimation {
                    scrollView.scrollTo(index, anchor: .center)
                }
            }
            .background {
                VStack {
                    Spacer()
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
        }
    }
    
    private var infoBox: some View {
        GroupBox {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
                Text(#localize("reaction_alert_message_no_support_local"))
            }
            .foregroundStyle(.secondary)
            .font(.subheadline)
        }
    }
    
    private func userList(_ userReactions: [UserReactionEntry], for reaction: ReactionEntry) -> some View {
        let sorted = userReactions.sorted {
            $0.isMe && !$1.isMe
        }
        
        return List(sorted) { user in
            HStack {
                user.profileImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text(user.name)
                    .font(.subheadline)
                
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .overlay(alignment: .trailing) {
                if user.isMe, UserSettings.shared().sendEmojiReactions,
                   let emoji = EmojiVariant(rawValue: reaction.reaction) {
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            model.removeOwnReaction(emoji)
                        }
                        label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .accessibilityLabel(#localize("delete"))
                    }
                }
            }
            // .id(user.id)
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - EmojiReactionModal.MenuBarItem

extension EmojiReactionModal {
    struct MenuBarItem: View {
        struct Content {
            let emoji: String
            let count: Int
        }
        
        let namespace: Namespace.ID
        var isSelected: Bool
        
        @State var value: Double = 0
        @State var content: Content
        
        var body: some View {
            VStack {
                HStack(spacing: 2) {
                    Text(content.emoji)
                        .font(.title3)
                    
                    if #available(iOS 17.0, *) {
                        Text(String(format: "%.0f", value))
                            .contentTransition(.numericText(value: value))
                            .font(.subheadline)
                            .fontWeight(isSelected ? .bold : .regular)
                            .foregroundColor(Colors.chatReactionBubbleTextColor.color)
                    }
                    else {
                        Text(verbatim: "\(content.count)")
                            .font(.subheadline)
                            .fontWeight(isSelected ? .bold : .regular)
                            .foregroundColor(Colors.chatReactionBubbleTextColor.color)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .onAppear {
                updateValue(
                    oldCount: Int(value),
                    newCount: content.count
                )
            }
        }
        
        private func updateValue(oldCount: Int, newCount: Int) {
            if newCount > oldCount {
                let delta = newCount - oldCount
                withAnimation {
                    value += Double(delta)
                }
            }
            else if newCount < oldCount {
                let delta = oldCount - newCount
                withAnimation {
                    value -= Double(delta)
                }
            }
        }
    }
}

typealias EmojiReactionModalViewController = UIHostingController<EmojiReactionModal>
extension EmojiReactionModalViewController {
    static func sheet(_ reactionsManager: any ReactionsModalDelegate) -> EmojiReactionModalViewController {
        UIHostingController(
            rootView: EmojiReactionModal(model: .init(reactionsManager))
        ).then { vc in
            if let sheetController = vc.presentationController as? UISheetPresentationController {
                sheetController.detents = [.medium(), .large()]
                sheetController.prefersGrabberVisible = true
                sheetController.prefersScrollingExpandsWhenScrolledToEdge = true
            }
            let window = UIApplication.shared.windows.first(where: \.isKeyWindow)
            let inverseSafeAreaInset = window?.safeAreaInsets.bottom ?? 0
            vc.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: -inverseSafeAreaInset, right: 0)
        }
    }
}
