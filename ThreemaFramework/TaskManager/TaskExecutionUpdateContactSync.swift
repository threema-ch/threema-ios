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

final class TaskExecutionUpdateContactSync: TaskExecutionBlobTransaction {
    private typealias BlobAndKey = (blob: Data?, blobID: Data?, encryptionKey: Data?)
    private typealias BlobAndKeyEncrypted = (blobEncrypted: Data?, blobMessage: Common_Blob)

    private var blobsEncrypted = [BlobAndKeyEncrypted]()

    override func prepare() -> Promise<Void> {
        guard let taskDefinition = taskDefinition as? TaskDefinitionUpdateContactSync else {
            return Promise<Void> { $0.reject(TaskExecutionError.wrongTaskDefinitionType) }
        }
        
        frameworkInjector.entityManager.performBlockAndWait {
            taskDefinition.deltaSyncContacts = taskDefinition.deltaSyncContacts
                .filter { self.checkPrecondition(delta: $0) }
        }

        var blobs = [BlobAndKey]()
        taskDefinition.deltaSyncContacts
            .filter { $0.profilePicture == .updated && $0.image != nil }
            .forEach { delta in
                blobs.append((delta.image, nil, nil))
            }
        taskDefinition.deltaSyncContacts
            .filter { $0.contactProfilePicture == .updated && $0.contactImage != nil }
            .forEach { delta in
                if let blobID = delta.contactImageBlobID,
                   let encryptionKey = delta.contactImageEncryptionKey {
                    // Blob is already uploaded
                    blobs.append((nil, blobID, encryptionKey))
                }
                else if let image = delta.contactImage {
                    blobs.append((image, nil, nil))
                }
            }

        do {
            blobsEncrypted = try encrypt(blobs: blobs)
        }
        catch {
            return Promise<Void> { $0.reject(error) }
        }
        
        if blobsEncrypted.isEmpty {
            return Promise()
        }
        
        return firstly {
            let blobsForUploading = blobsEncrypted.compactMap(\.blobEncrypted)
            if !blobsForUploading.isEmpty {
                return uploadBlobs(blobs: blobsForUploading)
            }
            else {
                return Promise { seal in seal.fulfill([Data]()) }
            }
        }.then { [self] blobIDs -> Promise<Void> in
            guard blobIDs.count == blobsEncrypted.filter({ $0.blobEncrypted != nil }).count else {
                throw TaskExecutionTransactionError.blobIDMismatch
            }

            // Update blob ID for new uploaded blobs
            var i = 0
            for blobID in blobIDs {
                var isSet = false
                while i < blobsEncrypted.count, !isSet {
                    if blobsEncrypted[i].blobMessage.id.isEmpty {
                        blobsEncrypted[i].blobMessage.id = blobID
                        isSet = true
                    }
                    i += 1
                }
            }

            return Promise()
        }
    }

    /// Encrypt blob data if not already uploaded (blob ID is set).
    /// - Parameter blobs: Blobs for to encrypt and create D2D blob messages
    /// - Returns: Encrypted blobs and its D2D blob messages
    private func encrypt(blobs: [BlobAndKey]) throws -> [BlobAndKeyEncrypted] {
        var encryptedBlobs = [BlobAndKeyEncrypted]()

        for item in blobs {
            if let blobID = item.blobID,
               let encryptionKey = item.encryptionKey {
                var blobMessage = Common_Blob()
                blobMessage.id = blobID
                blobMessage.key = encryptionKey
                blobMessage.nonce = ThreemaProtocol.nonce01
                blobMessage.uploadedAt = Date().millisecondsSince1970.littleEndian
                encryptedBlobs.append((nil, blobMessage))
            }
            else if let data = item.blob {
                let encryptedBlob = try encrypt(data: data)
                var blobMessage = Common_Blob()
                blobMessage.key = encryptedBlob.key
                blobMessage.nonce = encryptedBlob.nonce
                blobMessage.uploadedAt = Date().millisecondsSince1970.littleEndian
                encryptedBlobs.append((encryptedBlob.encryptedData, blobMessage))
            }
            else {
                throw TaskExecutionTransactionError.blobDataEncryptionFailed
            }
        }

        return encryptedBlobs
    }
    
    private func encrypt(data: Data) throws -> (key: Data, nonce: Data, encryptedData: Data) {
        guard let encryptionKey = NaClCrypto.shared()?.randomBytes(kBlobKeyLen) else {
            throw TaskExecutionTransactionError.blobDataEncryptionFailed
        }
        let nonce = ThreemaProtocol.nonce01
        guard let encryptedProfileImageData = NaClCrypto.shared()?
            .symmetricEncryptData(data, withKey: encryptionKey, nonce: nonce) else {
            throw TaskExecutionTransactionError.blobDataEncryptionFailed
        }
        return (encryptionKey, nonce, encryptedProfileImageData)
    }
    
    override func reflectTransactionMessages() throws -> [Promise<Void>] {
        guard let taskDefinition = taskDefinition as? TaskDefinitionUpdateContactSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }
        
        var reflectResults = [Promise<Void>]()
        
        for deltaSyncContact in taskDefinition.deltaSyncContacts {
            var syncContact = deltaSyncContact.syncContact
            
            switch deltaSyncContact.profilePicture {
            case .updated:
                var commonImage = Common_Image()
                commonImage.blob = blobsEncrypted.removeFirst().blobMessage
                syncContact.userDefinedProfilePicture.updated = commonImage
            case .removed:
                syncContact.userDefinedProfilePicture.removed = Common_Unit()
            case .unchanged:
                break
            }

            switch deltaSyncContact.contactProfilePicture {
            case .updated:
                var commonImage = Common_Image()
                commonImage.blob = blobsEncrypted.removeFirst().blobMessage
                syncContact.contactDefinedProfilePicture.updated = commonImage
            case .removed:
                syncContact.contactDefinedProfilePicture.removed = Common_Unit()
            case .unchanged:
                break
            }
            
            let envelope = frameworkInjector.mediatorMessageProtocol.getEnvelopeForContactSync(
                contact: syncContact,
                syncAction: deltaSyncContact.syncAction
            )

            reflectResults.append(Promise { try $0.fulfill(_ = reflectMessage(
                envelope: envelope,
                ltReflect: self.taskContext.logReflectMessageToMediator,
                ltAck: self.taskContext.logReceiveMessageAckFromMediator
            )) })
        }
        
        return reflectResults
    }
    
    override func shouldSkip() throws -> Bool {
        guard let task = taskDefinition as? TaskDefinitionUpdateContactSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }
        
        frameworkInjector.entityManager.performBlockAndWait {
            task.deltaSyncContacts = task.deltaSyncContacts
                .filter { self.checkPrecondition(delta: $0) }
        }
        return task.deltaSyncContacts.count <= 0
    }
    
    override func writeLocal() -> Promise<Void> {
        DDLogInfo("Contact sync writes local data immediately")
        return Promise()
    }
    
    /// Checks whether the contact has not changed since the task was created
    /// - Parameters:
    ///   - delta: Delta changes of sync contact
    /// - Returns: True if the contact has not changed since the task was created. False otherwise.
    private func checkPrecondition(delta: DeltaSyncContact) -> Bool {
        let sContact = delta.syncContact

        var allTrue = false

        frameworkInjector.entityManager.performBlockAndWait {
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
                    (self.frameworkInjector.userSettings.workIdentities.contains(contact.identity) ? .work : .regular)
            ) || !sContact.hasIdentityType
            let sameAcquaintanceLevel = (
                sContact.hasAcquaintanceLevel && sContact
                    .acquaintanceLevel == (contact.isContactHidden ? .group : .direct)
            ) || !sContact.hasAcquaintanceLevel

            let sameFirstname = (sContact.hasFirstName && sContact.firstName == contact.firstName ?? "") || !sContact
                .hasFirstName
            let sameLastname = (sContact.hasLastName && sContact.lastName == contact.lastName ?? "") || !sContact
                .hasLastName
            let sameNickname = (sContact.hasNickname && sContact.nickname == contact.publicNickname ?? "") || !sContact
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
                    .rawValue == conversation?.conversationCategory.rawValue ?? ConversationCategory.default.rawValue
            ) || !sContact.hasConversationCategory
            let sameConversationVisibility = (
                sContact.hasConversationVisibility && sContact.conversationVisibility
                    .rawValue == conversation?.conversationVisibility.rawValue ?? ConversationVisibility.default
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
}
