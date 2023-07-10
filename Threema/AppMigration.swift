//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import OSLog
import ThreemaFramework

/// Migrate app to a new version
///
/// How to add a new migration:
///
/// 1. Add a new `AppMigrationVersion`. See its documentation for details
/// 2. Add a new migrate function (`migrateToX_Y`)
///     - Document the function and describe what is migrated
///     - Check if the migration is as fast as possible and reduces resource usage (e.g. memory): E.g. for Core Data
///       operations use batch (`NSBatch...`) and try to load the least amount of Core Data-Objects possible.
/// 3. Call the migration in `run()`
///
/// ```swift
/// ...
/// @objc func run() {
///     do {
///         if migratedTo < .v4_8 {
///             try migrateTo4_8()
///             migratedTo = .v4_8
///         }
///         if migratedTo < .v4_9 {
///             try migratedTo4_9()
///             migratedTo = .v4_9
///         }
/// ...
///
/// /// Migrate to version 4.9:
/// /// Describe migration steps here!
/// private func migrateTo4_9() throws {
///     DDLogNotice("[AppMigration] App migration to version 4.9 started")
///     os_signpost(.begin, log: osPOILog, name: "4.9 migration")
///     ...
///     os_signpost(.end, log: osPOILog, name: "4.9 migration")
///     DDLogNotice("[AppMigration] App migration to version 4.9 successfully finished")
/// }
/// ```
@objc class AppMigration: NSObject {

    private let osPOILog = OSLog(subsystem: "ch.threema.iapp.appMigration", category: .pointsOfInterest)
    
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

        if reset {
            businessInjector.userSettings.appMigratedToVersion = AppMigrationVersion.none.rawValue
        }
    }

    @objc convenience init(businessInjectorObjc: NSObject) {
        self.init(businessInjector: businessInjectorObjc as! BusinessInjectorProtocol)
    }
    
    @available(
        *,
        deprecated,
        message: "Only use from Objective-C. Use `AppMigrationVersion.isMigrationRequired(userSettings:)` otherwise",
        renamed: "AppMigrationVersion.isMigrationRequired(userSettings:)"
    )
    @objc static func isMigrationRequired(userSettings: UserSettingsProtocol) -> Bool {
        AppMigrationVersion.isMigrationRequired(userSettings: userSettings)
    }
    
    @objc static func migrateSQLDHSessionStoreIfRequired() {
        do {
            try SQLDHSessionStore().executeNull()
        }
        catch {
            DDLogError("An error occurred when attempting to migrate SQLDHSessionStore \(error)")
        }
    }

    /// Runs all necessary migrations
    @objc func run() {
        // We need to run this check to reset the latest version to the correct value if needed
        guard AppMigrationVersion.isMigrationRequired(userSettings: businessInjector.userSettings) else {
            DDLogNotice("[AppMigration] No migration needed")
            return
        }
        
        do {
            if migratedTo < .v4_8 {
                try migrateTo4_8()
                migratedTo = .v4_8
            }
            if migratedTo < .v5_1 {
                try migrateTo5_1()
                migratedTo = .v5_1
            }
            if migratedTo < .v5_2 {
                try migrateTo5_2()
                migratedTo = .v5_2
            }
            if migratedTo < .v5_3_1 {
                try migrateTo5_3_1()
                migratedTo = .v5_3_1
            }
            // Add here a check if migration is necessary for a particular version...
        }
        catch {
            DDLogError("[AppMigration] (last migrated version \(migratedTo)) failed: \(error)")
        }
    }
    
    // Add here migration function for particular version...

    /// Migrate to version 4.8:
    /// - Check protection on my identity store
    /// - Update all contacts to CNContact
    /// - Update all work contacts the verfication level `kVerificationLevelWorkVerified` and
    ///   `kVerificationLevelWorkFullyVerified` to flag `workContact`
    /// - Cleanup draft of all conversations
    /// - Add push settings for all group conversations
    /// - Mark all messages after latest readed message as read
    private func migrateTo4_8() throws {
        DDLogNotice("[AppMigration] App migration to version 4.8 started")
        os_signpost(.begin, log: osPOILog, name: "4.8 migration")

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
        
        os_signpost(.end, log: osPOILog, name: "4.8 migration")
        DDLogNotice("[AppMigration] App migration to version 4.8 successfully finished")
    }
    
    /// Migrate to version 5.1:
    /// - Check pushShowNickname and set the correct notification type
    private func migrateTo5_1() throws {
        DDLogNotice("[AppMigration] App migration to version 5.1 started")
        os_signpost(.begin, log: osPOILog, name: "5.1 migration")

        let pushShowNickname = AppGroup.userDefaults().bool(forKey: "PushShowNickname")
        
        if pushShowNickname == true {
            UserSettings.shared().notificationType = NSNumber(0)
        }
        
        os_signpost(.end, log: osPOILog, name: "5.1 migration")
        DDLogNotice("[AppMigration] App migration to version 5.1 successfully finished")
    }
    
    /// Migrate to version 5.2:
    /// - Replace the conversation.marked property with the conversation.visibility property
    private func migrateTo5_2() throws {
        DDLogNotice("[AppMigration] App migration to version 5.2 started")
        os_signpost(.begin, log: osPOILog, name: "5.2 migration")
        entityManager.performSyncBlockAndSafe {
            
            let batch = NSBatchUpdateRequest(entityName: "Conversation")
            batch.resultType = .statusOnlyResultType
            batch
                .predicate =
                NSPredicate(
                    format: "marked == \(NSNumber(booleanLiteral: true))"
                )
            
            batch.propertiesToUpdate = [
                "marked": NSNumber(booleanLiteral: false),
                "visibility": ConversationVisibility.pinned.rawValue,
            ]
            // if there was a error, the execute function will return nil or a result with the result 0
            if let result = self.entityManager.entityFetcher.execute(batch) {
                if let success = result.result as? Int,
                   success == 0 {
                    DDLogError(
                        "[AppMigration] Failed to set visibility for conversations"
                    )
                }
            }
            else {
                DDLogError(
                    "[AppMigration] Failed to set visibility for conversations"
                )
            }
        }
        os_signpost(.end, log: osPOILog, name: "5.2 migration")
        DDLogNotice("[AppMigration] App migration to version 5.2 successfully finished")
    }
    
    /// Migrate to version 5.3.1:
    /// - Update the FS session data base to database version 1
    /// This only changes the userVersion field or allows downgrading from version 5.4
    private func migrateTo5_3_1() throws {
        DDLogNotice("[AppMigration] App migration to version 5.3.1 started")
        os_signpost(.begin, log: osPOILog, name: "5.3.1 migration")
        
        try BusinessInjector().dhSessionStore.executeNull()
        
        os_signpost(.end, log: osPOILog, name: "5.3.1 migration")
        DDLogNotice("[AppMigration] App migration to version 5.3.1 successfully finished")
    }
}
