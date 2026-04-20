import UIKit

final class WebUnreadMessageObject: NSObject {
    var type: String
    var id: String
    var date: Int
    var sortKey: Int
    var isOutbox: Bool
    var isStatus = false
    var statusType: String?
    var unread: Bool?
    
    init(firstUnreadMessage: BaseMessageEntity) {
        self.type = "contact"
        self.id = "unreadMessage"
        let currentDate = firstUnreadMessage.displayDate
        self.date = Int(currentDate.timeIntervalSince1970) - 1
        self.sortKey = Int(currentDate.timeIntervalSince1970) - 1
        self.isOutbox = true
        self.isStatus = true
        self.unread = true
        self.statusType = "firstUnreadMessage"
    }
    
    func objectDict() -> [String: Any] {
        [
            "type": type,
            "id": id,
            "date": date,
            "isOutbox": isOutbox,
            "isStatus": isStatus,
            "statusType": statusType!,
            "unread": unread!,
        ]
    }
}
