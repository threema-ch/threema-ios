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

import CocoaLumberjackSwift
import Foundation

class WebTypingUpdate: WebAbstractMessage {
    
    var id: String
    var isTyping: Bool
    
    override init(message: WebAbstractMessage) {
        self.id = message.args!["id"] as! String
        let data = message.data! as! [AnyHashable: Any?]
        self.isTyping = data["isTyping"] as! Bool
        super.init(
            messageType: "update",
            messageSubType: "typing",
            requestID: nil,
            ack: nil,
            args: ["id": id],
            data: ["isTyping": isTyping]
        )
    }
    
    init(identity: String, typing: Bool) {
        
        self.id = identity
        self.isTyping = typing
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id]
        let tmpData: [AnyHashable: Any?] = ["isTyping": isTyping]
        super.init(
            messageType: "update",
            messageSubType: "typing",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: tmpData
        )
    }
    
    func sendTypingToContact() {
        ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .threemaWeb, timeout: 10) {
            BusinessInjector().messageSender.sendTypingIndicator(typing: self.isTyping, toIdentity: self.id)
        } onTimeout: {
            DDLogError("Sending typing indicator message timed out")
        }
    }
}
