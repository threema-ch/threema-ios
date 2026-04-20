import Combine
import SwiftUI

final class EmojiSearchViewModel: ObservableObject {
    
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
