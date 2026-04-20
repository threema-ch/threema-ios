import Foundation
import ThreemaMacros
@testable import ThreemaFramework

final class UserNotificationManagerMock: UserNotificationManagerProtocol {
    
    private var returnUserNotificationContent: UserNotificationContent?
    
    convenience init(returnUserNotificationContent: UserNotificationContent) {
        self.init()
        self.returnUserNotificationContent = returnUserNotificationContent
    }
        
    func userNotificationContent(_ pendingUserNotification: PendingUserNotification) -> UserNotificationContent? {
        returnUserNotificationContent
    }
    
    func testNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent {
        UNMutableNotificationContent()
    }
    
    func threemaWebNotificationContent(payload: [AnyHashable: Any]) -> UNMutableNotificationContent {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = #localize("notification.threemaweb.connect.title")
        notificationContent.body = #localize("notification.threemaweb.connect.body")
        notificationContent.userInfo = payload

        return notificationContent
    }
    
    func applyContent(
        from: UserNotificationContent,
        to: inout UNMutableNotificationContent,
        silent: Bool,
        baseMessage: BaseMessageEntity?
    ) { }
}
