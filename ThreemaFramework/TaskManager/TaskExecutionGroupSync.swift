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

class TaskExecutionGroupSync: TaskExecutionBlobTransaction {
    var profilePictureBlob: Common_Blob?

    override func prepare() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionGroupSync else {
            return Promise<Void> { $0.reject(TaskExecutionError.wrongTaskDefinitionType) }
        }

        if let image = task.profilePicture == .updated ? task.image : nil {
            var encryptedData: Data!

            do {
                let encrypted = try encrypt(data: image)

                profilePictureBlob = Common_Blob()
                profilePictureBlob?.nonce = encrypted.nonce
                profilePictureBlob?.key = encrypted.key

                encryptedData = encrypted.payload
            }
            catch {
                return Promise<Void> { $0.reject(TaskExecutionTransactionError.blobEncryptFailed) }
            }

            if encryptedData.isEmpty {
                return Promise()
            }

            return firstly {
                uploadBlobs(blobs: [encryptedData])
            }.then { [self] blobIDs -> Promise<Void> in
                profilePictureBlob?.id = blobIDs.first as! Data
                return Promise()
            }
        }
        else {
            return Promise()
        }
    }

    private func encrypt(data: Data) throws -> (key: Data, nonce: Data, payload: Data) {
        guard let encryptionKey = NaClCrypto.shared()?.randomBytes(kBlobKeyLen) else {
            throw TaskExecutionTransactionError.blobEncryptFailed
        }
        let nonce = ThreemaProtocol.nonce01
        guard let encryptedProfileImageData = NaClCrypto.shared()?
            .symmetricEncryptData(data, withKey: encryptionKey, nonce: nonce) else {
            throw TaskExecutionTransactionError.blobUploadFailed
        }
        return (encryptionKey, nonce, encryptedProfileImageData)
    }

    override func reflectTransactionMessages() throws -> [Promise<Void>] {
        guard let task = taskDefinition as? TaskDefinitionGroupSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        switch task.profilePicture {
        case .updated:
            if let profilePictureBlob = profilePictureBlob {
                var commonImage = Common_Image()
                commonImage.blob = profilePictureBlob
                task.syncGroup.profilePicture.updated = commonImage
            }
        case .removed:
            task.syncGroup.profilePicture.removed = Common_Unit()
        case .unchanged:
            break
        }

        var syncAction: D2d_GroupSync.OneOf_Action!
        switch task.syncAction {
        case .create:
            var create = D2d_GroupSync.Create()
            create.group = task.syncGroup
            syncAction = .create(create)
        case .delete:
            var delete = D2d_GroupSync.Delete()
            delete.groupIdentity = task.syncGroup.groupIdentity
            syncAction = .delete(delete)
        case .update:
            var update = D2d_GroupSync.Update()
            update.group = task.syncGroup
            syncAction = .update(update)
        }

        let envelope = frameworkInjector.mediatorMessageProtocol.getEnvelopeForGroupSync(
            group: task.syncGroup,
            syncAction: syncAction
        )

        return [
            Promise<Void> { $0.fulfill(
                try reflectMessage(
                    envelope: envelope,
                    ltReflect: self.taskContext.logReflectMessageToMediator,
                    ltAck: self.taskContext.logReceiveMessageAckFromMediator
                )
            ) },
        ]
    }

    override func checkPreconditions() throws -> Bool {
        guard let task = taskDefinition as? TaskDefinitionGroupSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        let groupIdentity = GroupIdentity(
            id: NSData.convertBytes(task.syncGroup.groupIdentity.groupID),
            creator: task.syncGroup.groupIdentity.creatorIdentity
        )

        guard task.syncAction != .delete else {
            guard let groupEntity = frameworkInjector.entityManager.entityFetcher.groupEntity(
                for: groupIdentity.id,
                with: groupIdentity.creator
            ) else {
                return true
            }
            return groupEntity.state.intValue == GroupState.left.rawValue
        }

        guard let group = frameworkInjector.backgroundGroupManager.getGroup(
            groupIdentity.id,
            creator: groupIdentity.creator
        ) else {
            DDLogWarn("Group was deleted. Do not sync")
            return false
        }

        let sameMembers = (
            task.syncGroup.hasMemberIdentities && task.syncGroup.memberIdentities
                .identities.sorted() == Array(group.allMemberIdentities).sorted()
        ) || !task.syncGroup.hasMemberIdentities

        let sameName = (task.syncGroup.hasName && task.syncGroup.name == group.name) || !task.syncGroup.hasName

        let sameProfilePicture = (
            ((
                task.profilePicture == .updated
                    || task.profilePicture == .unchanged
            ) && group.photo != nil)
                ||
                ((
                    task.profilePicture == .removed
                        || task.profilePicture == .unchanged
                ) && group.photo == nil)
        )

        var sameImage = false
        if let image = group.photo?.data {
            sameImage = task.profilePicture == .updated ? task
                .image == image : task.profilePicture == .unchanged
        }
        else {
            sameImage = task.profilePicture == .removed || task
                .profilePicture == .unchanged
        }

        let sameState = (
            task.syncGroup.hasUserState &&
                (
                    task.syncGroup.userState == .kicked && group.state == .forcedLeft ||
                        task.syncGroup.userState == .left && group.state == .left ||
                        task.syncGroup.userState == .member && group.state == .active
                )
        ) || !task.syncGroup.hasUserState

        var category: ConversationCategory?
        var visibility: ConversationVisibility?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            let conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher.conversation(
                for: group.groupID,
                creator: group.groupCreatorIdentity
            )
            category = conversation?.conversationCategory
            visibility = conversation?.conversationVisibility
        }

        let sameConversationCategory = (
            task.syncGroup.hasConversationCategory && task.syncGroup.conversationCategory
                .rawValue == category?.rawValue ?? ConversationCategory.default.rawValue
        ) || !task.syncGroup.hasConversationCategory

        let sameConversationVisibility = (
            task.syncGroup.hasConversationVisibility && task.syncGroup.conversationVisibility
                .rawValue == visibility?.rawValue ?? ConversationVisibility.default.rawValue
        ) || !task.syncGroup.hasConversationVisibility

        return sameMembers && sameName && sameProfilePicture && sameImage && sameState && sameConversationCategory &&
            sameConversationVisibility
    }

    override func writeLocal() -> Promise<Void> {
        DDLogInfo("Group sync writes local data immediately")
        return Promise()
    }
}
