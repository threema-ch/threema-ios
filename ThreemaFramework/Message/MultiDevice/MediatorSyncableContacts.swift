//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

    private let serverConnector: ServerConnectorProtocol
    private var taskManager: TaskManagerProtocol
    private let entityManager: EntityManager
    
    init(
        _ serverConnector: ServerConnectorProtocol,
        _ taskManager: TaskManagerProtocol,
        _ entityManager: EntityManager
    ) {
        self.serverConnector = serverConnector
        self.taskManager = taskManager
        self.entityManager = entityManager
    }
    
    @objc override convenience init() {
        self.init(ServerConnector.shared(), TaskManager(), EntityManager(withChildContextForBackgroundProcess: true))
    }

    /// Update/Sync all attributes of a contact.
    /// - Parameters:
    ///   - identity: Contact identity tp sync
    ///   - withoutProfileImage: True profile picture will not be synced
    @objc func updateAll(identity: String, withoutProfileImage: Bool) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        entityManager.performBlockAndWait {
            guard let contact = self.entityManager.entityFetcher.contact(for: identity) else {
                return
            }

            let conversation = self.entityManager.entityFetcher.conversation(for: contact)

            var delta = self.getDelta(identity: contact.identity)

            delta.syncContact.identity = identity
            delta.syncContact.publicKey = contact.publicKey

            if let firstName = contact.firstName {
                delta.syncContact.firstName = firstName
            }
            else {
                delta.syncContact.clearFirstName()
            }

            if let lastName = contact.lastName {
                delta.syncContact.lastName = lastName
            }
            else {
                delta.syncContact.clearLastName()
            }

            delta.syncContact.identityType = contact.workContact.boolValue ? .work : .regular

            if let nickname = contact.publicNickname {
                delta.syncContact.nickname = nickname
            }
            else {
                delta.syncContact.clearNickname()
            }

            if let createAt = contact.createdAt {
                delta.syncContact.createdAt = UInt64(createAt.millisecondsSince1970)
            }
            else {
                delta.syncContact.clearCreatedAt()
            }

            delta.syncContact.verificationLevel = Sync_Contact
                .VerificationLevel(rawValue: Int(truncating: contact.verificationLevel))!

            switch contact.state?.intValue {
            case kStateActive:
                delta.syncContact.activityState = .active
            case kStateInactive:
                delta.syncContact.activityState = .inactive
            case kStateInvalid:
                delta.syncContact.activityState = .invalid
            default:
                DDLogError("Contact state has an unknown value")
            }

            switch contact.importedStatus {
            case .initial:
                delta.syncContact.syncState = .initial
            case .imported:
                delta.syncContact.syncState = .imported
            case .custom:
                delta.syncContact.syncState = .custom
            }

            if let visibility = conversation?.conversationVisibility {
                switch visibility {
                case .archived:
                    delta.syncContact.conversationVisibility = .archive
                @unknown default:
                    DDLogError("Conversation visibility has an unknown value")
                }
            }
            else {
                delta.syncContact.clearConversationVisibility()
            }

            if let category = conversation?.conversationCategory {
                switch category {
                case .private:
                    delta.syncContact.conversationCategory = .protected
                case .default:
                    delta.syncContact.conversationCategory = .default
                @unknown default:
                    // Show en alert with an sync error
                    DDLogError("Conversation category has a unknown value")
                }
            }
            else {
                delta.syncContact.clearConversationCategory()
            }

            if !withoutProfileImage {
                delta.profilePicture = contact.imageData != nil ? .updated : .removed
                delta.contactProfilePicture = contact.contactImage?.data != nil ? .updated : .removed
            }

            self.apply(delta: delta)
        }
    }

    @objc func updateFirstName(identity: String, value: String?) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        var delta = getDelta(identity: identity)
        if let value = value {
            delta.syncContact.firstName = value
        }
        else {
            delta.syncContact.clearFirstName()
        }
        apply(delta: delta)
    }

    @objc func updateLastName(identity: String, value: String?) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        var delta = getDelta(identity: identity)
        if let value = value {
            delta.syncContact.lastName = value
        }
        else {
            delta.syncContact.clearLastName()
        }
        apply(delta: delta)
    }

    @objc func updateNickname(identity: String, value: String?) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        var delta = getDelta(identity: identity)
        if let value = value {
            delta.syncContact.nickname = value
        }
        else {
            delta.syncContact.clearNickname()
        }
        apply(delta: delta)
    }

    @objc func updateState(identity: String, value: NSNumber?) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        var delta = getDelta(identity: identity)
        if let value = value {
            assert(value.intValue >= 0 && value.intValue <= 2)

            if let state = Sync_Contact.ActivityState(rawValue: value.intValue) {
                delta.syncContact.activityState = state
            }
        }
        else {
            delta.syncContact.clearIdentityType()
        }
        apply(delta: delta)
    }

    /// Update (remove) verification level.
    /// - Parameters:
    ///   - identity: Contact identity
    ///   - value: Verification level (0: unverified, 1: serverVerified, 2: fullyVerified)
    @objc func updateVerificationLevel(identity: String, value: NSNumber?) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        var delta = getDelta(identity: identity)
        if let value = value {
            delta.syncContact.verificationLevel = Sync_Contact
                .VerificationLevel(rawValue: value.intValue) ?? .unverified
        }
        else {
            delta.syncContact.clearVerificationLevel()
        }
        apply(delta: delta)
    }

    @objc func updateIdentityType(identity: String, value: NSNumber?) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        var delta = getDelta(identity: identity)
        if let value = value {
            assert(value.intValue >= 0 && value.intValue <= 1)

            if let identityType = Sync_Contact.IdentityType(rawValue: value.intValue) {
                delta.syncContact.identityType = identityType
            }
        }
        else {
            delta.syncContact.clearIdentityType()
        }
        apply(delta: delta)
    }

    /// Update (remove) profile contact image.
    /// - Parameters:
    ///   - identity: Contact identity
    ///   - value: DeltaUpdateType (0: unchanged, 1: removed, 2: updated)
    @objc func setProfileUpdateType(identity: String, value: Int) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }
        assert(value >= 0 && value <= 2)

        var delta = getDelta(identity: identity)
        delta.profilePicture = DeltaUpdateType(rawValue: value)!
        apply(delta: delta)
    }

    /// Update (remove) profile custom (user) image.
    /// - Parameters:
    ///   - identity: Contact identity
    ///   - value: DeltaUpdateType (0: unchanged, 1: removed, 2: updated)
    @objc func setContactProfileUpdateType(identity: String, value: Int) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }
        assert(value >= 0 && value <= 2)

        var delta = getDelta(identity: identity)
        delta.contactProfilePicture = DeltaUpdateType(rawValue: value)!
        apply(delta: delta)
    }

    /// Create tasks to synchronize the contacts, load and scale profile picture if is necessary
    func sync() -> Promise<Void> {
        guard serverConnector.isMultiDeviceActivated else {
            DDLogInfo("Do not sync because multi device is not activated")
            return Promise()
        }

        // Load images for profile picture
        entityManager.performBlockAndWait {
            let identities = self.deltaSyncContacts.map(\.syncContact.identity)

            for identity in identities {
                if let contact = self.entityManager.entityFetcher.contact(for: identity) {
                    var delta = self.getDelta(identity: identity)

                    if delta.profilePicture == .updated,
                       let imageData = contact.imageData {
                        delta.image = imageData
                    }

                    if delta.contactProfilePicture == .updated,
                       let imageData = contact.contactImage?.data {
                        delta.contactImage = imageData
                    }

                    self.apply(delta: delta)
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

    /// Objective-c bridge
    @objc func syncObjc() -> AnyPromise {
        AnyPromise(sync())
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
            guard serverConnector.isMultiDeviceActivated else {
                seal.fulfill_()
                return
            }

            let task = TaskDefinitionDeleteContactSync(contacts: [identity])
            taskManager.add(taskDefinition: task) { _, error in
                if let error = error {
                    seal.reject(error)
                }
                else {
                    seal.fulfill_()
                }
            }
        }
    }

    // Objective-c bridge
    @objc func deleteAndSyncObjc(identity: String) -> AnyPromise {
        AnyPromise(deleteAndSync(identity: identity))
    }

    func getChunkSize() -> Int {
        chunkSize
    }
    
    // MARK: Private Methods

    private func apply(delta: DeltaSyncContact) {
        if let index = deltaSyncContacts.firstIndex(where: { item in
            item.syncContact.identity == delta.syncContact.identity
        }) {
            deltaSyncContacts[index] = delta
        }
        else {
            deltaSyncContacts.append(delta)
        }
    }

    private func getDelta(identity: String) -> DeltaSyncContact {
        if let delta = deltaSyncContacts.first(where: { $0.syncContact.identity == identity }) {
            return delta
        }
        else {
            var syncContact = Sync_Contact()
            syncContact.identity = identity

            let delta = DeltaSyncContact(syncContact: syncContact)
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
    /// Additional retrun a Promise for the results of completion handler.
    /// - Parameter chunk: Contacts to sync handeld by the returned task
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
                if let error = error {
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
