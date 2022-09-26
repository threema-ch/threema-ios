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
import PromiseKit

class TaskExecutionUpdateContactSync: TaskExecutionBlobTransaction {
    var profilePictureBlobs = [Common_Blob]()
    var contactProfilePictureBlobs = [Common_Blob]()
    
    override func prepare() -> Promise<Void> {
        guard let taskDefinition = taskDefinition as? TaskDefinitionUpdateContactSync else {
            return Promise<Void> { $0.reject(TaskExecutionError.wrongTaskDefinitionType) }
        }
        
        frameworkInjector.backgroundEntityManager.performBlockAndWait {
            taskDefinition.deltaSyncContacts = taskDefinition.deltaSyncContacts
                .filter { self.checkPrecondition(delta: $0) }
        }
        
        let images = taskDefinition.deltaSyncContacts
            .compactMap { $0.profilePicture == .updated ? $0.image : nil }
        let contactImages = taskDefinition.deltaSyncContacts
            .compactMap { $0.contactProfilePicture == .updated ? $0.contactImage : nil }

        var encryptedData = [Data]()
        
        do {
            let imagesEncrypted = try encrypt(dataArr: images)
            profilePictureBlobs = imagesEncrypted.blobs
            encryptedData.append(contentsOf: imagesEncrypted.encryptedData)

            let contactImagesEncrypted = try encrypt(dataArr: contactImages)
            contactProfilePictureBlobs = contactImagesEncrypted.blobs
            encryptedData.append(contentsOf: contactImagesEncrypted.encryptedData)
        }
        catch {
            return Promise<Void> { $0.reject(TaskExecutionTransactionError.blobEncryptFailed) }
        }
        
        if encryptedData.isEmpty {
            return Promise()
        }
        
        return firstly {
            uploadBlobs(blobs: encryptedData)
        }.then { [self] blobIDs -> Promise<Void> in
            for i in 0..<images.count {
                profilePictureBlobs[i].id = blobIDs[i] as! Data
            }
            
            for i in 0..<contactImages.count {
                contactProfilePictureBlobs[i].id = blobIDs[images.count + i] as! Data
            }
            return Promise()
        }
    }
    
    private func encrypt(dataArr: [Data?]) throws -> (encryptedData: [Data], blobs: [Common_Blob]) {
        var resultArr = [Data]()
        var blobs = [Common_Blob]()
        
        for contactProfilePicture in dataArr {
            guard let data = contactProfilePicture else {
                throw TaskExecutionTransactionError.blobEncryptFailed
            }
            let encrypted = try encrypt(data: data)
            var blob = Common_Blob()
            blob.nonce = encrypted.nonce
            blob.key = encrypted.key
            blobs.append(blob)
            resultArr.append(encrypted.payload)
        }
        return (resultArr, blobs)
    }
    
    private func encrypt(data: Data) throws -> (key: Data, nonce: Data, payload: Data) {
        guard let encryptionKey = NaClCrypto.shared()?.randomBytes(kBlobKeyLen) else {
            throw TaskExecutionTransactionError.blobEncryptFailed
        }
        let nonce = Data([
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        ]) // kNonce_1
        guard let encryptedProfileImageData = NaClCrypto.shared()?
            .symmetricEncryptData(data, withKey: encryptionKey, nonce: nonce) else {
            throw TaskExecutionTransactionError.blobUploadFailed
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
                if deltaSyncContact.image != nil {
                    var commonImage = Common_Image()
                    commonImage.blob = profilePictureBlobs.removeFirst()
                    syncContact.userDefinedProfilePicture.updated = commonImage
                }
            case .removed:
                syncContact.userDefinedProfilePicture.removed = Common_Unit()
            case .unchanged:
                break
            }

            switch deltaSyncContact.contactProfilePicture {
            case .updated:
                if deltaSyncContact.contactImage != nil {
                    var commonImage = Common_Image()
                    commonImage.blob = contactProfilePictureBlobs.removeFirst()
                    syncContact.contactDefinedProfilePicture.updated = commonImage
                }
            case .removed:
                syncContact.contactDefinedProfilePicture.removed = Common_Unit()
            case .unchanged:
                break
            }
            
            let envelope = frameworkInjector.mediatorMessageProtocol.getEnvelopeForContactSync(contact: syncContact)

            reflectResults.append(Promise<Void> { $0.fulfill(try reflectMessage(
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
        
        frameworkInjector.backgroundEntityManager.performBlockAndWait {
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
        
        guard let contact = frameworkInjector.backgroundEntityManager.entityFetcher
            .contact(for: sContact.identity) else {
            DDLogInfo("Contact was deleted. Do not sync")
            return false
        }
        
        let conversation = contact.conversations?.first as? Conversation
        
        let samePublicKey = (sContact.hasPublicKey && sContact.publicKey == contact.publicKey) || !sContact.hasPublicKey
        let sameVerificationLevel = (
            sContact.hasVerificationLevel && sContact.verificationLevel.rawValue == contact
                .verificationLevel.intValue
        ) || !sContact.hasVerificationLevel
        let sameWorkStatus = (
            sContact.hasIdentityType && sContact
                .identityType == (contact.workContact.intValue == 0 ? .regular : .work)
        ) || !sContact.hasIdentityType
        let sameAcquaintanceLevel = (
            sContact.hasAcquaintanceLevel && sContact
                .acquaintanceLevel == (contact.hidden.boolValue ? .group : .direct)
        ) || !sContact.hasAcquaintanceLevel
        
        let sameFirstname = (sContact.hasFirstName && sContact.firstName == contact.firstName ?? "") || !sContact
            .hasFirstName
        let sameLastname = (sContact.hasLastName && sContact.lastName == contact.lastName ?? "") || !sContact
            .hasLastName
        let sameNickname = (sContact.hasNickname && sContact.nickname == contact.publicNickname ?? "") || !sContact
            .hasNickname
        
        let sameProfilePictrue = (
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
                .rawValue == conversation?.conversationVisibility.rawValue ?? ConversationVisibility.default.rawValue
        ) || !sContact.hasConversationVisibility
        
        let allTrue = samePublicKey &&
            sameVerificationLevel &&
            sameWorkStatus &&
            sameAcquaintanceLevel &&
            sameImportStatus &&
            sameConversationCategory &&
            sameConversationVisibility &&
            sameFirstname &&
            sameLastname &&
            sameNickname &&
            sameProfilePictrue &&
            sameImage &&
            sameContactProfilePicture &&
            sameContactImage &&
            sameVerificationLevel
        
        return allTrue
    }
}
