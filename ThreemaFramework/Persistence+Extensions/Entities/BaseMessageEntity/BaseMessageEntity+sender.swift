import Foundation
import ThreemaMacros

extension BaseMessageEntity {
    
    /// Readable name of the sender
    public var localizedSenderName: String {
        if isOwnMessage {
            #localize("me")
        }
        else {
            if let sender {
                sender.displayName
            }
            else {
                conversation.contact?.displayName ?? ""
            }
        }
    }
    
    public var senderIDColor: UIColor {
        if isOwnMessage {
            MyIdentityStore.shared().idColor
        }
        else {
            if let sender {
                sender.idColor
            }
            else {
                conversation.contact?.idColor ?? .primary
            }
        }
    }
}
