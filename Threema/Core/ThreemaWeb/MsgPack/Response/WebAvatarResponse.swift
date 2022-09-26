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

class WebAvatarResponse: WebAbstractMessage {
    
    var type: String
    var id: String
    var highResolution: Bool
    
    var avatar: Data?
    
    init(request: WebAvatarRequest) {
        self.type = request.type
        self.id = request.id
        self.highResolution = request.highResolution
        
        var size = highResolution ? kWebClientAvatarHiResSize : kWebClientAvatarSize
        let quality = highResolution ? kWebClientAvatarHiResQuality : kWebClientAvatarQuality
        if request.maxSize != nil {
            size = request.maxSize!
        }
        
        let entityManager = EntityManager()
        if type == "contact" {
            let contact = entityManager.entityFetcher.contact(for: id)

            if contact != nil {
                if let avatarImage = AvatarMaker.shared()
                    .avatar(for: contact!, size: CGFloat(size), masked: false, scaled: false) {
                    self.avatar = avatarImage.jpegData(compressionQuality: CGFloat(quality))
                }
            }
        }
        else if type == "group" {
            let groupID = request.id.hexadecimal()
            let conversation = entityManager.entityFetcher.conversation(for: groupID)
            
            if conversation != nil {
                if let avatarImage = AvatarMaker.shared()
                    .avatar(for: conversation!, size: CGFloat(size), masked: false, scaled: false) {
                    self.avatar = avatarImage.jpegData(compressionQuality: CGFloat(quality))
                }
            }
        }
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id, "highResolution": highResolution]
        let tmpAck = request.requestID != nil ? WebAbstractMessageAcknowledgement(request.requestID, true, nil) : nil
        super.init(
            messageType: "response",
            messageSubType: "avatar",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: avatar != nil ? avatar : nil
        )
    }
    
    init(requestID: String?, group: Group) {
        self.type = "group"
        self.id = group.groupID.hexEncodedString()
        self.highResolution = false
        
        let size = highResolution ? kWebClientAvatarHiResSize : kWebClientAvatarSize
        let quality = highResolution ? kWebClientAvatarHiResQuality : kWebClientAvatarQuality
        
        if let avatarImage = AvatarMaker.shared()
            .avatar(for: group.conversation, size: CGFloat(size), masked: false, scaled: false) {
            self.avatar = avatarImage.jpegData(compressionQuality: CGFloat(quality))
        }
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id]
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        super.init(
            messageType: "update",
            messageSubType: "avatar",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: avatar != nil ? avatar : nil
        )
    }
    
    init(requestID: String?, contact: Contact) {
        self.type = "contact"
        self.id = contact.identity
        self.highResolution = false
        
        let size = highResolution ? kWebClientAvatarHiResSize : kWebClientAvatarSize
        let quality = highResolution ? kWebClientAvatarHiResQuality : kWebClientAvatarQuality
        
        if let avatarImage = AvatarMaker.shared()
            .avatar(for: contact, size: CGFloat(size), masked: false, scaled: false) {
            self.avatar = avatarImage.jpegData(compressionQuality: CGFloat(quality))
        }
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id]
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        super.init(
            messageType: "update",
            messageSubType: "avatar",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: avatar != nil ? avatar : nil
        )
    }
}
