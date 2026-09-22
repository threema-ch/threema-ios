import Foundation
@testable import GroupCalls

final class MockGroupCallSystemMessageAdapter: @unchecked Sendable {
    private let lock = NSLock()
    private var posted = [GroupCalls.GroupCallSystemMessage]()

    var postedSystemMessages: [GroupCalls.GroupCallSystemMessage] {
        lock.withLock { posted }
    }

    var hasPostedGroupCallEnded: Bool {
        postedSystemMessages.contains { message in
            if case .groupCallEnded = message {
                return true
            }
            return false
        }
    }
}

// MARK: - GroupCallSystemMessageAdapterProtocol

extension MockGroupCallSystemMessageAdapter: GroupCallSystemMessageAdapterProtocol {
    func post(
        _ systemMessage: GroupCalls.GroupCallSystemMessage,
        in groupModel: GroupCalls.GroupCallThreemaGroupModel
    ) async throws {
        lock.withLock { posted.append(systemMessage) }
    }
}
