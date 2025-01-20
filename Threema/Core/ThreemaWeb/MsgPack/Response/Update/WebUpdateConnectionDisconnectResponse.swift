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

import Foundation

class WebUpdateConnectionDisconnectResponse: WebAbstractMessage {
    
    enum ReasonMode: String {
        case stop
        case delete
        case disable
        case replace
    }
    
    var reason: String
    
    init(disconnectReason: Int) {
        switch disconnectReason {
        case 0:
            self.reason = ReasonMode.stop.rawValue
        case 1:
            self.reason = ReasonMode.delete.rawValue
        case 2:
            self.reason = ReasonMode.disable.rawValue
        case 3:
            self.reason = ReasonMode.replace.rawValue
        default:
            self.reason = ReasonMode.stop.rawValue
        }
        
        let tmpData: [AnyHashable: Any?] = ["reason": reason]
        
        super.init(
            messageType: "update",
            messageSubType: "connectionDisconnect",
            requestID: nil,
            ack: nil,
            args: nil,
            data: tmpData
        )
    }
}
