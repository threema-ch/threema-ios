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

class WebConnectionAckUpdateRequest: WebAbstractMessage {
    
    var sequenceNumber: UInt32?
    
    override init(message: WebAbstractMessage) {
        let data = message.data! as! [AnyHashable: Any]
        super.init(message: message)
        self.sequenceNumber = convertToUInt32(sn: data["sequenceNumber"]!)
    }
    
    func convertToUInt32(sn: Any) -> UInt32 {
        var converted: UInt32 = 0
        if let sq = sn as? UInt8 {
            converted = UInt32(sq)
        }
        else if let sq = sn as? Int8 {
            converted = UInt32(sq)
        }
        else if let sq = sn as? UInt16 {
            converted = UInt32(sq)
        }
        else if let sq = sn as? Int16 {
            converted = UInt32(sq)
        }
        else if let sq = sn as? UInt32 {
            converted = sq
        }
        else if let sq = sn as? Int32 {
            converted = UInt32(sq)
        }
        else if let sq = sn as? UInt64 {
            if sq > UINT32_MAX {
                // error
            }
            else {
                converted = UInt32(sq)
            }
        }
        else if let sq = sn as? Int64 {
            if sq > UINT32_MAX {
                // error
            }
            else {
                converted = UInt32(sq)
            }
        }
        else {
            // error
        }
        return converted
    }
}
