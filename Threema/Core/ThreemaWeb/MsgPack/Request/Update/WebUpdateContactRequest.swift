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

class WebUpdateContactRequest: WebAbstractMessage {
    
    let identity: String
    
    var firstName: String?
    var lastName: String?
    var avatar: Data?
    var deleteAvatar = false
    
    var contact: Contact?
    
    override init(message: WebAbstractMessage) {
        
        self.identity = message.args!["identity"] as! String
        
        if let data = message.data as? [AnyHashable: Any?] {
            self.firstName = data["firstName"] as? String
            self.lastName = data["lastName"] as? String
            self.avatar = data["avatar"] as? Data
            
            if data["avatar"] != nil {
                if avatar == nil {
                    self.deleteAvatar = true
                }
                else {
                    let image = UIImage(data: avatar!)
                    if image!.size.width >= CGFloat(kContactImageSize) || image!.size
                        .height >= CGFloat(kContactImageSize) {
                        self.avatar = MediaConverter.scaleImageData(
                            to: avatar!,
                            toMaxSize: CGFloat(kContactImageSize),
                            useJPEG: false
                        )
                    }
                }
            }
        }
        super.init(message: message)
    }
    
    func updateContact() {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        let entityManager = EntityManager()
        let updatedContact = entityManager.entityFetcher.contact(for: identity)
        
        if firstName != nil {
            if firstName!.lengthOfBytes(using: .utf8) > 256 {
                ack!.success = false
                ack!.error = "valueTooLong"
                contact = updatedContact
                return
            }
        }
        if lastName != nil {
            if lastName!.lengthOfBytes(using: .utf8) > 256 {
                ack!.success = false
                ack!.error = "valueTooLong"
                contact = updatedContact
                return
            }
        }
        
        entityManager.performSyncBlockAndSafe {
            updatedContact?.firstName = self.firstName
            updatedContact?.lastName = self.lastName
            
            if self.avatar != nil || self.deleteAvatar == true {
                updatedContact?.imageData = self.avatar
            }
        }
        contact = updatedContact
        ack!.success = true
    }
}
