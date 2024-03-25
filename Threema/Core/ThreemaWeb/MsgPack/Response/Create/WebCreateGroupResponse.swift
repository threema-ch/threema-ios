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

import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
import ThreemaFramework

class WebCreateGroupResponse: WebAbstractMessage {
    
    var groupRequest: WebCreateGroupRequest
    
    init(request: WebCreateGroupRequest) {
        self.groupRequest = request
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, true, nil)
        
        super.init(messageType: "create", messageSubType: "group", requestID: nil, ack: tmpAck, args: nil, data: nil)
    }
    
    func addGroup(completion: @escaping () -> Void) {
        let mdmSetup = MDMSetup(setup: false)!
        if mdmSetup.disableCreateGroup() {
            createErrorResponse(errorDescription: "disabledByPolicy", completion: completion)
            return
        }
        
        let groupManager: GroupManagerProtocol = BusinessInjector().groupManager
        
        groupManager.createOrUpdate(
            for: GroupIdentity(
                id: NaClCrypto.shared().randomBytes(Int32(ThreemaProtocol.groupIDLength)),
                creator: ThreemaIdentity(MyIdentityStore.shared().identity)
            ),
            members: Set<String>(groupRequest.members),
            systemMessageDate: Date()
        )
        .done { group, _ in
            if let name = self.groupRequest.name {
                groupManager.setName(group: group, name: name)
                    .catch { error in
                        DDLogError("Error while set group name: \(error)")
                    }
            }

            if let photo = self.groupRequest.avatar {
                self.setGroupPhoto(
                    groupManager: groupManager,
                    photo: photo,
                    group: group,
                    completion: completion
                )
            }

            self.createSuccessResponse(group: group, completion: completion)
        }
        .catch { error in
            DDLogError("Could not create group members: \(error)")
            self.createErrorResponse(errorDescription: "internalError", completion: completion)
        }
    }
    
    func setGroupPhoto(
        groupManager: GroupManagerProtocol,
        photo: Data,
        group: Group,
        completion: @escaping () -> Void
    ) {
        groupManager.setPhoto(group: group, imageData: photo, sentDate: Date())
            .catch { error in
                self.createErrorResponse(
                    errorDescription: "Set group photo failed: \(error.localizedDescription)",
                    completion: completion
                )
            }
    }
    
    func createSuccessResponse(group: Group, completion: @escaping () -> Void) {
        ack!.success = true
        args = nil
        let webGroup = WebGroup(group: group)
        data = ["receiver": webGroup.objectDict()]
        completion()
    }
    
    func createErrorResponse(errorDescription: String, completion: @escaping () -> Void) {
        DDLogError(errorDescription)
        
        ack!.success = false
        ack!.error = errorDescription
        args = nil
        data = nil
        
        completion()
    }
}
