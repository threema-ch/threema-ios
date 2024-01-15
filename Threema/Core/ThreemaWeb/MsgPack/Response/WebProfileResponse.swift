//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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

class WebProfileResponse: WebAbstractMessage {
    
    var identity: String
    var publicKey: Data
    var publicNickname: String?
    var avatar: Data?
    
    init(requestID: String?) {
        self.identity = MyIdentityStore.shared().identity
        self.publicKey = MyIdentityStore.shared().publicKey
        
        if MyIdentityStore.shared().pushFromName != nil {
            self.publicNickname = MyIdentityStore.shared().pushFromName
        }
        else {
            self.publicNickname = MyIdentityStore.shared().identity
        }
        
        if let profilePicture = MyIdentityStore.shared().profilePicture,
           profilePicture["ProfilePicture"] != nil {
            
            self.avatar = profilePicture["ProfilePicture"] as? Data
        }
        
        var tmpData: [AnyHashable: Any?] = [
            "identity": identity,
            "publicKey": publicKey,
            "publicNickname": publicNickname,
        ]
        
        if avatar != nil {
            tmpData.updateValue(avatar!, forKey: "avatar")
        }
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        super.init(
            messageType: "response",
            messageSubType: "profile",
            requestID: nil,
            ack: tmpAck,
            args: nil,
            data: tmpData
        )
    }
}
