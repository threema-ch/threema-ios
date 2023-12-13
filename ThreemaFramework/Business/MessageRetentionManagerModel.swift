//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

/// Handles the logic of message retention
///  - Delete old messages based on user settings or mdm values (MDM overwrites user settings)
///  - Filter affected conversations based on Policy (currently only to filter out Note Groups)
public final class MessageRetentionManagerModel: MessageRetentionManagerModelProtocol & ObservableObject {
  
    @Published public var selection: Int = -1
        
    private let businessInjector: BusinessInjectorProtocol
    private let mdm = MDMSetup(setup: false)
    
    public var isMDM: Bool {
        (mdm?.keepMessagesDays() as? Int) != nil
    }
    
    private var keepMessagesDays: Int {
        // Custom days are only valid between 7 and 3650, values <= 0 should be excluded
        let checkDays: (Int) -> Int = { days in
            switch days {
            case 1..<7:
                return 7
            case 3650...:
                return 3650
            default:
                return days
            }
        }
        
        guard let keepMessagesDays = mdm?.keepMessagesDays() as? Int else {
            // Take UserSettings if the MDM values are not set
            return checkDays(businessInjector.userSettings.keepMessagesDays)
        }
        
        return checkDays(keepMessagesDays)
    }
    
    convenience init() {
        self.init(businessInjector: BusinessInjector())
    }
  
    init(businessInjector: BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
        self.selection = keepMessagesDays
    }
    
    /// Deletes all messages according to the current setting. MDMs or userSetttings `keepMessagesDays` are used to
    /// calculate the date after which messages should be deleted.
    public func deleteOldMessages() async {
        guard keepMessagesDays > 0, let deletionDate = deletionDate(keepMessagesDays) else {
            return
        }
        await businessInjector.backgroundEntityManager.entityDestroyer.deleteMessagesForMessageRetention(
            olderThan: deletionDate,
            for: conversations().map(\.objectID)
        )
        
        // recompute Unread
        computeUnread()
    }
    
    /// Just fetch the count of messages to be deleted to be consumed by the UI.
    /// - Parameter days: the amount of days from now affected messages. `days` must be higher than `0` as `-1` accounts
    /// for `never`
    /// - Returns: number of messages to be deleted
    public func numberOfMessagesToDelete(for retentionDays: Int?) async -> Int {
        guard let retentionDays, retentionDays > 0, let deletionDate = deletionDate(retentionDays) else {
            return 0
        }
        
        return await businessInjector.backgroundEntityManager.entityDestroyer.messagesToBeDeleted(
            olderThan: deletionDate,
            for: conversations().map(\.objectID)
        )
    }
    
    /// Update the current timeframe for  keeping Messages to the amount of `days` provided
    ///
    /// After setting the new value, we will trigger the deletion of old messages according to the new setting
    /// This function does nothing if this MDM setting is turned on
    ///
    /// - Parameter days: how many days in the past we will delete
    public func set(_ days: Int, completion: (() -> Void)? = nil) {
        guard selection != days, keepMessagesDays != days, !isMDM else {
            return
        }
        
        selection = days
        businessInjector.userSettings.keepMessagesDays = days
            
        // Trigger Deletion
        Task {
            await self.deleteOldMessages()
            completion?()
        }
    }
    
    /// Computes the Conversations to be affected by the deletion
    private func conversations() -> [Conversation] {
        let convs = (businessInjector.backgroundEntityManager.entityFetcher.allConversations() as? [Conversation]) ?? []
        return convs.filter {
            // note groups are excluded
            return !(businessInjector.backgroundGroupManager.getGroup(conversation: $0)?.isNoteGroup ?? false)
        }
    }
    
    private func computeUnread() {
        let unreadMessages = UnreadMessages(entityManager: businessInjector.backgroundEntityManager)
        
        if let conversations = businessInjector.backgroundEntityManager.entityFetcher
            .notArchivedConversations() as? [Conversation] {
            unreadMessages.totalCount(doCalcUnreadMessagesCountOf: Set(conversations))
        }
    }
}
