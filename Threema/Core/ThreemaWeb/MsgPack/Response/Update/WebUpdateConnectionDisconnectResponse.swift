import Foundation

final class WebUpdateConnectionDisconnectResponse: WebAbstractMessage {
    
    enum ReasonMode: String {
        case stop
        case delete
        case disable
        case replace
    }
    
    var reason: String
    
    init(disconnectReason: Int) {
        switch disconnectReason {
        case 0:
            self.reason = ReasonMode.stop.rawValue
        case 1:
            self.reason = ReasonMode.delete.rawValue
        case 2:
            self.reason = ReasonMode.disable.rawValue
        case 3:
            self.reason = ReasonMode.replace.rawValue
        default:
            self.reason = ReasonMode.stop.rawValue
        }
        
        let tmpData: [AnyHashable: Any?] = ["reason": reason]
        
        super.init(
            messageType: "update",
            messageSubType: "connectionDisconnect",
            requestID: nil,
            ack: nil,
            args: nil,
            data: tmpData
        )
    }
}
