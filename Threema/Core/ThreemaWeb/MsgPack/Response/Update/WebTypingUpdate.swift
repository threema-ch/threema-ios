import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials

final class WebTypingUpdate: WebAbstractMessage {
    
    var id: ThreemaIdentity
    var isTyping: Bool
    
    override init(message: WebAbstractMessage) {
        self.id = ThreemaIdentity(message.args!["id"] as! String)
        let data = message.data! as! [AnyHashable: Any?]
        self.isTyping = data["isTyping"] as! Bool
        super.init(
            messageType: "update",
            messageSubType: "typing",
            requestID: nil,
            ack: nil,
            args: ["id": id],
            data: ["isTyping": isTyping]
        )
    }
    
    init(identity: ThreemaIdentity, typing: Bool) {
        
        self.id = identity
        self.isTyping = typing
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id]
        let tmpData: [AnyHashable: Any?] = ["isTyping": isTyping]
        super.init(
            messageType: "update",
            messageSubType: "typing",
            requestID: nil,
            ack: nil,
            args: tmpArgs,
            data: tmpData
        )
    }
    
    func sendTypingToContact() {
        ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .threemaWeb, timeout: 10) {
            BusinessInjector.ui.messageSender.sendTypingIndicator(
                typing: self.isTyping,
                toIdentity: self.id
            )
        } onTimeout: {
            DDLogError("Sending typing indicator message timed out")
        }
    }
}
