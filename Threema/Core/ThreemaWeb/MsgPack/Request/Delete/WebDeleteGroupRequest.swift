//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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
        self.id = idString.hexadecimal()
        self.deleteType = message.args!["deleteType"] as! String
        super.init(message: message)
    }
    
    func deleteOrLeave() {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        let entityManager = EntityManager(withChildContextForBackgroundProcess: true)
        guard let conversation = entityManager.entityFetcher.legacyConversation(for: id) else {
            ack!.success = false
            ack!.error = "invalidGroup"
            return
        }
        
        if conversation.isGroup() {
            let groupManager = GroupManager(entityManager: entityManager)
            guard let group = groupManager.getGroup(conversation: conversation) else {
                ack!.success = false
                ack!.error = "invalidGroup"
                return
            }
            
            if group.didLeave, deleteType == "leave" {
                ack!.success = false
                ack!.error = "alreadyLeft"
                return
            }

            groupManager.leave(groupID: group.groupID, creator: group.groupCreatorIdentity, toMembers: nil)

            MessageDraftStore.deleteDraft(for: conversation)
            
            ack!.success = true
            
            if deleteType == "delete" {

                groupManager.dissolve(groupID: group.groupID, to: nil)

                entityManager.performSyncBlockAndSafe {
                    entityManager.entityDestroyer.deleteObject(object: conversation)
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
                return
            }
        }
        else {
            ack!.success = false
            ack!.error = "invalidGroup"
            return
        }
    }
}
