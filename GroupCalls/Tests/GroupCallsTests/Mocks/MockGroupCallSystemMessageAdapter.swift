import Foundation
@testable import GroupCalls

final class MockGroupCallSystemMessageAdapter: Sendable { }

// MARK: - GroupCallSystemMessageAdapterProtocol

extension MockGroupCallSystemMessageAdapter: GroupCallSystemMessageAdapterProtocol {
    func post(
        _ systemMessage: GroupCalls.GroupCallSystemMessage,
        in groupModel: GroupCalls.GroupCallThreemaGroupModel
    ) async throws {
        // Noop
    }
}
