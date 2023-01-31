//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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

class WebReceiverUpdate: WebAbstractMessage {
    
    enum ObjectMode: String {
        case new
        case modified
        case refresh
        case removed
    }

    var id: String
    var mode: String
    var type: String
    
    init(updatedContact: Contact, objectMode: ObjectMode) {
        
        self.id = updatedContact.identity
        self.mode = objectMode.rawValue
        self.type = "contact"
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "mode": mode, "type": type]
        let webContact = WebContact(updatedContact)
        super.init(
            messageType: "update",
            messageSubType: "receiver",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: webContact.objectDict()
        )
    }
    
    init(updatedGroup: Group, objectMode: ObjectMode) {
        
        self.id = updatedGroup.groupID.hexEncodedString()
        self.mode = objectMode.rawValue
        self.type = "group"
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id, "mode": mode, "type": type]
        let webGroup = WebGroup(group: updatedGroup)
        super.init(
            messageType: "update",
            messageSubType: "receiver",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: webGroup.objectDict()
        )
    }
}
