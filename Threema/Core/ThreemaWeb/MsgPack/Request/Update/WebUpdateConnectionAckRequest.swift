import Foundation

final class WebConnectionAckUpdateRequest: WebAbstractMessage {
    
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
