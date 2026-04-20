import Foundation
import ThreemaMacros

extension StorageManagementConversationView {
    enum ActionSheetType: Int, CaseIterable {
        case messages = 0
        case files
        
        var title: String {
            switch self {
            case .messages:
                #localize("delete_messages")
            case .files:
                #localize("delete_media")
            }
        }
            
        var description: String {
            switch self {
            case .messages:
                #localize("delete_messages_older_than")
            case .files:
                #localize("delete_media_older_than")
            }
        }
    }
}
