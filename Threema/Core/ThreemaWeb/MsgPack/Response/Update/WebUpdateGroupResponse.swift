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

class WebUpdateGroupResponse: WebAbstractMessage {
    
    var id: String
    
    var receiver: [AnyHashable: Any?]?
    
    init(groupRequest: WebUpdateGroupRequest) {
        
        self.id = groupRequest.id.hexEncodedString()

        if groupRequest.ack!.success {
            let webGroup = WebGroup(group: groupRequest.group!)
            self.receiver = webGroup.objectDict()
        }
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id]
        let tmpData: [AnyHashable: Any?] = ["receiver": receiver]
        
        super.init(
            messageType: "update",
            messageSubType: "group",
            requestID: nil,
            ack: groupRequest.ack,
            args: tmpArgs,
            data: tmpData
        )
    }
}
