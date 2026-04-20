import CocoaLumberjackSwift
import Foundation

final class WebUpdateConnectionDisconnectRequest: WebAbstractMessage {
    
    let reason: String
    
    override init(message: WebAbstractMessage) {
        let data = message.data as! [AnyHashable: Any?]
        self.reason = data["reason"] as! String
        super.init(message: message)
    }
    
    func disconnect(session: WCSession) {
        let forget: Bool = reason == "delete"
        DDLogNotice("[Threema Web] Disconnect webclient WebUpdateConnectionDisconnectRequest")
        session.stop(close: true, forget: forget, sendDisconnect: false, reason: .stop)
    }
}
