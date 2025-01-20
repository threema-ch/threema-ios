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

enum SkinTonePicker {
    static let preferenceID = "skinToneEmojiViewFrame"
    static let backgroundPreferenceID = "skinToneEmojiViewBackground"
    static let coordinateSpaceID = "skinToneEmojiViewCoordinateSpace"
    
    public class ViewModel: ObservableObject {
        @Published var frame: CGRect?
        @Published var emojiSelection: (emoji: EmojiVariant, section: EmojiCategory.Section?)?
        @Published var alignment: HorizontalAlignment = .center
        
        public init(
            frame: CGRect? = nil,
            alignment: HorizontalAlignment = .center
        ) {
            self.frame = frame
            self.alignment = alignment
        }
    }
    
    struct BaseModifier: ViewModifier {
        @StateObject var model: ViewModel
        @Environment(\.contentSize) private var contentSize
        @Environment(\.edgeInsets) private var edgeInsets
        @Environment(\.isSearchActive) private var isSearchActive
        @State private var safeAreaBottom: CGFloat = 0
        
        func body(content: Content) -> some View {
            content
                .coordinateSpace(name: SkinTonePicker.coordinateSpaceID)
                .onChange(of: contentSize.height) { _ in
                    deselectEmoji()
                }
                .onChange(of: isSearchActive) {
                    if $0 {
                        deselectEmoji()
                    }
                } // also when results change
                
                .onPreferenceChange(TrackedFrame.Key.self, perform: { frames in
                    if let skinTonePickerFrame = frames.filter({ $0.id == SkinTonePicker.backgroundPreferenceID })
                        .first {
                        safeAreaBottom = skinTonePickerFrame.proxy?.safeAreaInsets.bottom ?? 0
                    }
                    if let skinTonePickerFrame = frames.filter({ $0.id == SkinTonePicker.preferenceID }).first {
                        if let frame = model.frame, frame.minX == skinTonePickerFrame.frame.minX,
                           frame.minY != skinTonePickerFrame.frame.minY {
                            // dismiss the SkinToneSelectionView on scroll
                            deselectEmoji()
                        }
                        
                        model.frame = skinTonePickerFrame.frame
                    }
                })
                .overlay {
                    if let skinTonePickerFrame = model.frame,
                       model.emojiSelection != nil {
                        skinToneOverlay(with: skinTonePickerFrame)
                            .disableDragGesture()
                    }
                }
                .environmentObject(model)
                .environment(\.willDeselectEmoji, deselectEmoji)
        }
        
        private func skinToneOverlay(with skinPickerOriginFrame: CGRect) -> some View {
            ZStack {
                if let emoji = model.emojiSelection?.emoji, skinPickerOriginFrame.minY > 0 {
                    SkinTonePicker.SkinToneSelectionView(
                        targetEmoji: emoji,
                        alignment: $model.alignment
                    )
                    .onTapGesture(perform: deselectEmoji)
                    .frame(
                        width: skinPickerOriginFrame.width,
                        height: skinPickerOriginFrame.height
                    )
                    .animation(nil, value: model.frame)
                    .position(
                        in: .named(SkinTonePicker.coordinateSpaceID),
                        at: .init(
                            x: skinPickerOriginFrame.midX,
                            y: skinPickerOriginFrame.midY
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, safeAreaBottom)
        }
        
        // also dismisses the SkinTonePicker
        private func deselectEmoji() {
            model.emojiSelection = nil
        }
    }
}

// MARK: - SkinTonePicker.SkinToneSelectionView

extension SkinTonePicker {
    struct SkinToneSelectionView: View {
        typealias config = ChatViewConfiguration.EmojiReactions.Picker

        @State var targetEmoji: EmojiVariant
        @Binding var alignment: HorizontalAlignment
        
        var body: some View {
            VStack(alignment: alignment, spacing: -2) {
                HStack(spacing: -10) {
                    ForEach(Emoji.SkinTone.allCases) { skinTone in
                        EmojiVariantView(emoji: EmojiVariant(base: targetEmoji.base, skintone: skinTone))
                            .frame(
                                width: config.minEmojiViewWidth,
                                height: config.minEmojiViewWidth
                            )
                    }
                }
                .background {
                    VariableRoundedCornerRectangle(
                        radius: config.cornerRadius,
                        cornerToLeaveSquare: determineNoRadius()
                    )
                    .fill(.gray)
                    .padding(2)
                }
                .zIndex(0)
                HStack {
                    EmojiVariantView(emoji: targetEmoji)
                        .frame(
                            width: config.minEmojiViewWidth,
                            height: config.minEmojiViewWidth
                        )
                }
                .zIndex(1)
                .background {
                    VariableRoundedCornerRectangle(
                        radius: config.cornerRadius,
                        cornerToLeaveSquare: [.topLeft, .topRight]
                    )
                    .fill(.gray)
                    .padding(.horizontal, 2)
                }
            }
        }
        
        private func determineNoRadius() -> UIRectCorner {
            switch alignment {
            case .leading: .bottomLeft
            case .trailing: .bottomRight
            default: []
            }
        }
    }
}

extension View {
    public func skinTonePicker() -> some View {
        modifier(SkinTonePicker.BaseModifier(model: .init()))
    }
}
