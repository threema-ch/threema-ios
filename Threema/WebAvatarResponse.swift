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

class WebAvatarResponse: WebAbstractMessage {
    
    var type: String
    var id: String
    var highResolution: Bool
    
    var avatar: Data?
    
    init(request: WebAvatarRequest) {
        type = request.type
        id = request.id
        highResolution = request.highResolution
        
        var size = highResolution ? kWebClientAvatarHiResSize : kWebClientAvatarSize
        let quality = highResolution ? kWebClientAvatarHiResQuality : kWebClientAvatarQuality
        if request.maxSize != nil {
            size = request.maxSize!
        }
        
        let entityManager = EntityManager()
        if type == "contact" {
            let contact = entityManager.entityFetcher.contact(forId: id)

            if contact != nil {
                if let avatarImage = AvatarMaker.shared().avatar(for: contact!, size: CGFloat(size), masked: false, scaled: false) {
                    avatar = avatarImage.jpegData(compressionQuality: CGFloat(quality))
                }
            }
        }
        else if type == "group" {
            let groupId = request.id.hexadecimal()
            let conversation = entityManager.entityFetcher.conversation(forGroupId: groupId)
            
            if conversation != nil {
                if let avatarImage = AvatarMaker.shared().avatar(for: conversation!, size: CGFloat(size), masked: false, scaled: false) {
                    avatar = avatarImage.jpegData(compressionQuality: CGFloat(quality))
                }
            }
        }
        
        let tmpArgs:[AnyHashable:Any?] = ["type": type, "id": id, "highResolution": highResolution]
        let tmpAck = request.requestId != nil ? WebAbstractMessageAcknowledgement.init(request.requestId, true, nil) : nil
        super.init(messageType: "response", messageSubType: "avatar", requestId: nil, ack: tmpAck, args: tmpArgs, data: avatar != nil ? avatar : nil)
    }
    
    init(requestId: String?, groupProxy: GroupProxy) {
        type = "group"
        id = groupProxy.groupId.hexEncodedString()
        highResolution = false
        
        let size = highResolution ? kWebClientAvatarHiResSize : kWebClientAvatarSize
        let quality = highResolution ? kWebClientAvatarHiResQuality : kWebClientAvatarQuality
        
        if let avatarImage = AvatarMaker.shared().avatar(for: groupProxy.conversation(), size: CGFloat(size), masked: false, scaled: false) {
            avatar = avatarImage.jpegData(compressionQuality: CGFloat(quality))
        }
        
        let tmpArgs:[AnyHashable:Any?] = ["type": type, "id": id]
        let tmpAck = requestId != nil ? WebAbstractMessageAcknowledgement.init(requestId, true, nil) : nil
        super.init(messageType: "update", messageSubType: "avatar", requestId: nil, ack: tmpAck, args: tmpArgs, data: avatar != nil ? avatar : nil)
    }
    
    init(requestId: String?, contact: Contact) {
        type = "contact"
        id = contact.identity
        highResolution = false
        
        let size = highResolution ? kWebClientAvatarHiResSize : kWebClientAvatarSize
        let quality = highResolution ? kWebClientAvatarHiResQuality : kWebClientAvatarQuality
        
        if let avatarImage = AvatarMaker.shared().avatar(for: contact, size: CGFloat(size), masked: false, scaled: false) {
            avatar = avatarImage.jpegData(compressionQuality: CGFloat(quality))
        }
        
        let tmpArgs:[AnyHashable:Any?] = ["type": type, "id": id]
        let tmpAck = requestId != nil ? WebAbstractMessageAcknowledgement.init(requestId, true, nil) : nil
        super.init(messageType: "update", messageSubType: "avatar", requestId: nil, ack: tmpAck, args: tmpArgs, data: avatar != nil ? avatar : nil)
    }
}

