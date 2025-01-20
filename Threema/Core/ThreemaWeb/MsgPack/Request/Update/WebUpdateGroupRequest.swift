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

import CocoaLumberjackSwift
import Foundation

class WebUpdateGroupRequest: WebAbstractMessage {
    
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
    
    func updateGroup(completion: @escaping () -> Void) {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        DispatchQueue.main.sync {
            let businessInjector = BusinessInjector()
            guard let conversation = businessInjector.entityManager.entityFetcher.legacyConversation(for: id) else {
                ack!.success = false
                ack!.error = "invalidGroup"
                completion()
                return
            }

            guard let group = businessInjector.groupManager.getGroup(conversation: conversation) else {
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
            
            if self.name != nil {
                if self.name!.lengthOfBytes(using: .utf8) > 256 {
                    self.ack!.success = false
                    self.ack!.error = "valueTooLong"
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

                completion()
            }
        }
    }
}
