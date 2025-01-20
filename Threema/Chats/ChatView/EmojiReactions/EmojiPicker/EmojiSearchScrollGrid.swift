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
import ThreemaMacros

/// `EmojiPicker` extension to handle emoji search and display functionalities.
extension EmojiPicker {
    class SearchViewModel: ObservableObject {
        @Published var searchResults: [EmojiVariant] = []
        @Published var scale: CGFloat = ChatViewConfiguration.EmojiReactions.Picker.initialItemScale
        @Published var searchText = ""
    }
    
    /// View representing the list of emoji items based on search results.
    struct ItemList: View {
        @Binding var toolbarVisible: Bool
        
        @Environment(\.contentSize) var contentSize
        @Environment(\.edgeInsets) var edgeInsets
        @Environment(\.willDeselectEmoji) private var willDeselectEmoji
        @StateObject private var model: SearchViewModel = .init()
        @FocusState private var isTextFieldFocused: Bool
        
        var body: some View {
            VStack {
                searchBar
                ScrollGrid()
                    .overlay {
                        SearchScrollGrid()
                            .environmentObject(model)
                    }
            }
            .onChange(of: isTextFieldFocused) { newValue in
                toolbarVisible = !newValue
            }
            .onChange(of: model.searchResults) { _ in
                willDeselectEmoji?()
            }
        }
        
        private var searchBar: some View {
            SearchBarView(searchText: $model.searchText, isTextFieldFocused: _isTextFieldFocused)
                .padding([.top, .leading, .trailing])
                .onChange(of: model.searchText, perform: { searchText in
                    withAnimation { toolbarVisible = searchText.isEmpty && !isTextFieldFocused }
                    model.searchResults = Emoji.search(searchText)
                    model.scale = config.initialItemScale
                    withAnimation(.bouncy(extraBounce: 0.25).speed(1.2).delay(0.01)) {
                        model.scale = 1
                    }
                })
        }
    }
    
    struct SearchScrollGrid: View {
        @EnvironmentObject private var model: SearchViewModel
        
        var body: some View {
            if !model.searchText.isEmpty {
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
                        ForEach(model.searchResults) { emoji in
                            EquatableEmojiVariantView(emojiVariant: emoji)
                                .equatable()
                                .id(emoji.self)
                                .scaleEffect(model.scale)
                        }
                    }
                    .padding(.horizontal)
                }
                .background(.background)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }
        }
    }
    
    struct SearchBarView: View {
        @Environment(\.dismiss) var dismiss
        @Binding var searchText: String
        @FocusState var isTextFieldFocused: Bool

        var body: some View {
            VStack {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField(
                            "",
                            text: $searchText,
                            prompt: Text(#localize("emoji_reaction_picker_search_placeholder"))
                        )
                        .submitLabel(.done)
                        .disableAutocorrection(true)
                        .focused($isTextFieldFocused)
                    }
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    
                    if isTextFieldFocused {
                        Button {
                            searchText.removeAll()
                            isTextFieldFocused = false
                        } label: {
                            Text(#localize("cancel"))
                                .font(.subheadline)
                        }
                    }
                    else {
                        Button {
                            dismiss()
                        } label: {
                            Text(#localize("Done"))
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }
}
