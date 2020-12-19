//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

class WebUpdateConnectionDisconnectResponse: WebAbstractMessage {
    
    enum ReasonMode: String {
        case stop = "stop"
        case delete = "delete"
        case disable = "disable"
        case replace = "replace"
    }
    
    var reason: String
    
    init(disconnectReason: Int) {
        switch disconnectReason {
        case 0:
            reason = ReasonMode.stop.rawValue
            break
        case 1:
            reason = ReasonMode.delete.rawValue
            break
        case 2:
            reason = ReasonMode.disable.rawValue
            break
        case 3:
            reason = ReasonMode.replace.rawValue
            break
        default:
            reason = ReasonMode.stop.rawValue
        }
        
        let tmpData:[AnyHashable:Any?] = ["reason": reason]
        
        super.init(messageType: "update", messageSubType: "connectionDisconnect", requestId: nil, ack: nil, args: nil, data: tmpData)
    }
}
