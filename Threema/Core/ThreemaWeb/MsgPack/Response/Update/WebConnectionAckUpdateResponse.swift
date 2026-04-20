import Foundation

final class WebConnectionAckUpdateResponse: WebAbstractMessage {
    
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
