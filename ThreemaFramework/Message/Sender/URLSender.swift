import CocoaLumberjackSwift
import Foundation

@objc public final class URLSender: NSObject {
    
    /// Sends the file from url as a file message
    /// - Parameters:
    ///   - url: A local url pointing to a file
    ///   - asFile: Whether the file should be sent as is. Can be true if the photo/video has previously been converted
    ///   or if the user has explicitly chosen to send this file to be rendered as a file
    ///   - caption: The caption displayed below the file
    ///   - conversation: The conversation to which the file should be sent
    @objc public static func sendURL(_ url: URL, asFile: Bool, caption: String?, conversation: ConversationEntity) {
        let senderItem: URLSenderItem?
        if asFile {
            let uti = UTIConverter.uti(forFileURL: url) ?? UTType.data.identifier
            let mimeType = UTIConverter.mimeType(fromUTI: uti) ?? "application/octet-stream"
            senderItem = URLSenderItem(url: url, type: mimeType, renderType: 0, sendAsFile: true)
        }
        else {
            senderItem = URLSenderItemCreator.getSenderItem(for: url)
        }
        if caption != nil {
            senderItem?.caption = caption
        }
        
        guard let senderItem else {
            DDLogError("Could not create sender item")
            return
        }
        
        Task {
            do {
                try await BusinessInjector().messageSender.sendBlobMessage(for: senderItem, in: conversation.objectID)
            }
            catch {
                DDLogError("Could not send sender item, error: \(error)")
            }
        }
    }
}
