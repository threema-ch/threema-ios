import Foundation
import ThreemaMacros

extension StorageManagementConversationView {
    enum Section: Hashable, CaseIterable, Identifiable {
        var id: Self { self }
        
        case messages
        case files
        case messageRetention
        
        var localizedTitle: String {
            switch self {
            case .messages:
                #localize("messages")
            case .files:
                #localize("files")
            case .messageRetention:
                #localize("automatic_delete")
            }
        }
        
        var localizedDescription: String {
            switch self {
            case .messages:
                #localize("delete_messages_explain")
            case .files:
                #localize("delete_explain")
            case .messageRetention:
                #localize("automatic_delete_explain")
            }
        }
        
        var symbol: String {
            switch self {
            case .messages:
                "envelope"
            case .files:
                "doc"
            case .messageRetention:
                "xmark.bin"
            }
        }
    }
}
