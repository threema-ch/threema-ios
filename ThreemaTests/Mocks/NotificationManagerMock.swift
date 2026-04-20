import Foundation
import XCTest

@testable import Threema

final class NotificationManagerMock: NotificationManagerProtocol {
    var updateUnreadMessagesCountCallCount = 0

    func updateUnreadMessagesCount() {
        updateUnreadMessagesCountCallCount += 1
    }

    func updateUnreadMessagesCount(baseMessage: BaseMessageEntity?) {
        updateUnreadMessagesCountCallCount += 1
    }
}
