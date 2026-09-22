import Foundation
@testable import GroupCalls

final class MockDatabaseDelegate: GroupCallManagerDatabaseDelegateProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var removed = [ProposedGroupCall]()

    var removedCalls: [ProposedGroupCall] {
        lock.withLock { removed }
    }

    func removeFromStoredCalls(_ groupCall: ProposedGroupCall) {
        lock.withLock { removed.append(groupCall) }
    }
}
