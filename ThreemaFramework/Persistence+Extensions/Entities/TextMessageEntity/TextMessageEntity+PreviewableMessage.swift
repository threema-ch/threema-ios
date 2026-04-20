import CocoaLumberjackSwift
import Foundation

extension TextMessageEntity: PreviewableMessage {
    public var privatePreviewText: String {
        text
    }
}
