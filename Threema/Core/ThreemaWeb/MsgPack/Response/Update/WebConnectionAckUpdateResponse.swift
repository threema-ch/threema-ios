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

class WebConnectionAckUpdateResponse: WebAbstractMessage {
    
    var sequenceNumber: UInt32?
    
    init(requestID: String?, incomingSequenceNumber: UInt32) {
        self.sequenceNumber = incomingSequenceNumber
        let tmpData = ["sequenceNumber": sequenceNumber]
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        
        super.init(
            messageType: "update",
            messageSubType: "connectionAck",
            requestID: nil,
            ack: tmpAck,
            args: nil,
            data: tmpData
        )
    }
}
