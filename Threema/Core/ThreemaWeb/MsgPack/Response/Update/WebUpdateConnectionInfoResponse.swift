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

class WebUpdateConnectionInfoResponse: WebAbstractMessage, NSCoding {
    
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
    
    required init?(coder aDecoder: NSCoder) {
        self.id = aDecoder.decodeObject(forKey: "id") as! Data
        self.resume = aDecoder.decodeObject(forKey: "resume") as? WebConnection
        
        super.init(
            messageType: "update",
            messageSubType: "connectionInfo",
            requestID: nil,
            ack: nil,
            args: nil,
            data: aDecoder.decodeObject(forKey: "data")
        )
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: "id")
        if resume != nil {
            aCoder.encode(resume, forKey: "resume")
        }
        aCoder.encode(messageType, forKey: "messageType")
        if messageSubType != nil {
            aCoder.encode(messageSubType, forKey: "messageSubType")
        }
        if requestID != nil {
            aCoder.encode(requestID, forKey: "requestId")
        }
        if ack != nil {
            aCoder.encode(ack, forKey: "ack")
        }
        if args != nil {
            aCoder.encode(args, forKey: "args")
        }
        if data != nil {
            aCoder.encode(data, forKey: "data")
        }
    }
}
