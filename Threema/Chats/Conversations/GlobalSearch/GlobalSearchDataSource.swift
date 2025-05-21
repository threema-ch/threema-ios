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
import ThreemaMacros

// MARK: - Types

enum GlobalSearch {
    enum Section: Hashable {
        case tokens
        case conversation
        case message
        
        var localizedTitle: String? {
            switch self {
            case .tokens:
                nil
            case .conversation:
                #localize("chats_title")
            case .message:
                #localize("messages")
            }
        }
    }
    
    enum Row: Hashable {
        case messageToken(GlobalSearchMessageToken)
        case conversation(NSManagedObjectID)
        case message(NSManagedObjectID)
    }
}

class GlobalSearchDataSource: UITableViewDiffableDataSource<GlobalSearch.Section, GlobalSearch.Row> {
    
    // MARK: - Properties
    
    private weak var tableView: UITableView?
    private weak var entityFetcher: EntityFetcher?
    
    /// The default interval the source fetches messages in, 1d
    private let dateInterval = TimeInterval(-86400)
    private let dateIntervalBaseCoefficient = 2.0
    private var dateIntervalCoefficient: Double
    private var dateIntervalExponent = 5.0

    private let oldestMessageDate: Date
    private var currentDateCutoff = Date.now
    
    private var currentTokens = [GlobalSearchMessageToken]()
    private var currentSearchText = ""
    private var currentSearchScope = GlobalSearchConversationScope.all
    
    // MARK: - Lifecycle
    
    init(tableview: UITableView, entityManager: EntityManager) {
        
        self.tableView = tableview
        
        self.entityFetcher = entityManager.entityFetcher
        self.oldestMessageDate = entityFetcher!.dateOfOldestMessage()
        self.dateIntervalCoefficient = dateIntervalBaseCoefficient
        
        // This is needed to not have a circular reference
        super.init(tableView: tableview) { tableView, indexPath, row in
            
            switch row {
                
            case let .messageToken(token):
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: SearchContentConfigurations.contentConfigurationTokenCellIdentifier,
                    for: indexPath
                )
                
                cell.contentConfiguration = SearchContentConfigurations.contentConfiguration(for: token)
                
                // For these tokens it looks better if there is no inset for the icons
                // (as in Mail.app & Photos.app in iOS 17)
                cell.separatorInset = .zero
                
                // Fix appearance for dark mode
                cell.backgroundColor = .clear
                
                return cell
                
            case let .conversation(id):
                var conversation: ConversationEntity?
                entityManager.performAndWait {
                    conversation = entityManager.entityFetcher.existingObject(with: id) as? ConversationEntity
                }
                
                guard let conversation else {
                    return nil
                }
                
                let conversationCell: ConversationTableViewCell = tableView.dequeueCell(for: indexPath)
                conversationCell.setConversation(to: conversation)
                return conversationCell
                
            case let .message(id):
                var message: BaseMessageEntity?
                entityManager.performAndWait {
                    message = entityManager.entityFetcher.existingObject(with: id) as? BaseMessageEntity
                }
                
                guard let message else {
                    return nil
                }
                
                let messageCell: GlobalSearchResultsTableViewCell = tableView.dequeueCell(for: indexPath)
                messageCell.message = message
                return messageCell
            }
        }
        
        registerCells()
        
        defaultRowAnimation = .fade
        
        // First search
        Task {
            await updateSearchResults(for: currentSearchText, with: currentTokens, in: currentSearchScope)
        }
    }
    
    private func registerCells() {
        // We register here the header used in `GlobalSearchResultsViewController`. If we extend this we might move this
        // logic over there
        tableView?.register(
            UITableViewHeaderFooterView.self,
            forHeaderFooterViewReuseIdentifier: SearchContentConfigurations
                .contentConfigurationSectionHeaderIdentifier
        )
        
        tableView?.register(
            UITableViewCell.self,
            forCellReuseIdentifier: SearchContentConfigurations.contentConfigurationTokenCellIdentifier
        )
        tableView?.registerCell(GlobalSearchResultsTableViewCell.self)
        tableView?.registerCell(ConversationTableViewCell.self)
    }
    
    public func updateSearchResults(
        for text: String,
        with tokens: [GlobalSearchMessageToken],
        in scope: GlobalSearchConversationScope
    ) async {
        // Reset cutoff date and coefficient
        currentDateCutoff = .now
        dateIntervalCoefficient = dateIntervalBaseCoefficient
        
        // Update current values
        currentTokens = tokens
        currentSearchText = text
        currentSearchScope = scope
        
        // Create fresh snapshot
        var snapshot = NSDiffableDataSourceSnapshot<GlobalSearch.Section, GlobalSearch.Row>()
        
        // Resolve section contents
        loadTokens(snapshot: &snapshot)
        
        // We only show the conversations if no tokens are selected
        if tokens.isEmpty, !currentSearchText.isEmpty {
            loadConversations(snapshot: &snapshot)
        }
        
        // We load messages if there is a search text or a token
        if !currentSearchText.isEmpty || !tokens.isEmpty {
            loadMessages(snapshot: &snapshot)
        }
        // Finally, apply the updates
        Task { @MainActor in
            apply(snapshot)
        }
    }
    
    // MARK: - Fetching
    
    private func loadTokens(snapshot: inout NSDiffableDataSourceSnapshot<
        GlobalSearch.Section,
        GlobalSearch.Row
    >) {
        
        // We only show tokens not yet selected
        let nonSelectedTokens = GlobalSearchMessageToken.allCases.filter {
            !currentTokens.contains($0)
        }
        
        let filtered: [GlobalSearchMessageToken] =
            // If no search text is provided we show all remaining
            if currentSearchText.isEmpty {
                nonSelectedTokens
            }
            // Otherwise we show only the ones containing the search text in title
            else {
                nonSelectedTokens.filter {
                    $0.title.localizedCaseInsensitiveContains(currentSearchText)
                }
            }
        
        // We do not show the section if we have no filtered tokens
        guard !filtered.isEmpty else {
            return
        }
        
        if !snapshot.sectionIdentifiers.contains(.tokens) {
            snapshot.appendSections([.tokens])
        }
        let rows: [GlobalSearch.Row] = filtered.map {
            GlobalSearch.Row.messageToken($0)
        }
        snapshot.appendItems(rows, toSection: .tokens)
    }
    
    private func loadConversations(snapshot: inout NSDiffableDataSourceSnapshot<
        GlobalSearch.Section,
        GlobalSearch.Row
    >) {
        guard let entityFetcher else {
            return
        }
        
        let conversations = entityFetcher.matchingConversationsForGlobalSearch(
            containing: currentSearchText,
            scope: currentSearchScope
        )
        
        // We do not show the section if we have no conversations
        guard !conversations.isEmpty else {
            return
        }
        
        let rows: [GlobalSearch.Row] = conversations.map {
            GlobalSearch.Row.conversation($0)
        }
        if !snapshot.sectionIdentifiers.contains(.conversation) {
            snapshot.appendSections([.conversation])
        }
        snapshot.appendItems(rows, toSection: .conversation)
    }
    
    /// Used for loading a new batch of messages, i.e. when the tokens, scope or the search text changes
    private func loadMessages(snapshot: inout NSDiffableDataSourceSnapshot<GlobalSearch.Section, GlobalSearch.Row>) {
        
        guard let entityFetcher else {
            return
        }
        
        // Calculate cut off date in past, when then search from then until `currentDateCutoff`
        let newInterval = dateInterval * dateIntervalCoefficient
        let startDate = currentDateCutoff.addingTimeInterval(newInterval)
        
        let messages = entityFetcher.matchingMessages(
            containing: currentSearchText,
            between: startDate,
            and: currentDateCutoff,
            in: currentSearchScope,
            types: currentTokens
        )
        
        currentDateCutoff = startDate
        
        if !messages.isEmpty {
            let rows: [GlobalSearch.Row] = messages.map {
                GlobalSearch.Row.message($0)
            }
            if !snapshot.sectionIdentifiers.contains(.message) {
                snapshot.appendSections([.message])
            }
            snapshot.appendItems(rows, toSection: .message)
            
            // If we found less than 25 messages, we continue searching
            if snapshot.itemIdentifiers(inSection: .message).count < 25 {
                dateIntervalCoefficient = pow(dateIntervalCoefficient, dateIntervalExponent)
                loadMessages(snapshot: &snapshot)
            }
        }
        // If we did not find any messages, we search again until we find some, or we reached the date of the oldest
        // message
        else if currentDateCutoff > oldestMessageDate {
            dateIntervalCoefficient = pow(dateIntervalCoefficient, dateIntervalExponent)
            loadMessages(snapshot: &snapshot)
        }
    }
    
    /// Used for loading more messages and appending them to the current snapshot, called when scrolling
    public func loadMoreMessages() {
        
        guard !currentTokens.isEmpty || currentSearchText != "" else {
            return
        }
        
        guard currentDateCutoff > oldestMessageDate, let entityFetcher else {
            return
        }
        
        // Calculate cut off date in past, when then search from then until `currentDateCutoff`
        let newInterval = dateInterval * dateIntervalCoefficient
        let startDate = currentDateCutoff.addingTimeInterval(newInterval)
        
        let messages = entityFetcher.matchingMessages(
            containing: currentSearchText,
            between: startDate,
            and: currentDateCutoff,
            in: currentSearchScope,
            types: currentTokens
        )
        
        currentDateCutoff = startDate
        
        if !messages.isEmpty {
            // We get the current snapshot to append the new results
            var snapshot = snapshot()

            let rows: [GlobalSearch.Row] = messages.map {
                GlobalSearch.Row.message($0)
            }
           
            if !snapshot.sectionIdentifiers.contains(.message) {
                snapshot.appendSections([.message])
            }
            snapshot.appendItems(rows, toSection: .message)
            
            if snapshot.itemIdentifiers(inSection: .message).count < 25, currentDateCutoff > oldestMessageDate {
                dateIntervalCoefficient = pow(dateIntervalCoefficient, dateIntervalExponent)
                loadMoreMessages()
            }
            else {
                Task { @MainActor in
                    apply(snapshot)
                }
            }
        }
        // If we did not find any messages, we search again until we find some, or we reached the date of the oldest
        // message
        else if currentDateCutoff > oldestMessageDate {
            
            dateIntervalCoefficient = pow(dateIntervalCoefficient, dateIntervalExponent)
            loadMoreMessages()
        }
    }
}
