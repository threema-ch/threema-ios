//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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
    
    var identity: String?
    var groupID: Data?
    let type: String
    
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        
        if type == "contact" {
            self.identity = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as? String
            self.groupID = idString?.hexadecimal()
        }
        
        super.init(message: message)
    }
    
    func clean() {
        DispatchQueue.main.sync {
            let entityManager = EntityManager()
            
            if identity != nil {
                let conversation = entityManager.entityFetcher.conversation(forIdentity: identity)
                entityManager.performSyncBlockAndSafe {
                    entityManager.entityDestroyer.deleteObject(object: conversation!)
                }
            }
            else if groupID != nil {
                if let conversation = entityManager.entityFetcher.conversation(for: groupID) {
                    entityManager.performSyncBlockAndSafe {
                        var imageData: Data?
                        var imageHeight: NSNumber?
                        var imageWidth: NSNumber?
                        
                        if let groupImage = conversation.groupImage {
                            imageData = groupImage.data
                            imageHeight = groupImage.height
                            imageWidth = groupImage.width
                        }
                        
                        entityManager.entityDestroyer.deleteObject(object: conversation)
                        
                        let tmpConversation = entityManager.entityCreator.conversation()
                        tmpConversation?.contact = conversation.contact
                        tmpConversation?.members = conversation.members
                        tmpConversation?.groupID = conversation.groupID
                        tmpConversation?.groupName = conversation.groupName
                        tmpConversation?.groupMyIdentity = conversation.groupMyIdentity
                        
                        if imageData != nil {
                            let tmpImageData = entityManager.entityCreator.imageData()
                            tmpImageData?.data = imageData
                            tmpImageData?.height = imageHeight ?? 0.0
                            tmpImageData?.width = imageWidth ?? 0.0
                            tmpConversation?.groupImage = tmpImageData
                            tmpConversation?.groupImageSetDate = conversation.groupImageSetDate
                        }
                    }
                }
            }
        }
    }
}
