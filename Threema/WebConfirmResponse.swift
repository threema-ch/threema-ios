//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

class WebConfirmResponse: WebAbstractMessage {
    
    init(message: WebAbstractMessage, success: Bool, error: String?) {
        let ack = WebAbstractMessageAcknowledgement.init(message.requestId, success, error)
        super.init(messageType: "update", messageSubType: "confirm", requestId: nil, ack: ack, args: nil, data: nil)
    }
    
    init(webReadRequest: WebReadRequest) {
        super.init(messageType: "update", messageSubType: "confirm", requestId: nil, ack: webReadRequest.ack, args: nil, data: nil)
    }
    
    init(webCleanReceiverConversationRequest: WebCleanReceiverConversationRequest) {
        let tmpAck = WebAbstractMessageAcknowledgement.init(webCleanReceiverConversationRequest.requestId, true, nil)
        super.init(messageType: "update", messageSubType: "confirm", requestId: nil, ack: tmpAck, args: nil, data: nil)
    }
    
    init(webUpdateProfileRequest: WebUpdateProfileRequest) {
        super.init(messageType: "update", messageSubType: "confirm", requestId: nil, ack: webUpdateProfileRequest.ack, args: nil, data: nil)
    }
    
    init(webGroupSyncRequest: WebGroupSyncRequest) {
        super.init(messageType: "update", messageSubType: "confirm", requestId: nil, ack: webGroupSyncRequest.ack, args: nil, data: nil)
    }
    
    init(webDeleteMessageRequest: WebDeleteMessageRequest) {
        super.init(messageType: "update", messageSubType: "confirm", requestId: nil, ack: webDeleteMessageRequest.ack, args: nil, data: nil)
    }
    
    init(webDeleteGroupRequest: WebDeleteGroupRequest) {
        super.init(messageType: "update", messageSubType: "confirm", requestId: nil, ack: webDeleteGroupRequest.ack, args: nil, data: nil)
    }
    
    init(webUpdateConversationRequest: WebUpdateConversationRequest) {
        super.init(messageType: "response", messageSubType: "confirmAction", requestId: nil, ack: webUpdateConversationRequest.ack, args: nil, data: nil)
    }
    
    init(webUpdateActiveConversationRequest: WebUpdateActiveConversationRequest) {
        super.init(messageType: "response", messageSubType: "confirm", requestId: nil, ack: webUpdateActiveConversationRequest.ack, args: nil, data: nil)
    }
}
