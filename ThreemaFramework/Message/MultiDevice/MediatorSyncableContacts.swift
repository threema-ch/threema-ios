//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import PromiseKit
import ThreemaProtocols

enum DeltaUpdateType: Int, Codable {
    case unchanged
    case removed
    case updated
}

class MediatorSyncableContacts: NSObject {
    @objc static let deltaUpdateTypeUnchanged = DeltaUpdateType.unchanged.rawValue
    @objc static let deltaUpdateTypeRemoved = DeltaUpdateType.removed.rawValue
    @objc static let deltaUpdateTypeUpdated = DeltaUpdateType.updated.rawValue

    private let chunkSize = 100
    private var deltaSyncContacts = [DeltaSyncContact]()

    private let userSettings: UserSettingsProtocol
    private let pushSettingManager: PushSettingManagerProtocol
    private var taskManager: TaskManagerProtocol
    private let entityManager: EntityManager
    
    init(
        _ userSettings: UserSettingsProtocol,
        _ pushSettingManager: PushSettingManagerProtocol,
        _ taskManager: TaskManagerProtocol,
        _ entityManager: EntityManager
    ) {
        self.userSettings = userSettings
        self.pushSettingManager = pushSettingManager
        self.taskManager = taskManager
        self.entityManager = entityManager
    }
    
    @objc override convenience init() {
        self.init(
            UserSettings.shared(),
            PushSettingManager(),
            TaskManager(),
            EntityManager(withChildContextForBackgroundProcess: true)
        )
    }
    
    func getAllDeltaSyncContacts() -> [DeltaSyncContact] {
        var allDeltaContacts = [DeltaSyncContact]()
        
        entityManager.performBlockAndWait {
            guard let allContacts = self.entityManager.entityFetcher.allContacts() else {
                DDLogError("Unable to load all contacts")
                return
            }
            
            for anyContact in allContacts {
                guard let contact = anyContact as? ContactEntity else {
                    continue
                }
                
                var newDeltaSyncContact = DeltaSyncContact()
                self.loadAndUpdateAll(contact, delta: &newDeltaSyncContact, added: true, withoutProfileImage: false)
                
                // Load the pictures if they are available as they need to be directly sent during device join
                
                if newDeltaSyncContact.profilePicture == .updated,
                   let imageData = contact.imageData {
                    newDeltaSyncContact.image = imageData
                }
                
                if newDeltaSyncContact.contactProfilePicture == .updated,
                   let imageData = contact.contactImage?.data {
                    newDeltaSyncContact.contactImage = imageData
                }
                
                allDeltaContacts.append(newDeltaSyncContact)
            }
        }
        
        return allDeltaContacts
    }

    @objc func updateAll(identity: String, added: Bool) {
        updateAll(identity: identity, added: added, withoutProfileImage: false)
    }

    /// Update/Sync all attributes of a contact.
    /// - Parameters:
    ///   - identity: Contact identity to sync
    ///   - added: True contact has added otherwise has updated
    ///   - withoutProfileImage: True profile picture will not be synced
    @objc func updateAll(identity: String, added: Bool, withoutProfileImage: Bool) {
        guard userSettings.enableMultiDevice else {
            return
        }

        entityManager.performBlockAndWait {
            guard let contact = self.entityManager.entityFetcher.contact(for: identity) else {
                return
            }
            
            var delta = self.getDelta(contact.identity)
            
            self.loadAndUpdateAll(contact, delta: &delta, added: added, withoutProfileImage: withoutProfileImage)

            self.apply(delta)
        }
    }
    
    private func loadAndUpdateAll(
        _ contactEntity: ContactEntity,
        delta: inout DeltaSyncContact,
        added: Bool,
        withoutProfileImage: Bool
    ) {
        // Default sync action is update, is once changed to create never will change back to update
        if delta.syncAction == .update, added {
            delta.syncAction = .create
        }

        apply(delta)

        let pushSetting = pushSettingManager.find(forContact: contactEntity.threemaIdentity)

        delta.syncContact.update(contact: contactEntity, pushSetting: pushSetting)

        let workIdentities = userSettings.workIdentities ?? NSOrderedSet(array: [String]())
        delta.syncContact.update(identityType: workIdentities.contains(contactEntity.identity) ? .work : .regular)

        if !withoutProfileImage {
            delta.profilePicture = contactEntity.imageData != nil ? .updated : .removed
            delta.contactProfilePicture = contactEntity.contactImage?.data != nil ? .updated : .removed
        }

        if let conversation = entityManager.entityFetcher.conversation(for: contactEntity) {
            delta.syncContact.update(conversation: conversation)

            delta.lastConversationUpdate = conversation.lastUpdate
        }
        else {
            delta.syncContact.update(conversationCategory: .default)
            delta.syncContact.update(conversationVisibility: .normal)
        }

        apply(delta)
    }

    /// Update (remove) acquaintance level.
    ///   - identity: Contact identity
    ///   - value: State (0: direct, 1: group)
    ///
    /// enum {
    ///     ContactAcquaintanceLevelDirect = 0,
    ///     ContactAcquaintanceLevelGroup = 1
    /// };
    @objc func updateAcquaintanceLevel(identity: String, value: NSNumber?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        var acquaintanceLevel: Sync_Contact.AcquaintanceLevel?
        if let value {
            assert(value.intValue >= 0 && value.intValue <= 1)

            acquaintanceLevel = Sync_Contact.AcquaintanceLevel(rawValue: value.intValue)
        }
        delta.syncContact.update(acquaintanceLevel: acquaintanceLevel)
        apply(delta)
    }

    func updateConversationCategory(identity: String, value: ConversationCategory?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact
            .update(conversationCategory: value != nil ? Sync_ConversationCategory(rawValue: value!.rawValue) : nil)
        apply(delta)
    }

    func updateConversationVisibility(identity: String, value: ConversationVisibility?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact
            .update(conversationVisibility: value != nil ? Sync_ConversationVisibility(rawValue: value!.rawValue) : nil)
        apply(delta)
    }

    @objc func updateFeatureMask(identity: String, value: NSNumber?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact.update(featureMask: value?.uint64Value)
        apply(delta)
    }

    @objc func updateFirstName(identity: String, value: String?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact.update(firstName: value)
        apply(delta)
    }

    /// Update identity type (see identity states)
    /// - Parameters:
    ///    - identity: Threema-ID of the (work) contact
    ///    - value: True identity is a work identity, changes on `UserSettings.workIdentities`
    @objc func updateIdentityType(identity: String, value: NSNumber?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        var identityType: Sync_Contact.IdentityType?
        if let value {
            assert(value.intValue >= 0 && value.intValue <= 1)

            identityType = Sync_Contact.IdentityType(rawValue: value.intValue)
        }
        delta.syncContact.update(identityType: identityType)
        apply(delta)
    }

    @objc func updateLastName(identity: String, value: String?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact.update(lastName: value)
        apply(delta)
    }

    @objc func updateNickname(identity: String, value: String?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact.update(nickname: value)
        apply(delta)
    }

    func updateNotificationSound(identity: String, isMuted: Bool?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact.update(notificationSoundIsMuted: isMuted)
        apply(delta)
    }

    func updateNotificationTrigger(identity: String, type: PushSetting.PushSettingType, expiresAt: Date?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact.update(notificationTriggerType: type, notificationTriggerExpiresAt: expiresAt)
        apply(delta)
    }

    /// Update read receipt
    /// - Parameters:
    ///   - identity: Identity of contact to update value for
    ///   - value: One of the `ReadReceipt` raw values
    @objc func updateReadReceipt(identity: String, value: ReadReceipt) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact.update(readReceipt: value)
        apply(delta)
    }

    /// Update (remove) state.
    /// - Parameters:
    ///   - identity: Contact identity
    ///   - value: State (0: active, 1: inactive, 2: invalid)
    ///
    /// enum {
    ///     kStateActive = 0,
    ///     kStateInactive = 1,
    ///     kStateInvalid = 2
    /// };
    @objc func updateState(identity: String, value: NSNumber?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        var activitySate: Sync_Contact.ActivityState?
        if let value {
            assert(value.intValue >= 0 && value.intValue <= 2)

            activitySate = Sync_Contact.ActivityState(rawValue: value.intValue)
        }
        delta.syncContact.update(activityState: activitySate)
        apply(delta)
    }

    @objc func updateTypingIndicator(identity: String, value: TypingIndicator) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact.update(typingIndicator: value)
        apply(delta)
    }

    /// Update (remove) verification level.
    /// - Parameters:
    ///   - identity: Contact identity
    ///   - value: Verification level (0: unverified, 1: serverVerified, 2: fullyVerified)
    ///
    /// enum {
    ///     kVerificationLevelUnverified = 0,
    ///     kVerificationLevelServerVerified,
    ///     kVerificationLevelFullyVerified,
    ///     // Legacy value, do not use anymore except for migration. Use workContact instead
    ///     kVerificationLevelWorkVerified,
    ///     // Legacy value, do not use anymore except for migration. Use workContact instead
    ///     kVerificationLevelWorkFullyVerified
    /// };
    @objc func updateVerificationLevel(identity: String, value: NSNumber?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        delta.syncContact
            .update(verificationLevel: value != nil ? Sync_Contact.VerificationLevel(rawValue: value!.intValue) : nil)
        apply(delta)
    }

    /// Update work verification level.
    /// - Parameters:
    ///    - identity: Threema-ID of the work contact
    ///    - value: True work contact is in the same work subscription (package) as myself, changes on
    ///             `Contact.isWork()` -> `Contact.workContact`
    @objc func updateWorkVerificationLevel(identity: String, value: NSNumber?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var delta = getDelta(identity)
        var workVerificationLevel: Sync_Contact.WorkVerificationLevel?
        if let value {
            workVerificationLevel = value.boolValue ? .workSubscriptionVerified : Sync_Contact.WorkVerificationLevel
                .none
        }
        delta.syncContact.update(workVerificationLevel: workVerificationLevel)
        apply(delta)
    }

    /// Update (remove) profile contact image.
    /// - Parameters:
    ///   - identity: Contact identity
    ///   - value: DeltaUpdateType (0: unchanged, 1: removed, 2: updated)
    @objc func setProfileUpdateType(identity: String, value: Int) {
        guard userSettings.enableMultiDevice else {
            return
        }
        assert(value >= 0 && value <= 2)

        var delta = getDelta(identity)
        delta.profilePicture = DeltaUpdateType(rawValue: value)!
        apply(delta)
    }

    /// Update (remove) profile custom (user) image.
    /// - Parameters:
    ///   - identity: Contact identity
    ///   - value: DeltaUpdateType (0: unchanged, 1: removed, 2: updated)
    ///   - blobID: Blob ID of already uploaded profile picture
    ///   - encryptionKey: Encryption key of already uploaded profile picture
    @objc func setContactProfileUpdateType(identity: String, value: Int, blobID: Data?, encryptionKey: Data?) {
        guard userSettings.enableMultiDevice else {
            return
        }
        assert(value >= 0 && value <= 2)

        var delta = getDelta(identity)
        delta.contactProfilePicture = DeltaUpdateType(rawValue: value)!
        delta.contactImageBlobID = blobID
        delta.contactImageEncryptionKey = encryptionKey
        apply(delta)
    }
    
    /// Create tasks to synchronize the contacts, load and scale profile picture if is necessary
    func sync() -> Promise<Void> {
        guard userSettings.enableMultiDevice else {
            DDLogInfo("Do not sync because multi device is not activated")
            return Promise()
        }

        // Load images for profile picture
        entityManager.performAndWait {
            let identities = self.deltaSyncContacts.map(\.syncContact.identity)

            for identity in identities {
                if let contact = self.entityManager.entityFetcher.contact(for: identity) {
                    var delta = self.getDelta(identity)

                    if delta.profilePicture == .updated,
                       let imageData = contact.imageData {
                        delta.image = imageData
                    }

                    if delta.contactProfilePicture == .updated,
                       delta.contactImageBlobID != nil,
                       delta.contactImageEncryptionKey != nil,
                       let imageData = contact.contactImage?.data {
                        delta.contactImage = imageData
                    }

                    self.apply(delta)
                }
            }
        }

        // Syncing a large number of contacts in a single transaction might exceed the transaction
        // limit on the mediator server
        let chunked = deltaSyncContacts.chunked(into: chunkSize)
        let (taskTuple, taskResults) = taskTupleWithTaskResults(for: chunked)

        if !taskResults.isEmpty {
            // Add all tasks to TaskManager and wait until all tasks are completed
            return firstly { () -> Promise<Void> in
                taskManager.add(taskDefinitionTuples: taskTuple)
                return Promise()
            }
            .then { () -> Promise<Void> in
                race(
                    when(fulfilled: taskResults),
                    self.timeout(seconds: 60 * 5 * taskResults.count)
                )
                .then { _ -> Promise<Void> in
                    self.deltaSyncContacts = [DeltaSyncContact]()

                    return Promise()
                }
            }
        }
        return Promise()
    }

    /// Objective-C bridge
    @objc func syncObjc(completionHandler: @escaping (Error?) -> Void) {
        sync()
            .done {
                completionHandler(nil)
            }
            .catch { error in
                completionHandler(error)
            }
    }

    /// Sync as async call, without return value
    @objc func syncAsync() {
        sync()
            .catch { error in
                DDLogError("Sync contacts failed: \(error)")
            }
    }

    /// Immediately sync a deleted contact
    /// - Parameter identity: The identity of the to be deleted contact
    func deleteAndSync(identity: String) -> Promise<Void> {
        Promise { seal in
            guard userSettings.enableMultiDevice else {
                seal.fulfill_()
                return
            }

            let task = TaskDefinitionDeleteContactSync(contacts: [identity])
            taskManager.add(taskDefinition: task) { _, error in
                if let error {
                    seal.reject(error)
                }
                else {
                    seal.fulfill_()
                }
            }
        }
    }

    // Objective-c bridge
    @objc func deleteAndSyncObjc(identity: String, completionHandler: @escaping (Error?) -> Void) {
        deleteAndSync(identity: identity)
            .done {
                completionHandler(nil)
            }
            .catch { error in
                completionHandler(error)
            }
    }

    func getChunkSize() -> Int {
        chunkSize
    }
    
    // MARK: Private Methods

    private func apply(_ delta: DeltaSyncContact) {
        if let index = deltaSyncContacts.firstIndex(where: { item in
            item.syncContact.identity == delta.syncContact.identity
        }) {
            deltaSyncContacts[index] = delta
        }
        else {
            deltaSyncContacts.append(delta)
        }
    }

    private func getDelta(_ identity: String) -> DeltaSyncContact {
        if let delta = deltaSyncContacts.first(where: { $0.syncContact.identity == identity }) {
            return delta
        }
        else {
            var syncContact = Sync_Contact()
            syncContact.identity = identity

            // Default sync action is update, is once changed to create never will change back to update
            let delta = DeltaSyncContact(syncContact: syncContact, syncAction: .update)
            deltaSyncContacts.append(delta)

            return delta
        }
    }

    /// Create task and completion handler tuple for adding in TaskManager.
    /// - Parameter chunked: Chunked contacts to sync
    /// - Returns: Tuple task / completion handler and array of Promises to wait until all tasks completed
    private func taskTupleWithTaskResults(
        for chunked: [[DeltaSyncContact]]
    ) -> ([(taskDefinition: TaskDefinitionProtocol, completionHandler: TaskCompletionHandler)], [Promise<Void>]) {

        var taskTuple = [(taskDefinition: TaskDefinitionProtocol, completionHandler: TaskCompletionHandler)]()
        var taskResults = [Promise<Void>]()

        for chunk in chunked {
            if !chunk.isEmpty {
                let taskWithTaskResult = taskWithTaskResult(for: chunk)

                taskTuple.append((taskWithTaskResult.taskDefinition, taskWithTaskResult.completionHandler!))
                taskResults.append(taskWithTaskResult.taskResult)
            }
        }

        return (taskTuple, taskResults)
    }

    /// Create task and completion handler for update contact sync.
    /// Additional return a Promise for the results of completion handler.
    /// - Parameter chunk: Contacts to sync handled by the returned task
    /// - Returns: Task with its completion handler and Promise for the result
    private func taskWithTaskResult(
        for chunk: [DeltaSyncContact]
    ) -> (
        taskDefinition: TaskDefinitionProtocol,
        completionHandler: TaskCompletionHandler?,
        taskResult: Promise<Void>
    ) {
        let taskDefinition = TaskDefinitionUpdateContactSync(deltaSyncContacts: chunk)
        var completionHandler: TaskCompletionHandler?

        let taskResult = Promise<Void> { seal in
            completionHandler = { (_: TaskDefinitionProtocol, error: Error?) in
                if let error {
                    DDLogError("Task \(taskDefinition) not completed successfully because of an error. Error: \(error)")
                    seal.reject(error)
                }
                else {
                    seal.fulfill_()
                }
            }
        }

        return (taskDefinition, completionHandler, taskResult)
    }

    private func timeout(seconds: Int) -> Promise<Void> {
        Promise { seal in
            after(seconds: TimeInterval(seconds))
                .done {
                    seal.reject(TaskExecutionError.reflectMessageTimeout(message: "Timeout"))
                }
                .catch { error in
                    seal.reject(error)
                }
        }
    }
}
