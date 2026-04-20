import Foundation

final class WebAlertUpdate: WebAbstractMessage {
    
    var source: SourceObj
    var type: TypeObj
    var message: String
    
    enum SourceObj: String {
        case server
        case device
    }
    
    enum TypeObj: String {
        case error
        case warning
        case info
    }
    
    init(source: SourceObj, type: TypeObj, message: String) {
        self.source = source
        self.type = type
        self.message = message
        
        let tmpArgs: [AnyHashable: Any?] = ["source": source.rawValue, "type": type.rawValue]
        let tmpData: [AnyHashable: Any?] = ["message": message] as [String: Any]
        
        super.init(
            messageType: "update",
            messageSubType: "alert",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: tmpData
        )
    }
}
