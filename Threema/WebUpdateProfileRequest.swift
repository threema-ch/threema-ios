//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

class WebUpdateProfileRequest: WebAbstractMessage {
    
    var nickName: String?
    var avatar: Data?
    
    var deleteNickName: Bool = false
    var deleteAvatar: Bool = false
    
    override init(message:WebAbstractMessage) {
        let data = message.data as! [AnyHashable: Any?]
        nickName = data["publicNickname"] as? String
        avatar = data["avatar"] as? Data
        
        if data["publicNickname"] != nil {
            if nickName == nil {
                deleteNickName = true
            }
        }
        
        if data["avatar"] != nil {
            if avatar == nil {
                deleteAvatar = true
            } else {
                let image = UIImage.init(data: avatar!)
                if image!.size.width >= CGFloat(kContactImageSize) || image!.size.height >= CGFloat(kContactImageSize) {
                    avatar = MediaConverter.scaleImageData(to: avatar!, toMaxSize: CGFloat(kContactImageSize), useJPEG: false)
                }
            }
        }
        super.init(message: message)
    }
    
    func updateProfile() {
        ack = WebAbstractMessageAcknowledgement.init(requestId, false, nil)
        if deleteNickName {
            MyIdentityStore.shared().pushFromName = nil
            LicenseStore.shared().performUpdateWorkInfo()
        } else {
            if nickName != nil {
                if nickName!.lengthOfBytes(using: .utf8) > 32 {
                    ack!.success = false
                    ack!.error = "valueTooLong"
                    return
                }
                MyIdentityStore.shared().pushFromName = nickName
                LicenseStore.shared().performUpdateWorkInfo()
            }
        }
        
        if avatar == nil && !deleteAvatar {
            ack!.success = true
            return
        }
        
        AvatarMaker.shared().clearCacheForProfilePicture()
        var profile = MyIdentityStore.shared().profilePicture
        
        if profile == nil {
            profile = [:]
        }
        
        if (avatar == profile!["ProfilePicture"] as? Data) {
            ack!.success = true
            return
        }
        
        profile?.setValue(avatar, forKey: "ProfilePicture")
        profile?.removeObject(forKey: "LastUpload")
        MyIdentityStore.shared().profilePicture = profile
        ContactStore.shared().removeProfilePictureFlagForAllContacts()
        ack!.success = true
    }
}
