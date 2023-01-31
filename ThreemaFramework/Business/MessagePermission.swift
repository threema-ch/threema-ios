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

public class MessagePermission: NSObject {
    public enum MessagePermissionError: Error {
        case conversationNotFound(for: String)
    }

    let myIdentityStore: MyIdentityStoreProtocol
    let userSettings: UserSettingsProtocol
    let groupManager: GroupManagerProtocol
    let entityManager: EntityManager

    @objc public required init(
        myIdentityStore: MyIdentityStoreProtocol,
        userSettings: UserSettingsProtocol,
        groupManager: GroupManagerProtocolObjc,
        entityManager: EntityManager
    ) {
        self.myIdentityStore = myIdentityStore
        self.userSettings = userSettings
        self.groupManager = groupManager as! GroupManagerProtocol
        self.entityManager = entityManager
    }

    /// Check can send message to contact.
    /// - Parameters:
    ///     - to: Receiver identity of the message
    /// - Returns: Is not isAllowed than reason is set to inform user
    public func canSend(to identity: String) -> (isAllowed: Bool, reason: String?) {
        var result: (isAllowed: Bool, reason: String?) = (false, nil)

        entityManager.performBlockAndWait {
            guard let conversation = self.entityManager.entityFetcher.conversation(forIdentity: identity) else {
                result = (false, "Conversation for contact (\(identity)) not found.")
                return
            }
            result = self.canSend(to: conversation)
        }

        return result
    }

    /// Check can send message to group.
    /// - Parameters:
    ///     - groupID: Group ID
    ///     - groupCreator: Group creator
    /// - Returns: Is not isAllowed than reason is set to inform user
    public func canSend(
        groudID: Data,
        groupCreatorIdentity: String
    ) -> (isAllowed: Bool, reason: String?) {
        var result: (isAllowed: Bool, reason: String?) = (false, nil)

        entityManager.performBlockAndWait {
            guard let conversation = self.groupManager.getGroup(groudID, creator: groupCreatorIdentity)?.conversation
            else {
                result = (
                    false,
                    "Conversation for group (id \(groudID.hexString) / group creator \(groupCreatorIdentity)) not found."
                )
                return
            }
            result = self.canSend(to: conversation)
        }

        return result
    }

    @objc func canSend(to identity: String, reason: UnsafeMutablePointer<NSString?>?) -> Bool {
        let result = canSend(to: identity)
        if let r = result.reason, let reason = reason {
            reason.pointee = r as NSString
        }
        return result.isAllowed
    }

    @objc func canSend(
        groupID: Data,
        groupCreatorIdentity: String,
        reason: UnsafeMutablePointer<NSString?>?
    ) -> Bool {
        let result = canSend(groudID: groupID, groupCreatorIdentity: groupCreatorIdentity)
        if let r = result.reason, let reason = reason {
            reason.pointee = r as NSString
        }
        return result.isAllowed
    }

    private func canSend(to conversation: Conversation) -> (isAllowed: Bool, reason: String?) {
        // Check for blacklisted contact
        if let identity = conversation.contact?.identity,
           conversation.groupID == nil,
           userSettings.blacklist.contains(identity) {
            DDLogError("Cannot send a message to this contact \(identity) because it is blocked")
            return (false, BundleUtil.localizedString(forKey: "contact_blocked_cannot_send"))
        }

        // Check that the group was started while we were using the same identity as now
        if let groupMyIdentity = conversation.groupMyIdentity,
           !groupMyIdentity.elementsEqual(myIdentityStore.identity) {
            DDLogError(
                "Cannot send a message to this group. This group was created while user were using a different Threema ID. Cannot send any messages to it with your current ID"
            )
            return (false, BundleUtil.localizedString(forKey: "group_different_identity"))
        }

        // Check for invalid contact
        if conversation.groupID == nil,
           let contact = conversation.contact,
           let state = contact.state,
           state.intValue == kStateInvalid {
            DDLogError("Cannot send a message to this contact (\(contact.identity) because it is invalid")
            return (false, BundleUtil.localizedString(forKey: "contact_invalid_cannot_send"))
        }

        // Check group state
        if let group = groupManager.getGroup(conversation: conversation) {

            // Not allowed for empty groups, exept i'm group creator because is a note group
            if group.allMemberIdentities.filter({ $0 != myIdentityStore.identity }).isEmpty,
               !group.isOwnGroup {
                DDLogError("Cannot send a message because there are no more members in this group")
                return (false, BundleUtil.localizedString(forKey: "no_more_members"))
            }

            if group.didLeave || group.didForcedLeave {
                DDLogError("Cannot send a message to this group because i left the group, i'm not a member anymore")
                return (false, BundleUtil.localizedString(forKey: "group_is_not_member"))
            }
        }

        return (true, nil)
    }
}
