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

class WebAlertUpdate: WebAbstractMessage {
    
    var source: SourceObj
    var type: TypeObj
    var message: String
    
    enum SourceObj: String {
        case server
        case device
    }
    
    enum TypeObj: String {
        case error
        case warning
        case info
    }
    
    init(source: SourceObj, type: TypeObj, message: String) {
        self.source = source
        self.type = type
        self.message = message
        
        let tmpArgs: [AnyHashable: Any?] = ["source": source.rawValue, "type": type.rawValue]
        let tmpData: [AnyHashable: Any?] = ["message": message] as [String: Any]
        
        super.init(
            messageType: "update",
            messageSubType: "alert",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: tmpData
        )
    }
}
