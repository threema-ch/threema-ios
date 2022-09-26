//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

@objc class AppMigration: NSObject {

    private let businessInjector: BusinessInjectorProtocol

    // Entity manager for main or background thread
    private var entityManager: EntityManager {
        Thread.isMainThread ? businessInjector.entityManager : businessInjector
            .backgroundEntityManager
    }

    private var migratedTo: AppMigrationVersion {
        get {
            AppMigrationVersion(rawValue: businessInjector.userSettings.appMigratedToVersion) ?? .none
        }
        set {
            businessInjector.userSettings.appMigratedToVersion = newValue.rawValue
        }
    }

    init(businessInjector: BusinessInjectorProtocol, reset: Bool = false) {
        self.businessInjector = businessInjector

        // If `appMigratedToVersion` greater than latest migration version means, that the BETA user has downgraded the app.
        // In this case run all migrations again.
        if reset || businessInjector.userSettings.appMigratedToVersion > AppMigrationVersion.allCases.last!.rawValue {
            businessInjector.userSettings.appMigratedToVersion = AppMigrationVersion.none.rawValue
        }
    }

    @objc convenience init(businessInjectorObjc: NSObject) {
        self.init(businessInjector: businessInjectorObjc as! BusinessInjectorProtocol)
    }
    
    @objc static func isMigrationRequired(userSettings: UserSettingsProtocol) -> Bool {
        AppMigrationVersion.isMigrationRequired(userSettings: userSettings)
    }

    /// Runs all necessary migrations
    @objc func run() {
        do {
            if migratedTo < .v48 {
                try migrateTo48()
                migratedTo = .v48
            }
            // Add here a check is migration necessary for particular version...
        }
        catch {
            DDLogError("[AppMigration] (last migrated version \(migratedTo)) failed: \(error)")
        }
    }
    
    // Add here migration function for particular version...

    /// Migrate to version 4.8:
    /// - Check protection on my identity store
    /// - Update all contacts to CNContact
    /// - Update all work contacts the verfication level `kVerificationLevelWorkVerified` and `kVerificationLevelWorkFullyVerified` to flag `workContact`
    /// - Cleanup draft of all conversations
    /// - Add push settings for all group conversations
    /// - Mark all messages after latest readed message as read
    private func migrateTo48() throws {
        DDLogNotice("[AppMigration] App migration to version 4.8 started")

        if DatabaseManager.db().shouldUpdateProtection() {
            businessInjector.myIdentityStore.updateConnectionRights()
            DatabaseManager.db().updateProtection()
        }

        businessInjector.contactStore.updateAllContactsToCNContact()
        AppGroup.userDefaults().removeObject(forKey: "AlreadyUpdatedToCNContacts")

        businessInjector.contactStore.updateAllContacts()

        MessageDraftStore.cleanupDrafts()
        AppGroup.userDefaults().removeObject(forKey: "AlreadyDeletedOldDrafts")

        NotificationManager.generatePushSettingForAllGroups()

        entityManager.performSyncBlockAndSafe {
            let unreadMessages = UnreadMessages(entityManager: self.entityManager)

            for conversation in self.entityManager.entityFetcher.allConversations() {
                guard let conversation = conversation as? Conversation else {
                    continue
                }
                    
                let messageFetcher = MessageFetcher(for: conversation, with: self.entityManager)
                let calendar = Calendar.current
                
                // Check has conversation unread messages
                guard self.entityManager.entityFetcher.countUnreadMessages(for: conversation) > 0 else {
                    if conversation.unreadMessageCount != 0 {
                        unreadMessages.totalCount(doCalcUnreadMessagesCountOf: [conversation])
                    }
                    continue
                }
                
                // Get remote date from latest readed message or max 2 week old
                var firstRemoteSentDate: Date? = calendar.date(byAdding: .day, value: -14, to: Date())
                
                for msg in messageFetcher.messages(at: 0, count: messageFetcher.count()).reversed() {
                    if !msg.isOwnMessage,
                       msg.read?.boolValue ?? false,
                       let remoteSendDate = msg.remoteSentDate {
                        if firstRemoteSentDate == nil {
                            firstRemoteSentDate = remoteSendDate
                        }
                        else if remoteSendDate > firstRemoteSentDate! {
                            firstRemoteSentDate = remoteSendDate
                        }
                        break
                    }
                }
                
                let batch = NSBatchUpdateRequest(entityName: "Message")
                batch.resultType = .statusOnlyResultType
                batch
                    .predicate =
                    NSPredicate(
                        format: "conversation == %@ && isOwn == false && remoteSentDate < %@", conversation,
                        firstRemoteSentDate! as NSDate
                    )
                
                batch.propertiesToUpdate = ["readDate": Date(), "read": true]
                // if there was a error, the execute function will return nil or a result with the result 0
                if let result = self.entityManager.entityFetcher.execute(batch) {
                    if let success = result.result as? Int,
                       success == 0 {
                        DDLogError(
                            "[AppMigration] Failed to set messages as read for conversation \(conversation.objectID)"
                        )
                    }
                }
                else {
                    DDLogError(
                        "[AppMigration] Failed to set messages as read for conversation \(conversation.objectID)"
                    )
                }
                
                unreadMessages.totalCount(doCalcUnreadMessagesCountOf: [conversation])
            }
        }
        
        // See IOS-2811 for more information
        AppGroup.userDefaults().set(false, forKey: "PushReminderDoNotShowAgain")
        
        DDLogNotice("[AppMigration] App migration to version 4.8 successfully finished")
    }
}
