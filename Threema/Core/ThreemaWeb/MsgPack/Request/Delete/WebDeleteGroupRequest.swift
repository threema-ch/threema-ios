//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

import CocoaLumberjack
import Foundation
import ThreemaFramework

class WebDeleteGroupRequest: WebAbstractMessage {
    
    var id: Data?
    let deleteType: String
    
    override init(message: WebAbstractMessage) {

        let idString = message.args!["id"] as! String
        self.id = idString.hexadecimal
        self.deleteType = message.args!["deleteType"] as! String
        super.init(message: message)
    }
    
    func deleteOrLeave() {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        let backgroundBusinessInjector = BusinessInjector(forBackgroundProcess: true)
        let entityManager = backgroundBusinessInjector.entityManager

        let id = id
        let deleteType = deleteType
        let result: Result<(ConversationEntity, Group), WebRequestError> = entityManager.performAndWait {
            guard let conversation = entityManager.entityFetcher
                .legacyConversationEntity(for: id)
            else {
                return .failure(WebRequestError(message: "invalidGroup"))
            }

            guard conversation.isGroup else {
                return .failure(WebRequestError(message: "invalidGroup"))
            }

            guard let group = backgroundBusinessInjector.groupManager.getGroup(conversation: conversation) else {
                return .failure(WebRequestError(message: "invalidGroup"))
            }

            if group.didLeave, deleteType == "leave" {
                return .failure(WebRequestError(message: "alreadyLeft"))
            }

            return .success((conversation, group))
        }

        guard case let .success((conversation, group)) = result else {
            if case let .failure(error) = result {
                ack!.success = false
                ack!.error = error.message
            }
            return
        }

        backgroundBusinessInjector.groupManager.leave(groupIdentity: group.groupIdentity, toMembers: nil)

        MessageDraftStore.shared.deleteDraft(for: conversation)

        ack!.success = true

        if deleteType == "delete" {
            backgroundBusinessInjector.groupManager.dissolve(groupID: group.groupID, to: nil)

            entityManager.performAndWaitSave {
                MessageDraftStore.shared.deleteDraft(for: conversation)
                entityManager.entityDestroyer.delete(conversation: conversation)
            }

            DispatchQueue.main.async {
                let notificationManager = NotificationManager()
                notificationManager.updateUnreadMessagesCount()

                let info = [kKeyConversation: conversation]
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: kNotificationDeletedConversation),
                    object: nil,
                    userInfo: info
                )
            }
        }
        else {
            ack!.success = false
            ack!.error = "badRequest"
        }
    }
}
