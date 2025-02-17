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
    
    /// View representing the list of emoji items based on search results.
    struct ItemList: View {
        @Binding var toolbarVisible: Bool
        
        @Environment(\.contentSize) var contentSize
        @Environment(\.edgeInsets) var edgeInsets
        @Environment(\.willDeselectEmoji) private var willDeselectEmoji
        @StateObject private var model: EmojiSearchViewModel = .init()
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
                .onChange(of: model.searchResults) { _ in
                    withAnimation {
                        toolbarVisible = model.searchResults.isEmpty && !isTextFieldFocused
                    }
                }
        }
    }
    
    struct SearchScrollGrid: View {
        @EnvironmentObject private var model: EmojiSearchViewModel
        
        var body: some View {
            if !model.searchText.isEmpty {
                if model.searchResults.isEmpty {
                    VStack {
                        if model.isSearching {
                            ProgressView()
                        }
                        else {
                            Text(#localize("emoji_reaction_picker_search_no_result"))
                                .italic()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(24)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .top
                    )
                    .background(.background)
                }
                else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(
                                .adaptive(
                                    minimum: config.minEmojiViewWidth,
                                    maximum: config.maxEmojiViewWidth
                                ),
                                spacing: config.rowSpacing
                            )],
                            spacing: config.columnSpacing
                        ) {
                            ForEach(model.searchResults) { emoji in
                                EquatableEmojiVariantView(emojiVariant: emoji, allowSkinTypeSelection: false)
                                    .equatable()
                                    .id(emoji.self)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                    .background(.background)
                }
            }
        }
    }
    
    struct SearchBarView: View {
        @Environment(\.dismiss) var dismiss
        @Binding var searchText: String
        @FocusState var isTextFieldFocused: Bool

        var body: some View {
       
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)
                    TextField(
                        "",
                        text: $searchText,
                        prompt: Text(#localize("emoji_reaction_picker_search_placeholder"))
                    )
                    .submitLabel(.done)
                    .disableAutocorrection(true)
                    .focused($isTextFieldFocused, equals: true)
                }
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .onTapGesture {
                    isTextFieldFocused = true
                }
                
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
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                            .imageScale(.large)
                    }
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}
