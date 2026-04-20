import Foundation

final class WebUpdateConnectionInfoResponse: WebAbstractMessage {
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
