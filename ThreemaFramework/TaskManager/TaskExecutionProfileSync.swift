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

/// Reflect my profile data to mediator server.
final class TaskExecutionProfileSync: TaskExecutionBlobTransaction {

    override func prepare() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionProfileSync else {
            return Promise<Void> { $0.reject(TaskExecutionError.wrongTaskDefinitionType) }
        }

        if task.syncUserProfile.hasProfilePicture {
            switch task.syncUserProfile.profilePicture.image {
            case .removed:
                break
            case .updated:
                let encryptionKey = NaClCrypto.shared()?.randomBytes(kBlobKeyLen)
                let nonce = ThreemaProtocol.nonce01
                let encryptedProfileImageData = NaClCrypto.shared()?.symmetricEncryptData(
                    task.profileImage,
                    withKey: encryptionKey,
                    nonce: nonce
                )

                return uploadBlobs(blobs: [encryptedProfileImageData!])
                    .then { blobIDs -> Promise<Void> in
                        if let blobID = blobIDs.first {
                            task.syncUserProfile.profilePicture.updated.blob = Common_Blob()
                            task.syncUserProfile.profilePicture.updated.blob.id = blobID
                            task.syncUserProfile.profilePicture.updated.blob.key = encryptionKey!
                            task.syncUserProfile.profilePicture.updated.blob.nonce = nonce

                            return Promise()
                        }
                        else {
                            throw TaskExecutionTransactionError.blobIDMissing
                        }
                    }
            case .none:
                break
            }
        }

        return Promise()
    }
    
    override func reflectTransactionMessages() throws -> [Promise<Void>] {
        guard let task = taskDefinition as? TaskDefinitionProfileSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }
        
        let envelope = frameworkInjector.mediatorMessageProtocol.getEnvelopeForProfileUpdate(
            userProfile: task.syncUserProfile
        )
        
        return [Promise { try $0.fulfill(_ = reflectMessage(
            envelope: envelope,
            ltReflect: self.taskContext.logReflectMessageToMediator,
            ltAck: self.taskContext.logReceiveMessageAckFromMediator
        )) }]
    }
    
    override func shouldSkip() throws -> Bool {
        guard let task = taskDefinition as? TaskDefinitionProfileSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        // Skip if nothing has changed
        return !(
            task.syncUserProfile.hasIdentityLinks
                || task.syncUserProfile.hasNickname
                || task.syncUserProfile.hasProfilePicture
                || task.syncUserProfile.hasProfilePictureShareWith
        )
    }

    override func writeLocal() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionProfileSync else {
            return Promise<Void> { $0.reject(TaskExecutionError.wrongTaskDefinitionType) }
        }

        let profileStore = ProfileStore(
            serverConnector: frameworkInjector.serverConnector,
            myIdentityStore: frameworkInjector.myIdentityStore,
            contactStore: frameworkInjector.contactStore,
            userSettings: frameworkInjector.userSettings,
            taskManager: nil
        )
        profileStore.save(
            syncUserProfile: task.syncUserProfile,
            profileImage: task.profileImage,
            isLinkMobileNoPending: task.linkMobileNoPending,
            isLinkEmailPending: task.linkEmailPending
        )

        return Promise()
    }
}
