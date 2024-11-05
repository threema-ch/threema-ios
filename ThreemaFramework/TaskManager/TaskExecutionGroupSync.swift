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
import PromiseKit
import ThreemaEssentials
import ThreemaProtocols

final class TaskExecutionGroupSync: TaskExecutionBlobTransaction {

    override func executeTransaction() throws -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionGroupSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        return try uploadBlob(data: task.image)
            .then { blob in
                try task.checkDropping()

                switch task.profilePicture {
                case .updated:
                    if let blob {
                        var commonImage = Common_Image()
                        commonImage.blob = blob
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

                let envelope = self.frameworkInjector.mediatorMessageProtocol.getEnvelopeForGroupSync(
                    group: task.syncGroup,
                    syncAction: syncAction
                )

                try self.reflectMessage(
                    envelope: envelope,
                    ltReflect: self.taskContext.logReflectMessageToMediator,
                    ltAck: self.taskContext.logReceiveMessageAckFromMediator
                )

                return Promise()
            }
    }

    override func checkPreconditions() throws -> Bool {
        guard let task = taskDefinition as? TaskDefinitionGroupSync else {
            throw TaskExecutionError.wrongTaskDefinitionType
        }

        let groupIdentity = GroupIdentity(
            id: task.syncGroup.groupIdentity.groupID.littleEndianData,
            creator: ThreemaIdentity(task.syncGroup.groupIdentity.creatorIdentity)
        )

        guard task.syncAction != .delete else {
            guard let groupEntity = frameworkInjector.entityManager.entityFetcher.groupEntity(
                for: groupIdentity.id,
                with: groupIdentity.creator.string
            ) else {
                return true
            }
            return groupEntity.state.intValue == GroupEntity.GroupState.left.rawValue
        }

        guard let group = frameworkInjector.groupManager.getGroup(
            groupIdentity.id,
            creator: groupIdentity.creator.string
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
            ) && group.old_ProfilePicture != nil)
                ||
                ((
                    task.profilePicture == .removed
                        || task.profilePicture == .unchanged
                ) && group.old_ProfilePicture == nil)
        )

        var sameImage = false
        if let image = group.old_ProfilePicture {
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

        var category: ConversationEntity.Category?
        var visibility: ConversationEntity.Visibility?
        frameworkInjector.entityManager.performAndWaitSave {
            let conversation = self.frameworkInjector.entityManager.entityFetcher.conversationEntity(
                for: group.groupID,
                creator: group.groupCreatorIdentity
            )
            category = conversation?.conversationCategory
            visibility = conversation?.conversationVisibility
        }

        let sameConversationCategory = (
            task.syncGroup.hasConversationCategory && task.syncGroup.conversationCategory
                .rawValue == category?.rawValue ?? ConversationEntity.Category.default.rawValue
        ) || !task.syncGroup.hasConversationCategory

        let sameConversationVisibility = (
            task.syncGroup.hasConversationVisibility && task.syncGroup.conversationVisibility
                .rawValue == visibility?.rawValue ?? ConversationEntity.Visibility.default.rawValue
        ) || !task.syncGroup.hasConversationVisibility

        return sameMembers && sameName && sameProfilePicture && sameImage && sameState && sameConversationCategory &&
            sameConversationVisibility
    }

    override func writeLocal() -> Promise<Void> {
        DDLogInfo("Group sync writes local data immediately")
        return Promise()
    }
}
