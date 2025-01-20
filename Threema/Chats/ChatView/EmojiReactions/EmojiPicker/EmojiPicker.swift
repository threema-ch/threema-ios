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

/// A view component that renders an emoji picker interface.
public struct EmojiPicker: View {
    @StateObject var model: ReactionModel
    @State var toolbarVisible = true
    
    public var body: some View {
        ItemList(toolbarVisible: $toolbarVisible)
            .emojiToolbar(isVisible: $toolbarVisible)
            .skinTonePicker()
            .registerSizeObserver()
            .environment(\.isSearchActive, !toolbarVisible)
            .environment(
                \.reactionEntries,
                model
                    .reactionEntries
                    .filter { $0.displayValue != "�" }
                    .sorted(by: { $0.userReactionEntries.count > $1.userReactionEntries.count })
                    .sorted(by: {
                        if let d1 = $0.userReactionEntries.map(\.sortDate).sorted().first,
                           let d2 = $1.userReactionEntries.map(\.sortDate).sorted().first {
                            d1 > d2
                        }
                        else {
                            false
                        }
                    })
            )
    }
}
