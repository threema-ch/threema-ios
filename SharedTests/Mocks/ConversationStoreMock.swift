import Foundation
import ThreemaProtocols
@testable import ThreemaFramework

final class ConversationStoreMock: NSObject, ConversationStoreProtocol, ConversationStoreInternalProtocol {
    // MARK: ConversationStoreProtocol

    func pin(_ conversation: ConversationEntity) {
        // no-op
    }

    func unpin(_ conversation: ConversationEntity) {
        // no-op
    }

    func makePrivate(_ conversation: ConversationEntity) {
        // no-op
    }

    func makeNotPrivate(_ conversation: ConversationEntity) {
        // no-op
    }

    func archive(_ conversation: ConversationEntity) {
        // no-op
    }

    func unarchive(_ conversation: ConversationEntity) {
        // no-op
    }

    // MARK: ConversationStoreInternalProtocol

    func updateConversation(withContact syncContact: ThreemaProtocols.Sync_Contact) {
        // no-op
    }

    func updateConversation(withGroup syncGroup: ThreemaProtocols.Sync_Group) {
        // no-op
    }
}
