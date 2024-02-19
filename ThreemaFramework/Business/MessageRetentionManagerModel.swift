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
  
    @Published public var selection: Int = MessageRetentionManagerModel.defaultValue
    
    private weak var backgroundEntityManager: EntityManager?
    private weak var userSettings: UserSettingsProtocol?
    private weak var backgroundGroupManager: GroupManagerProtocol?
    
    private static let defaultValue = -1
    
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
            if let userSettings {
                return checkDays(userSettings.keepMessagesDays)
            }
            
            return MessageRetentionManagerModel.defaultValue
        }
        
        return checkDays(keepMessagesDays)
    }
    
    init(
        backgroundEntityManager: EntityManager,
        userSettings: UserSettingsProtocol,
        backgroundGroupManager: GroupManagerProtocol
    ) {
        self.backgroundEntityManager = backgroundEntityManager
        self.userSettings = userSettings
        self.backgroundGroupManager = backgroundGroupManager
        self.selection = keepMessagesDays
    }
    
    convenience init() {
        self.init(businessInjector: BusinessInjector())
    }
  
    convenience init(businessInjector: BusinessInjectorProtocol) {
        self.init(
            backgroundEntityManager: businessInjector.backgroundEntityManager,
            userSettings: businessInjector.userSettings,
            backgroundGroupManager: businessInjector.backgroundGroupManager
        )
    }
    
    /// Deletes all messages according to the current setting. MDMs or userSetttings `keepMessagesDays` are used to
    /// calculate the date after which messages should be deleted.
    public func deleteOldMessages() async {
        guard keepMessagesDays > 0, let deletionDate = deletionDate(keepMessagesDays),
              let backgroundEntityManager else {
            return
        }
        await backgroundEntityManager.entityDestroyer.deleteMessagesForMessageRetention(
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
        guard let retentionDays, retentionDays > 0, let deletionDate = deletionDate(retentionDays),
              let backgroundEntityManager else {
            return 0
        }
        
        return await backgroundEntityManager.entityDestroyer.messagesToBeDeleted(
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
        guard selection != days, keepMessagesDays != days, !isMDM, let userSettings else {
            return
        }
        
        selection = days
        userSettings.keepMessagesDays = days
            
        // Trigger Deletion
        Task {
            await self.deleteOldMessages()
            completion?()
        }
    }
    
    /// Computes the Conversations to be affected by the deletion
    private func conversations() -> [Conversation] {
        guard let backgroundEntityManager, let backgroundGroupManager else {
            return []
        }
        let convs = (backgroundEntityManager.entityFetcher.allConversations() as? [Conversation]) ?? []
        return convs.filter {
            // note groups are excluded
            return !(backgroundGroupManager.getGroup(conversation: $0)?.isNoteGroup ?? false)
        }
    }
    
    private func computeUnread() {
        guard let backgroundEntityManager else {
            return
        }
        
        let unreadMessages = UnreadMessages(entityManager: backgroundEntityManager)
        
        if let conversations = backgroundEntityManager.entityFetcher
            .notArchivedConversations() as? [Conversation] {
            unreadMessages.totalCount(doCalcUnreadMessagesCountOf: Set(conversations))
        }
    }
}
