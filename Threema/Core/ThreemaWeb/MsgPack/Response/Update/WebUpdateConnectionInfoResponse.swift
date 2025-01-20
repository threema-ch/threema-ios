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

class WebUpdateConnectionInfoResponse: WebAbstractMessage {
    var id: Data
    var resume: WebConnection?
    
    init(currentID: Data, previousID: Data?, previousSequenceNumber: UInt32?) {
        self.id = currentID
        
        var tmpData: [AnyHashable: Any?] = ["id": id]
        
        if previousID != nil, previousSequenceNumber != nil,
           !previousID!.bytes.isEmpty {
            self.resume = WebConnection(connection: ["id": previousID!, "sequenceNumber": previousSequenceNumber!])
        }

        if resume != nil {
            tmpData.updateValue(resume!.objectDict(), forKey: "resume")
        }
        
        super.init(
            messageType: "update",
            messageSubType: "connectionInfo",
            requestID: nil,
            ack: nil,
            args: nil,
            data: tmpData
        )
    }
}
