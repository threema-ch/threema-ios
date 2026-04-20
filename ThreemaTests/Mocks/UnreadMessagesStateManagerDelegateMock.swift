import Foundation

@testable import Threema

final class UnreadMessagesStateManagerDelegateMock: UnreadMessagesStateManagerDelegate {
    var shouldMarkMessagesAsRead = true
}
