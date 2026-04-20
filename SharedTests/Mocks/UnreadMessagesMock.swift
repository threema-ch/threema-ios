import Foundation
import ThreemaFramework

final class UnreadMessagesMock: UnreadMessagesProtocol {
    func read(for conversation: ConversationEntity, isAppInBackground: Bool) -> Int {
        0
    }
    
    func read(for messages: [BaseMessageEntity], in conversation: ConversationEntity, isAppInBackground: Bool) -> Int {
        0
    }
    
    func totalCount(doCalcUnreadMessagesCountOf: Set<ConversationEntity>, withPerformBlockAndWait: Bool) -> Int {
        0
    }
    
    func count(for conversation: ConversationEntity, withPerformBlockAndWait: Bool) -> Int {
        0
    }
    
    func totalCount() -> Int {
        0
    }
}
