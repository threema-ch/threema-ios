//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

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
/// 4. Extend the `AppMigrationTests` with the new migration
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

    // BusinessInjector for main or background thread
    private let businessInjector: BusinessInjectorProtocol

    private var migratedTo: AppMigrationVersion {
        get {
            AppMigrationVersion(rawValue: businessInjector.userSettings.appMigratedToVersion) ?? .none
        }
        set {
            businessInjector.userSettings.appMigratedToVersion = newValue.rawValue
        }
    }

    #if DEBUG
        init(businessInjector: BusinessInjectorProtocol) {
            self.businessInjector = businessInjector
        }
    #endif

    init(reset: Bool = false) {
        self.businessInjector = BusinessInjector(forBackgroundProcess: !Thread.isMainThread)
        super.init()

        if reset {
            businessInjector.userSettings.appMigratedToVersion = AppMigrationVersion.none.rawValue
        }
    }

    @objc override init() {
        self.businessInjector = BusinessInjector(forBackgroundProcess: !Thread.isMainThread)
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

    /// Runs all necessary migrations
    /// Throws an error if and only if a migration has failed and the app is expected to not be usable without it.
    /// Specifically `run` catches all errors but only re-throws a closely defined subset of it
    ///
    /// Errors thrown by `run` are always `NSErrors` i.e. they are directly usable by `ErrorHandler.abortWithError()`
    /// function.
    @objc func run() throws {
        // We do not perform migrations in safe mode
        guard !SettingsBundleHelper.safeMode else {
            DDLogNotice("[AppMigration] safe mode enabled no migrations will be performed")
            return
        }

        // We need to run this check to reset the latest version to the correct value if needed
        guard AppMigrationVersion.isMigrationRequired(userSettings: businessInjector.userSettings) else {
            DDLogNotice("[AppMigration] No migration needed")
            return
        }

        // Do app files migration before files might be used by business services
        let appFilesMigration = AppFilesMigration(migratedTo: migratedTo)
        try appFilesMigration.run()

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
                // This migration can throw errors of kind `SQLDHSessionStore.SQLDHSessionStoreMigrationError` which
                // are rethrown here
                try migrateTo5_3_1()
                migratedTo = .v5_3_1
            }
            if migratedTo < .v5_4 {
                // This migration can throw errors of kind `SQLDHSessionStore.SQLDHSessionStoreMigrationError` which
                // are rethrown here
                try migrateTo5_4()
                migratedTo = .v5_4
            }
            if migratedTo < .v5_5 {
                try migrateTo5_5()
                migratedTo = .v5_5
            }
            if migratedTo < .v5_6 {
                try migrateTo5_6()
                migratedTo = .v5_6
            }
            if migratedTo < .v5_7 {
                try migrateTo5_7()
                migratedTo = .v5_7
            }
            if migratedTo < .v5_9 {
                try migrateTo5_9()
                migratedTo = .v5_9
            }
            if migratedTo < .v5_9_2 {
                try migrateTo5_9_2()
                migratedTo = .v5_9_2
            }
            if migratedTo < .v6_0 {
                try migrateTo6_0()
                migratedTo = .v6_0
            }
            if migratedTo < .v6_2 {
                try migrateTo6_2()
                migratedTo = .v6_2
            }
            if migratedTo < .v6_2_1 {
                // Only a files migration is run
                migratedTo = .v6_2_1
            }
            if migratedTo < .v6_3 {
                // Only a files migration is run
                migratedTo = .v6_3
            }

            // Add here a check if migration is necessary for a particular version...
        }
        catch {
            DDLogError("[AppMigration] (last migrated version \(migratedTo)) failed: \(error)")

            if let error = error as? SQLDHSessionStore.SQLDHSessionStoreMigrationError {
                switch error {
                case let .downgradeFromUnsupportedVersion(innerError),
                     let .unknownError(innerError):
                    throw innerError
                }
            }
        }

        // Validate that we actually upgraded to the most recent version
        guard !AppMigrationVersion.isMigrationRequired(userSettings: businessInjector.userSettings) else {
            // We need to throw a `NSError` with a localized message shown as part of the error body to the user, but we
            // only localize the first sentence such that the rest is easily readable by us.
            let dict = [
                NSLocalizedDescriptionKey: "\(#localize("app_migration_uncompleted")) Expected: \(AppMigrationVersion.allCases.last!.rawValue) Actual: \(businessInjector.userSettings.appMigratedToVersion)",
            ]
            let nsError = NSError(domain: "\(type(of: self))", code: 1, userInfo: dict)
            throw nsError
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
        businessInjector.contactStore.updateAllContacts()

        MessageDraftStore.shared.cleanupDrafts()
        AppGroup.userDefaults().removeObject(forKey: "AlreadyDeletedOldDrafts")

        businessInjector.entityManager.performAndWaitSave {
            for conversation in self.businessInjector.entityManager.entityFetcher.allConversations() {
                guard let conversation = conversation as? ConversationEntity else {
                    continue
                }

                let messageFetcher = MessageFetcher(for: conversation, with: self.businessInjector.entityManager)
                let calendar = Calendar.current

                // Check has conversation unread messages
                guard self.businessInjector.entityManager.entityFetcher.countUnreadMessages(for: conversation) > 0
                else {
                    if conversation.unreadMessageCount != 0 {
                        self.businessInjector.unreadMessages.totalCount(doCalcUnreadMessagesCountOf: [conversation])
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
                if let result = self.businessInjector.entityManager.entityFetcher.execute(batch) {
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

                self.businessInjector.unreadMessages.totalCount(doCalcUnreadMessagesCountOf: [conversation])
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
        businessInjector.entityManager.performAndWaitSave {

            let batch = NSBatchUpdateRequest(entityName: "Conversation")
            batch.resultType = .statusOnlyResultType
            batch
                .predicate =
                NSPredicate(
                    format: "marked == \(NSNumber(booleanLiteral: true))"
                )

            batch.propertiesToUpdate = [
                "marked": NSNumber(booleanLiteral: false),
                "visibility": ConversationEntity.Visibility.pinned.rawValue,
            ]
            // if there was a error, the execute function will return nil or a result with the result 0
            if let result = self.businessInjector.entityManager.entityFetcher.execute(batch) {
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

    /// Migrate to version 5.4:
    /// - Update the FS session data base to include new fields required in protocol version 18
    private func migrateTo5_4() throws {
        DDLogNotice("[AppMigration] App migration to version 5.4 started")
        os_signpost(.begin, log: osPOILog, name: "5.4 migration")

        try BusinessInjector().dhSessionStore.executeNull()

        businessInjector.entityManager.performAndWaitSave {
            // Set for all conversations the last update
            let batch = NSBatchUpdateRequest(entityName: "Conversation")
            batch.resultType = .statusOnlyResultType
            batch
                .predicate =
                NSPredicate(
                    format: "lastUpdate == nil"
                )

            batch.propertiesToUpdate = [
                "lastUpdate": Date(timeIntervalSince1970: 0),
            ]
            // if there was a error, the execute function will return nil or a result with the result 0
            if let result = self.businessInjector.entityManager.entityFetcher.execute(batch) {
                if let success = result.result as? Int,
                   success == 0 {
                    DDLogError(
                        "[AppMigration] Failed to set lastUpdate for empty lastUpdate conversations"
                    )
                }
                else {
                    DDLogNotice(
                        "[AppMigration] Succeeded to set lastUpdate for empty lastUpdate conversations"
                    )
                }
            }
            else {
                DDLogError(
                    "[AppMigration] Failed to set lastUpdate for empty lastUpdate conversations"
                )
            }
        }

        os_signpost(.end, log: osPOILog, name: "5.4 migration")
        DDLogNotice("[AppMigration] App migration to version 5.4 successfully finished")
    }

    /// Migrate to version 5.5:
    /// - Remove own contact from contact list if exists
    private func migrateTo5_5() throws {
        DDLogNotice("[AppMigration] App migration to version 5.5 started")
        os_signpost(.begin, log: osPOILog, name: "5.5 migration")

        businessInjector.entityManager.performAndWaitSave {
            if self.businessInjector.entityManager.entityDestroyer.deleteOwnContact() {
                DDLogNotice("[AppMigration] Removed own contact from contact list")
            }
        }

        os_signpost(.end, log: osPOILog, name: "5.5 migration")
        DDLogNotice("[AppMigration] App migration to version 5.5 successfully finished")
    }

    /// Migrate to version 5.6:
    /// - Remove own contact from block list
    private func migrateTo5_6() throws {
        DDLogNotice("[AppMigration] App migration to version 5.6 started")
        os_signpost(.begin, log: osPOILog, name: "5.6 migration")

        if let blockList = businessInjector.userSettings.blacklist,
           let myIdentity = businessInjector.myIdentityStore.identity,
           blockList.contains(myIdentity) {
            let mutableBlocklist = NSMutableOrderedSet(orderedSet: blockList)
            mutableBlocklist.remove(myIdentity)
            businessInjector.userSettings.blacklist = mutableBlocklist
            DDLogNotice("[AppMigration] Removed own contact from block list")
        }

        os_signpost(.end, log: osPOILog, name: "5.6 migration")
        DDLogNotice("[AppMigration] App migration to version 5.6 successfully finished")
    }

    /// Migrate to version 5.7:
    /// - Migrate push settings dictionary to new type struct `PushSetting`
    private func migrateTo5_7() throws {
        DDLogNotice("[AppMigration] App migration to version 5.7 started")
        os_signpost(.begin, log: osPOILog, name: "5.7 migration")

        var newPushSettings = [PushSetting]()

        let applyPushSetting: (NSDictionary, PushSetting) -> PushSetting = { dic, pushSetting -> PushSetting in
            var pushSettingChanged = pushSetting

            if let value = dic["type"] as? Int,
               let type = PushSetting.PushSettingType(rawValue: value) {
                pushSettingChanged.type = type
            }

            if let value = dic["periodOffTillDate"] as? Date {
                pushSettingChanged.periodOffTillDate = value
            }

            if let value = dic["silent"] as? Bool {
                pushSettingChanged.muted = value
            }

            if let value = dic["mentions"] as? Bool {
                pushSettingChanged.mentioned = value
            }

            return pushSettingChanged
        }

        // Migrate `UserSettings.noPushIdentities` and `UserSettings.pushSettingsList`
        let noPushIdentities = AppGroup.userDefaults().array(forKey: "NoPushIdentities") as? [String]
        var pushSettingList = AppGroup.userDefaults().array(forKey: "PushSettingsList") ?? [Any]()

        let pushSettingListIdentities = pushSettingList.compactMap { item in
            if let dic = item as? NSDictionary,
               let identity = dic["identity"] as? String {
                return identity
            }
            return nil
        }

        noPushIdentities?.filter { item in
            if item.count == 8 {
                !(
                    pushSettingListIdentities.filter { $0.count == 8 }
                        .compactMap { $0.uppercased() }
                        .contains(item.uppercased())
                )
            }
            else if let item = BytesUtility.toBytes(hexString: item) {
                !(
                    pushSettingListIdentities.filter { $0.count > 8 }
                        .compactMap { BytesUtility.toBytes(hexString: $0) }
                        .contains(item)
                )
            }
            else {
                false
            }
        }.forEach { identity in
            let dic = ["identity": identity, "type": 1] // `PushSettingType.off`
            pushSettingList.append(dic)
        }

        if !pushSettingList.isEmpty {
            for item in pushSettingList {
                if let dic = item as? NSDictionary,
                   let identity = dic["identity"] as? String {

                    businessInjector.entityManager.performAndWait {
                        // The 'old' push setting identity, could be a Threema ID or a Group ID
                        var contactEntity: ContactEntity?
                        if identity.count == 8 {
                            contactEntity = self.businessInjector.entityManager.entityFetcher.contact(for: identity)
                        }

                        // Looking for contact or group for given push setting identity,
                        // if contact or group not found then push setting will discarded
                        if let contactEntity {
                            let pushSetting = applyPushSetting(
                                dic,
                                self.businessInjector.pushSettingManager.find(forContact: contactEntity.threemaIdentity)
                            )
                            newPushSettings.removeAll { item in
                                item.identity == pushSetting.identity
                            }
                            newPushSettings.append(pushSetting)
                        }
                        else if let myIdentity = self.businessInjector.myIdentityStore.identity,
                                let bytesGroupID = BytesUtility.toBytes(hexString: identity) {
                            let groupID = Data(bytesGroupID)
                            self.businessInjector.entityManager.performAndWait {
                                if let groupEntities = self.businessInjector.entityManager.entityFetcher
                                    .groupEntities(for: groupID) {
                                    for groupEntity in groupEntities {
                                        if let group = self.businessInjector.groupManager.getGroup(
                                            // swiftformat:disable:next acronyms
                                            groupEntity.groupId,
                                            creator: groupEntity.groupCreator ?? myIdentity
                                        ) {

                                            let pushSetting = applyPushSetting(
                                                dic,
                                                self.businessInjector.pushSettingManager
                                                    .find(forGroup: group.groupIdentity)
                                            )
                                            newPushSettings.removeAll { item in
                                                item.groupIdentity == pushSetting.groupIdentity
                                            }
                                            newPushSettings.append(pushSetting)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            let jsonEncoder = JSONEncoder()
            let newPushSettingsEncoded = try newPushSettings.map { item in
                try jsonEncoder.encode(item)
            }

            businessInjector.userSettings.pushSettings = newPushSettingsEncoded
        }

        AppGroup.userDefaults().removeObject(forKey: "NoPushIdentities")
        AppGroup.userDefaults().removeObject(forKey: "PushSettingsList")

        // Old migration task, generate push setting for all groups, is not necessary anymore.
        // Delete corresponding user setting
        AppGroup.userDefaults().removeObject(forKey: "PushGroupGenerated")

        os_signpost(.end, log: osPOILog, name: "5.7 migration")
        DDLogNotice("[AppMigration] App migration to version 5.7 successfully finished")
    }

    /// Migrate to version 5.9:
    /// - Migrate captions from json into the core data caption field
    /// - Update the FS session data base to database version 5
    /// - Remove unknown group alert list for pending group messages
    private func migrateTo5_9() throws {
        DDLogNotice("[AppMigration] App migration to version 5.9 started")
        os_signpost(.begin, log: osPOILog, name: "5.9 migration")

        businessInjector.entityManager.performAndWaitSave {
            if let allFileMessages =
                self.businessInjector.entityManager.entityFetcher
                    .allFileMessagesWithJsonCaptionButEmptyCaption() as?
                    [FileMessageEntity] {
                for fileMessage in allFileMessages {
                    fileMessage.caption = fileMessage.jsonCaption
                }
            }
        }

        // Remove deprecated user settings
        AppGroup.userDefaults().removeObject(forKey: "VideoCallInChatInfoShown")
        AppGroup.userDefaults().removeObject(forKey: "VideoCallInfoShown")
        AppGroup.userDefaults().removeObject(forKey: "VideoCallSpeakerInfoShown")

        // Upgrade FS session data base to database version 5
        try BusinessInjector().dhSessionStore.executeNull()

        // Remove unknown group alert list for pending group messages
        AppGroup.userDefaults().removeObject(forKey: "UnknownGroupAlertList")

        os_signpost(.end, log: osPOILog, name: "5.9 migration")
        DDLogNotice("[AppMigration] App migration to version 5.9 successfully finished")
    }

    /// Migrate to version 5.9.2:
    /// - Migrate from `PendingCreateID` to full `AppSetupState`
    private func migrateTo5_9_2() throws {
        DDLogNotice("[AppMigration] App migration to version 5.9.2 started")
        os_signpost(.begin, log: osPOILog, name: "5.9.2 migration")

        // Migrate from "PendingCreateID" to a full app setup state:
        // If "PendingCreateID" is set the identity was created, but setup not completed
        if AppGroup.userDefaults().bool(forKey: "PendingCreateID") {
            AppSetup.state = .identityAdded
        }
        // If the identity is invalid or the app was deleted before we need to restart the setup
        else if !AppSetup.hasPreexistingDatabaseFile || !MyIdentityStore.shared().isValidIdentity {
            AppSetup.state = .notSetup
        }
        // By default the setup should be completed
        else {
            AppSetup.state = .complete
        }

        // Remove "PendingCreateID"
        AppGroup.userDefaults().removeObject(forKey: "PendingCreateID")

        os_signpost(.end, log: osPOILog, name: "5.9.2 migration")
        DDLogNotice("[AppMigration] App migration to version 5.9.2 successfully finished")
    }

    /// Migrate to version 6.0:
    /// - Set FileAudioMessages consumed date (1970) for existing messages
    private func migrateTo6_0() throws {
        DDLogNotice("[AppMigration] App migration to version 6.0 started")
        os_signpost(.begin, log: osPOILog, name: "6.0 migration")

        // Remember to setup of Threema Safe when downgrade Threema (only necessary if Threema Safe activated)
        let safeConfigManager = SafeConfigManager(myIdentityStore: businessInjector.myIdentityStore)
        if safeConfigManager.getKey() != nil {
            businessInjector.userSettings.safeIntroShown = false
        }

        // Consumed date is new 1970 for all existing voice messages
        businessInjector.entityManager.performAndWaitSave {
            let batch = NSBatchUpdateRequest(entityName: "FileMessage")
            batch.resultType = .statusOnlyResultType
            batch
                .predicate =
                NSPredicate(
                    format: "isOwn == false AND type == 1 AND mimeType IN %@", UTIConverter.renderingAudioMimetypes()
                )

            batch.propertiesToUpdate = ["consumed": Date(timeIntervalSince1970: 0)]
            // If there was an error, the execute function will return nil or a result with the result 0
            if let result = self.businessInjector.entityManager.entityFetcher.execute(batch) {
                if let success = result.result as? Int,
                   success == 0 {
                    DDLogError(
                        "[AppMigration] Failed to set consumed date for existing voice messages"
                    )
                }
            }
            else {
                DDLogError(
                    "[AppMigration] Failed to set consumed date for existing voice messages"
                )
            }
        }

        os_signpost(.end, log: osPOILog, name: "6.0 migration")
        DDLogNotice("[AppMigration] App migration to version 6.0 successfully finished")
    }

    /// Migrate to version 6.2:
    /// - Remove lastWorkUpdateRequest in IdentityStore
    private func migrateTo6_2() throws {
        DDLogNotice("[AppMigration] App migration to version 6.2 started")
        os_signpost(.begin, log: osPOILog, name: "6.2 migration")

        /// - Remove lastWorkUpdateRequest in IdentityStore
        AppGroup.userDefaults().removeObject(forKey: "LastWorkUpdateRequest")
        AppGroup.userDefaults().synchronize()

        os_signpost(.end, log: osPOILog, name: "6.2 migration")
        DDLogNotice("[AppMigration] App migration to version 6.2 successfully finished")
    }
}
