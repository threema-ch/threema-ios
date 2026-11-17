import Foundation
import PromiseKit
@testable import ThreemaFramework

final class UserNotificationCenterManagerMock: UserNotificationCenterManagerProtocol {
    private let returnFireDate: Date
    private let deliveredNotifications: [PendingUserNotificationKey]?
    /// Notifications scheduled but not shown yet, in any stage
    private let pendingNotifications: [PendingUserNotificationKey]

    var addCalls = [PendingUserNotificationKey]()
    /// Content of every notification added, in the order of `addCalls`
    var addedNotifications = [UNNotificationContent]()
    var removeCalls = [PendingUserNotificationKey]()
    /// Removals that also cleared notifications already shown, not just pending ones
    var removeDeliveredCalls = [PendingUserNotificationKey]()

    convenience init() {
        self.init(returnFireDate: Date())
    }

    required init(
        returnFireDate: Date,
        deliveredNotifications: [PendingUserNotificationKey]? = nil,
        pendingNotifications: [PendingUserNotificationKey] = []
    ) {
        self.returnFireDate = returnFireDate
        self.deliveredNotifications = deliveredNotifications
        self.pendingNotifications = pendingNotifications
    }
    
    func add(
        contentKey: PendingUserNotificationKey,
        stage: UserNotificationStage,
        notification: UNNotificationContent
    ) -> Promise<Date?> {
        addCalls.append(contentKey)
        addedNotifications.append(notification)

        return Promise { seal in
            seal.fulfill(returnFireDate)
        }
    }
    
    func isPending(contentKey: PendingUserNotificationKey, stage: UserNotificationStage) -> Bool {
        pendingNotifications.contains(contentKey)
    }
    
    func isDelivered(contentKey: PendingUserNotificationKey) -> Bool {
        deliveredNotifications?.contains(contentKey) ?? false
    }

    func remove(contentKey: PendingUserNotificationKey, exceptStage: UserNotificationStage?, justPending: Bool) {
        removeCalls.append(contentKey)
        if !justPending {
            removeDeliveredCalls.append(contentKey)
        }
    }
}
