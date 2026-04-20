import Foundation

public protocol GroupCallSystemMessageAdapterProtocol: AnyObject, Sendable {
    func post(_ systemMessage: GroupCallSystemMessage, in groupModel: GroupCallThreemaGroupModel) async throws
}
