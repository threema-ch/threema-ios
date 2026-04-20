import CocoaLumberjackSwift
import Foundation

final class WebUpdateGroupRequest: WebAbstractMessage {
    
    let id: Data
    
    var members: [String]
    var name: String?
    var avatar: Data?
    
    var deleteName = false
    var deleteAvatar = false
    
    var group: Group?
    
    override init(message: WebAbstractMessage) {
        let idString = message.args!["id"] as! String
        self.id = idString.hexadecimal!
        
        let data = message.data as! [AnyHashable: Any?]
        self.members = data["members"] as! [String]
        self.name = data["name"] as? String
        self.avatar = data["avatar"] as? Data
        
        if data["name"] != nil {
            if name == nil {
                self.deleteName = true
            }
        }
        
        if data["avatar"] != nil {
            if avatar == nil {
                self.deleteAvatar = true
            }
            else {
                let image = UIImage(data: avatar!)
                if image!.size.width >= CGFloat(kContactImageSize) || image!.size.height >= CGFloat(kContactImageSize) {
                    self.avatar = MediaConverter.scaleImageData(
                        to: avatar!,
                        toMaxSize: CGFloat(kContactImageSize),
                        useJPEG: false
                    )
                }
            }
        }
        super.init(message: message)
    }
    
    func updateGroup(completion: @escaping @Sendable () -> Void) {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        let businessInjector = BusinessInjector.ui

        let id = id
        let group: Group? = businessInjector.entityManager.performAndWait {
            guard let conversation = businessInjector.entityManager.entityFetcher
                .legacyConversationEntity(for: id) else {
                return nil
            }
            return businessInjector.groupManager.getGroup(conversation: conversation)
        }

        guard let group else {
            ack!.success = false
            ack!.error = "invalidGroup"
            completion()
            return
        }

        self.group = group

        if members.isEmpty {
            ack!.success = false
            ack!.error = "noMembers"
            completion()
            return
        }

        if !group.isOwnGroup {
            ack!.success = false
            ack!.error = "notAllowed"
            completion()
            return
        }

        if name != nil {
            if name!.lengthOfBytes(using: .utf8) > 256 {
                ack!.success = false
                ack!.error = "valueTooLong"
                completion()
                return
            }
        }

        Task {
            do {
                let (group, _) = try await businessInjector.groupManager.createOrUpdate(
                    for: group.groupIdentity,
                    members: Set<String>(members),
                    systemMessageDate: Date()
                )

                if self.deleteName || self.name != nil {
                    try await businessInjector.groupManager.setName(
                        group: group,
                        name: self.name
                    )
                }

                if !self.deleteAvatar,
                   let photo = self.avatar {
                    try await businessInjector.groupManager.setPhoto(
                        group: group,
                        imageData: photo,
                        sentDate: Date()
                    )
                }

                self.ack!.success = true
            }
            catch {
                DDLogError("Could not update group members: \(error)")
                self.ack!.success = false
                self.ack!.error = "internalError"
            }

            await MainActor.run {
                completion()
            }
        }
    }
}
