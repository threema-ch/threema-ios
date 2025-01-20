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

struct EmojiVariantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.selectEmojiVariant) private var selectEmojiVariant
    
    var emoji: EmojiVariant
    
    var body: some View {
        emojiButton
            .buttonStyle(HighlightedButtonStyle())
    }
    
    private var emojiButton: some View {
        Button {
            selectEmojiVariant?(emoji)
            dismiss()
        } label: {
            VStack {
                Text(emoji.rawValue)
                    .font(.largeTitle)
            }
        }
    }
}

// MARK: - EmojiVariantView.HighlightedButtonStyle

extension EmojiVariantView {
    struct HighlightedButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(configuration.isPressed ? Color.accentColor : Color.clear)
                .clipShape(Circle())
                .scaleEffect(configuration.isPressed ? ChatViewConfiguration.EmojiReactions.Picker.onPressScale : 1.0)
                .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
        }
    }
}
