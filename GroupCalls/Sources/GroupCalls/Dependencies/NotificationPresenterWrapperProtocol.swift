import Foundation

public protocol NotificationPresenterWrapperProtocol: AnyObject, Sendable {
    func presentGroupCallNotification(
        type: GroupCallNotificationType
    )
}
