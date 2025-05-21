//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

class EmojiSearchViewModel: ObservableObject {
    
    typealias config = ChatViewConfiguration.EmojiReactions.Picker
    
    @Published var searchResults: [EmojiVariant] = []
    @Published var searchText = ""
    @Published var isSearching = false
    
    private var subscriptions = Set<AnyCancellable>()
    private var searchIndex: Emoji.SearchIndex?

    // MARK: - Lifecycle
    
    init() {
        prepareSearchIndex()
        
        $searchText
            .sink(receiveValue: { [weak self] text in
                guard !text.isEmpty else {
                    self?.searchResults = []
                    return
                }
                self?.isSearching = true
                Task.detached(priority: .high) {
                    self?.search(text: text)
                }
            })
            .store(in: &subscriptions)
    }
    
    // MARK: - Functions
    
    func prepareSearchIndex() {
        Task.detached(priority: .high) {
            self.searchIndex = Emoji.searchIndex
        }
    }
    
    private func search(text: String) {
        
        guard let searchIndex else {
            return
        }
        
        let results = Array(searchIndex.filter { (key: EmojiVariant, descriptions: [String]) in
            descriptions.contains {
                $0.localizedCaseInsensitiveContains(text)
            } || text == key.rawValue
        }.keys).sorted {
            $0.base.sortOrder < $1.base.sortOrder
        }
            
        Task { @MainActor in
            self.searchResults = results
            isSearching = false
        }
    }
}
