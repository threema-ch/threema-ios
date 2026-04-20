import Foundation

final class WebClientInfoRequest: WebAbstractMessage {
    
    let userAgent: String
    let browserName: String?
    var browserVersion: Int?
    
    override init(message: WebAbstractMessage) {
        let data = message.data! as! [AnyHashable: Any?]
        self.userAgent = data["userAgent"] as! String
        self.browserName = data["browserName"] as? String
        self.browserVersion = data["browserVersion"] as? Int
        super.init(message: message)
    }
}
