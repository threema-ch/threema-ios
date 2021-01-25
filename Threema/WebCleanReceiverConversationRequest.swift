//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

import Foundation

class WebCleanReceiverConversationRequest: WebAbstractMessage {
    
    var identity: String? = nil
    var groupId: Data? = nil
    let type: String
    
    override init(message:WebAbstractMessage) {
        type = message.args!["type"] as! String
        
        if type == "contact" {
            identity = message.args!["id"] as? String
        } else {
            let idString = message.args!["id"] as? String
            groupId = idString?.hexadecimal()
        }
        
        super.init(message: message)
    }
    
    func clean() {
        DispatchQueue.main.sync {
            let entityManager = EntityManager()
            
            if identity != nil {
                let conversation = entityManager.entityFetcher.conversation(forIdentity: identity)
                entityManager.performSyncBlockAndSafe({
                    entityManager.entityDestroyer.deleteObject(object: conversation!)
                })
            }
            else if groupId != nil {
                let conversation = entityManager.entityFetcher.conversation(forGroupId: groupId)
                let groupProxy = GroupProxy.init(for: conversation, entityManager: entityManager)
                
                if groupProxy != nil {
                    var tmpConversation: Conversation? = nil
                    entityManager.performSyncBlockAndSafe({
                        var imageData: Data? = nil
                        var imageHeight: NSNumber? = nil
                        var imageWidth: NSNumber? = nil
                        
                        if conversation?.groupImage != nil {
                            imageData = conversation?.groupImage.data
                            imageHeight = conversation?.groupImage.height
                            imageWidth = conversation?.groupImage.width
                        }
                        
                        entityManager.entityDestroyer.deleteObject(object: conversation!)
                        
                        tmpConversation = entityManager.entityCreator.conversation()
                        tmpConversation?.contact = conversation?.contact
                        tmpConversation?.members = conversation?.members
                        tmpConversation?.groupId = conversation?.groupId
                        tmpConversation?.groupName = conversation?.groupName
                        tmpConversation?.groupMyIdentity = conversation?.groupMyIdentity
                        
                        if imageData != nil {
                            let tmpImageData = entityManager.entityCreator.imageData()
                            tmpImageData?.data = imageData
                            tmpImageData?.height = imageHeight ?? 0.0
                            tmpImageData?.width = imageWidth ?? 0.0
                            tmpConversation?.groupImage = tmpImageData
                            tmpConversation?.groupImageSetDate = conversation?.groupImageSetDate
                        }
                    })
                }
            }
        }
    }
}
