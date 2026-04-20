import Foundation

final class WebProfileUpdate: WebAbstractMessage {
    
    var nickname: String?
    var avatar: Data?
    
    init(nicknameChanged: Bool, newNickname: String?, newAvatar: Data?, deleteAvatar: Bool) {
        var tmpData = [AnyHashable: Any?]()
        if newNickname != nil {
            self.nickname = newNickname!
            tmpData.updateValue(nickname, forKey: "publicNickname")
        }
        else {
            if nicknameChanged == true {
                self.nickname = ""
                tmpData.updateValue(nickname, forKey: "publicNickname")
            }
        }
        if newAvatar != nil {
            let avatarImage = UIImage(data: newAvatar!)
            self.avatar = avatarImage!.jpegData(compressionQuality: CGFloat(kWebClientAvatarHiResQuality))!
            tmpData.updateValue(avatar, forKey: "avatar")
        }
        else if deleteAvatar == true {
            tmpData.updateValue(nil, forKey: "avatar")
        }
        
        super.init(messageType: "update", messageSubType: "profile", requestID: nil, ack: nil, args: nil, data: tmpData)
    }
}
