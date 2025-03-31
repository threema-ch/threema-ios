//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

final class TaskExecutionUpdateContactSync: TaskExecutionBlobTransaction {
    private typealias BlobEncryptionKey = (uploadID: String, blob: Data?, blobID: Data?, encryptionKey: Data?)
    private typealias BlobEncrypted = (uploadID: String, blobEncrypted: Data?, blobMessage: Common_Blob)

    override func executeTransaction() throws -> Promise<Void> {
        guard let taskDefinition = taskDefinition as? TaskDefinitionUpdateContactSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        return try uploadProfilePictures()
            .then { blobsEncrypted in
                var reflectResults = [Promise<Void>]()

                for deltaSyncContact in taskDefinition.deltaSyncContacts {
                    var syncContact = deltaSyncContact.syncContact

                    switch deltaSyncContact.profilePicture {
                    case .updated:
                        if let blobMessage = blobsEncrypted
                            .first(where: { $0.uploadID == deltaSyncContact.syncContact.identity })?.blobMessage {
                            var commonImage = Common_Image()
                            commonImage.blob = blobMessage
                            syncContact.userDefinedProfilePicture.updated = commonImage
                        }
                        else {
                            DDLogError("Encrypted blob for profile picture is missing")
                        }
                    case .removed:
                        syncContact.userDefinedProfilePicture.removed = Common_Unit()
                    case .unchanged:
                        break
                    }

                    switch deltaSyncContact.contactProfilePicture {
                    case .updated:
                        if let blobMessage = blobsEncrypted
                            .first(where: { $0.uploadID == "\(deltaSyncContact.syncContact.identity)-c" })?
                            .blobMessage {
                            var commonImage = Common_Image()
                            commonImage.blob = blobMessage
                            syncContact.contactDefinedProfilePicture.updated = commonImage
                        }
                        else {
                            DDLogError("Encrypted blob for contact profile picture is missing")
                        }
                    case .removed:
                        syncContact.contactDefinedProfilePicture.removed = Common_Unit()
                    case .unchanged:
                        break
                    }

                    let envelope = self.frameworkInjector.mediatorMessageProtocol.getEnvelopeForContactSync(
                        contact: syncContact,
                        syncAction: deltaSyncContact.syncAction
                    )

                    reflectResults.append(Promise { try $0.fulfill(
                        _ = self.reflectMessage(
                            envelope: envelope,
                            ltReflect: self.taskContext.logReflectMessageToMediator,
                            ltAck: self.taskContext.logReceiveMessageAckFromMediator
                        )
                    ) })
                }

                return when(fulfilled: reflectResults).asVoid()
            }
    }

    override func shouldDrop() throws -> Bool {
        guard let task = taskDefinition as? TaskDefinitionUpdateContactSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        frameworkInjector.entityManager.performAndWait {
            task.deltaSyncContacts = task.deltaSyncContacts
                .filter { self.checkPrecondition(delta: $0) }
        }
        return task.deltaSyncContacts.count <= 0
    }

    override func writeLocal() -> Promise<Void> {
        DDLogInfo("Contact sync writes local data immediately")
        return Promise()
    }

    /// Checks whether the contact has not changed since the task was created, or not already exists on creation
    /// - Parameters:
    ///   - delta: Delta changes of sync contact
    /// - Returns: True if the contact has not changed since the task was created. False otherwise.
    private func checkPrecondition(delta: DeltaSyncContact) -> Bool {
        switch delta.syncAction {
        case .create:
            // Will the contact created, because of incoming message and unknown sender,
            // the contact must be sync before storing into the database.
            // Otherwise the contact will be stored into the database before syncing.
            guard (frameworkInjector.entityManager.performAndWait {
                self.frameworkInjector.entityManager.entityFetcher
                    .contact(for: delta.syncContact.identity) != nil
            })
            else {
                return true
            }

            return checkContactHasChanged(delta)
        case .update:
            return checkContactHasChanged(delta)
        }
    }

    private func checkContactHasChanged(_ delta: DeltaSyncContact) -> Bool {
        let sContact = delta.syncContact

        var allTrue = false

        frameworkInjector.entityManager.performAndWait {
            guard let contact = self.frameworkInjector.entityManager.entityFetcher
                .contact(for: sContact.identity) else {
                DDLogInfo("Contact was deleted. Do not sync")
                return
            }

            let conversation = self.frameworkInjector.entityManager.entityFetcher.conversation(for: contact)

            let samePublicKey = (sContact.hasPublicKey && sContact.publicKey == contact.publicKey) || !sContact
                .hasPublicKey
            let sameVerificationLevel = (
                sContact.hasVerificationLevel && sContact.verificationLevel.rawValue == contact
                    .verificationLevel.intValue
            ) || !sContact.hasVerificationLevel
            let sameWorkStatus = (
                sContact.hasIdentityType && sContact
                    .identityType ==
                    (
                        self.frameworkInjector.userSettings.workIdentities
                            .contains(contact.identity) ? .work : .regular
                    )
            ) || !sContact.hasIdentityType
            let sameAcquaintanceLevel = (
                sContact.hasAcquaintanceLevel && sContact
                    .acquaintanceLevel == (contact.isContactHidden ? .groupOrDeleted : .direct)
            ) || !sContact.hasAcquaintanceLevel

            let sameFirstname = (sContact.hasFirstName && sContact.firstName == contact.firstName ?? "") ||
                !sContact
                .hasFirstName
            let sameLastname = (sContact.hasLastName && sContact.lastName == contact.lastName ?? "") || !sContact
                .hasLastName
            let sameNickname = (sContact.hasNickname && sContact.nickname == contact.publicNickname ?? "") ||
                !sContact
                .hasNickname

            let sameProfilePicture = (
                ((
                    delta.profilePicture == .updated
                        || delta.profilePicture == .unchanged
                ) && contact.imageData != nil)
                    ||
                    ((
                        delta.profilePicture == .removed
                            || delta.profilePicture == .unchanged
                    ) && contact.imageData == nil)
            )

            var sameImage = false
            if let image = contact.imageData {
                sameImage = delta.profilePicture == .updated ? delta
                    .image == image : delta.profilePicture == .unchanged
            }
            else {
                sameImage = delta.profilePicture == .removed || delta
                    .profilePicture == .unchanged
            }

            let sameContactProfilePicture = (
                ((
                    delta.contactProfilePicture == .updated
                        || delta.contactProfilePicture == .unchanged
                ) && contact.contactImage?.data != nil)
                    ||
                    ((
                        delta.contactProfilePicture == .removed
                            || delta.contactProfilePicture == .unchanged
                    ) && contact.contactImage?.data == nil)
            )

            var sameContactImage = false
            if let image = contact.contactImage?.data {
                sameContactImage = delta.contactProfilePicture == .updated ? delta
                    .contactImage == image : delta.contactProfilePicture == .unchanged
            }
            else {
                sameContactImage = delta.contactProfilePicture == .removed || delta
                    .contactProfilePicture == .unchanged
            }

            let sameImportStatus = (
                sContact.hasSyncState && sContact.syncState.rawValue == contact.importedStatus.rawValue
            ) || !sContact.hasSyncState
            let sameConversationCategory = (
                sContact.hasConversationCategory && sContact.conversationCategory
                    .rawValue == conversation?.conversationCategory.rawValue ?? ConversationEntity.Category
                    .default.rawValue
            ) || !sContact.hasConversationCategory
            let sameConversationVisibility = (
                sContact.hasConversationVisibility && sContact.conversationVisibility
                    .rawValue == conversation?.conversationVisibility.rawValue ?? ConversationEntity
                    .Visibility.default
                    .rawValue
            ) || !sContact.hasConversationVisibility

            allTrue = samePublicKey &&
                sameVerificationLevel &&
                sameWorkStatus &&
                sameAcquaintanceLevel &&
                sameImportStatus &&
                sameConversationCategory &&
                sameConversationVisibility &&
                sameFirstname &&
                sameLastname &&
                sameNickname &&
                sameProfilePicture &&
                sameImage &&
                sameContactProfilePicture &&
                sameContactImage &&
                sameVerificationLevel
        }

        return allTrue
    }

    // MARK: Private functions

    private func uploadProfilePictures() throws -> Promise<[BlobEncrypted]> {
        guard let taskDefinition = taskDefinition as? TaskDefinitionUpdateContactSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        frameworkInjector.entityManager.performAndWait {
            taskDefinition.deltaSyncContacts = taskDefinition.deltaSyncContacts
                .filter { self.checkPrecondition(delta: $0) }
        }

        var blobs = [BlobEncryptionKey]()
        taskDefinition.deltaSyncContacts
            .filter { $0.profilePicture == .updated && $0.image != nil }
            .forEach { delta in
                blobs.append((delta.syncContact.identity, delta.image, nil, nil))
            }
        taskDefinition.deltaSyncContacts
            .filter { $0.contactProfilePicture == .updated && $0.contactImage != nil }
            .forEach { delta in
                if let blobID = delta.contactImageBlobID,
                   let encryptionKey = delta.contactImageEncryptionKey {
                    // Blob is already uploaded
                    blobs.append(("\(delta.syncContact.identity)-c", nil, blobID, encryptionKey))
                }
                else if let image = delta.contactImage {
                    blobs.append(("\(delta.syncContact.identity)-c", image, nil, nil))
                }
            }

        try taskDefinition.checkDropping()
        var blobsEncrypted = try encrypt(blobs: blobs)

        if blobsEncrypted.isEmpty {
            return Promise { $0.fulfill(blobsEncrypted) }
        }

        return firstly {
            try taskDefinition.checkDropping()

            let encryptedBlobsForUploading: [BlobUpload] = blobsEncrypted
                .filter { $0.blobEncrypted != nil }
                .map { ($0.uploadID, $0.blobEncrypted!) }

            if !encryptedBlobsForUploading.isEmpty {
                return uploadBlobs(blobs: encryptedBlobsForUploading)
            }
            else {
                return Promise { seal in seal.fulfill([BlobUploaded]()) }
            }
        }.then { (uploadedBlobs: [BlobUploaded]) -> Promise<[BlobEncrypted]> in
            Promise { seal in
                if uploadedBlobs.count != blobsEncrypted.filter({ $0.blobEncrypted != nil }).count {
                    DDLogError("Not all blobs of contact profile pictures are uploaded!")
                    seal.reject(TaskExecutionTransactionError.blobIDMismatch)
                    return
                }

                // Update blob ID for new uploaded blobs
                for uploadedBlob in uploadedBlobs {
                    var isSet = false
                    var i = 0
                    while i < blobsEncrypted.count, !isSet {
                        if blobsEncrypted[i].uploadID == uploadedBlob.uploadID,
                           blobsEncrypted[i].blobMessage.id.isEmpty {
                            blobsEncrypted[i].blobMessage.id = uploadedBlob.blobID
                            isSet = true
                        }
                        i += 1
                    }
                }

                seal.fulfill(blobsEncrypted)
            }
        }
    }

    /// Encrypt blob data if not already uploaded (blob ID is set).
    /// - Parameter blobs: Blobs for the encryption and creation of D2D blob messages
    /// - Returns: Encrypted blobs and its D2D blob messages
    private func encrypt(blobs: [BlobEncryptionKey]) throws -> [BlobEncrypted] {
        var encryptedBlobs = [BlobEncrypted]()

        for item in blobs {
            if let blobID = item.blobID,
               let encryptionKey = item.encryptionKey {
                var blobMessage = Common_Blob()
                blobMessage.id = blobID
                blobMessage.key = encryptionKey
                blobMessage.nonce = ThreemaProtocol.nonce01
                blobMessage.uploadedAt = Date().millisecondsSince1970.littleEndian
                encryptedBlobs.append((item.uploadID, nil, blobMessage))
            }
            else if let data = item.blob {
                let encryptedBlob = try encryptBlob(data: data)
                var blobMessage = Common_Blob()
                blobMessage.key = encryptedBlob.key
                blobMessage.nonce = encryptedBlob.nonce
                blobMessage.uploadedAt = Date().millisecondsSince1970.littleEndian
                encryptedBlobs.append((item.uploadID, encryptedBlob.encryptedData, blobMessage))
            }
            else {
                throw TaskExecutionTransactionError.blobDataEncryptionFailed
            }
        }

        return encryptedBlobs
    }
}
