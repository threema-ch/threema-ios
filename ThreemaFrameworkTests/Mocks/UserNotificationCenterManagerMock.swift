import Foundation
import PromiseKit
@testable import ThreemaFramework

final class UserNotificationCenterManagerMock: UserNotificationCenterManagerProtocol {
    private let returnFireDate: Date
    private let deliveredNotifications: [PendingUserNotificationKey]?

    var addCalls = [PendingUserNotificationKey]()
    var removeCalls = [PendingUserNotificationKey]()

    convenience init() {
        self.init(returnFireDate: Date())
    }

    required init(returnFireDate: Date, deliveredNotifications: [PendingUserNotificationKey]? = nil) {
        self.returnFireDate = returnFireDate
        self.deliveredNotifications = deliveredNotifications
    }
    
    func add(
        contentKey: PendingUserNotificationKey,
        stage: UserNotificationStage,
        notification: UNNotificationContent
    ) -> Promise<Date?> {
        addCalls.append(contentKey)

        return Promise { seal in
            seal.fulfill(returnFireDate)
        }
    }
    
    func isPending(contentKey: PendingUserNotificationKey, stage: UserNotificationStage) -> Bool {
        false
    }
    
    func isDelivered(contentKey: PendingUserNotificationKey) -> Bool {
        deliveredNotifications?.contains(contentKey) ?? false
    }

    func remove(contentKey: PendingUserNotificationKey, exceptStage: UserNotificationStage?, justPending: Bool) {
        removeCalls.append(contentKey)
    }
}
