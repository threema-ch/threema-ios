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
        
        let businessInjector = BusinessInjector()
        let entityManager = businessInjector.entityManager
        
        if type == "contact", let contact = entityManager.entityFetcher.contact(for: id) {
            let businessContact = Contact(contactEntity: contact)
            self.avatar = businessContact.profilePicture.resizedImage(newSize: CGSize(
                width: size,
                height: size
            )).jpegData(compressionQuality: CGFloat(quality))
        }
        else if type == "group" {
            let groupID = request.id.hexadecimal
            let conversation = entityManager.entityFetcher.legacyConversation(for: groupID)
            
            if let conversation, let group = businessInjector.groupManager.getGroup(conversation: conversation) {
                self.avatar = group.profilePicture.resizedImage(newSize: CGSize(width: size, height: size))
                    .jpegData(compressionQuality: CGFloat(quality))
            }
        }
        else {
            self.avatar = ProfilePictureGenerator.unknownContactImage.resizedImage(newSize: CGSize(
                width: size,
                height: size
            ))
            .jpegData(compressionQuality: CGFloat(quality))
        }
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id, "highResolution": highResolution]
        let tmpAck = request.requestID != nil ? WebAbstractMessageAcknowledgement(request.requestID, true, nil) : nil
        super.init(
            messageType: "response",
            messageSubType: "avatar",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: avatar
        )
    }
    
    init(requestID: String?, group: Group) {
        self.type = "group"
        self.id = group.groupID.hexEncodedString()
        self.highResolution = false
        
        let size = highResolution ? kWebClientAvatarHiResSize : kWebClientAvatarSize
        let quality = highResolution ? kWebClientAvatarHiResQuality : kWebClientAvatarQuality
        
        self.avatar = group.profilePicture.resizedImage(newSize: CGSize(width: size, height: size))
            .jpegData(compressionQuality: CGFloat(quality))
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id]
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        super.init(
            messageType: "update",
            messageSubType: "avatar",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: avatar
        )
    }
    
    init(requestID: String?, contact: ContactEntity) {
        self.type = "contact"
        self.id = contact.identity
        self.highResolution = false
        
        let size = highResolution ? kWebClientAvatarHiResSize : kWebClientAvatarSize
        let quality = highResolution ? kWebClientAvatarHiResQuality : kWebClientAvatarQuality
        
        let businessContact = Contact(contactEntity: contact)
        self.avatar = businessContact.profilePicture.resizedImage(newSize: CGSize(width: size, height: size))
            .jpegData(compressionQuality: CGFloat(quality))
        
        let tmpArgs: [AnyHashable: Any?] = ["type": type, "id": id]
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        
        super.init(
            messageType: "update",
            messageSubType: "avatar",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: avatar
        )
    }
}
