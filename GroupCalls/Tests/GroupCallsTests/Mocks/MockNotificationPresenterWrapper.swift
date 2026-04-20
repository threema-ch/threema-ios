import Foundation
@testable import GroupCalls

final class MockNotificationPresenterWrapper { }

// MARK: - NotificationPresenterWrapperProtocol

extension MockNotificationPresenterWrapper: NotificationPresenterWrapperProtocol {
    func presentGroupCallNotification(type: GroupCalls.GroupCallNotificationType) {
        // No-op
    }
}
