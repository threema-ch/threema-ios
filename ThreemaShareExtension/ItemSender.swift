import CocoaLumberjackSwift
import CoreServices
import Foundation
import PromiseKit
import ThreemaFramework
import ThreemaMacros

protocol SenderItemDelegate: AnyObject {
    func showAlert(with title: String, message: String)
    func setProgress(progress: NSNumber, forItem: Any)
    func finishedItem(item: Any)
    func setFinished()
}

class ItemSender: NSObject {

    private lazy var persistenceManager = PersistenceManager(
        appGroupID: AppGroup.groupID(),
        userDefaults: AppGroup.userDefaults(),
        remoteSecretManager: AppLaunchManager.remoteSecretManager
    )

    private var recipientConversations: Set<ConversationEntity>?
    var itemsToSend: [URL]?
    var textToSend: String?
    var sendAsFile = false
    var captions = [String?]()
    
    private var sentItemCount: Int?
    private var totalSendCount: Int?
    
    private var correlationIDs: [String] = Array()
    private let imageSender = ImageURLSenderItemCreator()

    var shouldCancel = false
    
    private var uploadSema = DispatchSemaphore(value: 0)
    private var sender: Old_FileMessageSender?
    
    weak var delegate: SenderItemDelegate?
    
    func itemCount() -> Promise<Int> {
        var count = 0
        if itemsToSend != nil {
            return .value(itemsToSend!.count)
        }
        
        guard let text = textToSend else {
            return .value(count)
        }
        if !text.isEmpty {
            count = count + 1
        }
        
        return .value(count)
    }
    
    func addText(text: String) {
        textToSend = text
    }
    
    private func sendTextItems() {
        for conversation in recipientConversations! {
            if shouldCancel {
                return
            }
            sendItem(senderItem: textToSend!, toConversation: conversation, correlationID: nil)
        }
    }
    
    private func sendMediaItems() {
        let conv: [ConversationEntity] = Array(recipientConversations!)
        DispatchQueue.global().async {
            var senderItem: URLSenderItem?
            for i in 0..<self.itemsToSend!.count {
                guard !self.shouldCancel else {
                    return
                }
                
                autoreleasepool {
                    senderItem = self.getMediaSenderItem(url: self.itemsToSend![i], caption: self.captions[i])
                    
                    for j in 0..<conv.count {
                        guard !self.shouldCancel else {
                            senderItem = nil
                            return
                        }
                        
                        autoreleasepool {
                            self.sendItem(
                                senderItem: senderItem!,
                                toConversation: conv[j],
                                correlationID: self.correlationIDs[j]
                            )
                        }
                        // We do no longer call refreshDirtyObjects(false) since it lead to some changes not being saved
                        // correctly, and thus have higher memory usage in the share extension.
                    }
                    senderItem = nil
                }
            }
        }
    }
    
    private func getMediaSenderItem(url: URL, caption: String?) -> URLSenderItem {
        var senderItem: URLSenderItem
        if sendAsFile {
            let uti = UTIConverter.uti(forFileURL: url) ?? UTType.data.identifier
            let mimeType = UTIConverter.mimeType(fromUTI: uti) ?? "application/octet-stream"
            senderItem = URLSenderItem(
                url: url,
                type: mimeType,
                renderType: 0,
                sendAsFile: true
            )
        }
        else {
            guard let item = URLSenderItemCreator.getSenderItem(for: url, maxSize: .large) else {
                let uti = UTIConverter.uti(forFileURL: url) ?? UTType.data.identifier
                let mimeType = UTIConverter.mimeType(fromUTI: uti) ?? "application/octet-stream"
                let msg = "Could not create sender item for item of type \(mimeType)"
                DDLogError("\(msg)")
                fatalError(msg)
            }
            senderItem = item
        }
        if let caption, !caption.isEmpty {
            senderItem.caption = caption
        }
        return senderItem
    }
    
    func sendItemsTo(conversations: Set<ConversationEntity>) {
        recipientConversations = conversations
        _ = itemCount().done { [imageSender] itemCount in
            self.totalSendCount = self.recipientConversations!.count * itemCount
            self.sentItemCount = 0
            
            if self.textToSend != nil {
                self.sendTextItems()
            }
            else if self.itemsToSend != nil {
                for _ in 0..<self.recipientConversations!.count {
                    self.correlationIDs.append(imageSender.createCorrelationID())
                }
                self.sendMediaItems()
            }
            else {
                let err = "No sendable items provided"
                DDLogError("\(err)")
                fatalError(err)
            }
        }
    }
    
    private func sendItem(senderItem: Any, toConversation: ConversationEntity, correlationID: String?) {
        if let senderItem = senderItem as? URLSenderItem {
            sendURLSenderItem(senderItem: senderItem, toConversation: toConversation, correlationID: correlationID)
        }
        else if let message = senderItem as? String {
            
            let trimmedMessage = ThreemaUtility.trimCharacters(in: message)
            if !(trimmedMessage == "" || trimmedMessage == "\u{fffc}"), !trimmedMessage.isEmpty {
                sendString(message: message, toConversation: toConversation)
            }
            else {
                let title = #localize("error_message_no_items_title")
                let message = #localize("error_message_no_items_message")
                delegate!.showAlert(with: title, message: message)
                
                delegate?.finishedItem(item: progressItemKey(item: message, conversation: toConversation)!)
                sentItemCount = sentItemCount! + 1
                checkIsFinished()
            }
        }
        else {
            let title = #localize("error_message_no_items_title")
            let message = #localize("error_message_no_items_message")
            delegate!.showAlert(with: title, message: message)
            
            sentItemCount = sentItemCount! + 1
            checkIsFinished()
        }
    }
    
    private func sendURLSenderItem(
        senderItem: URLSenderItem,
        toConversation: ConversationEntity,
        correlationID: String?
    ) {
        sender = Old_FileMessageSender()
        sender!.uploadProgressDelegate = self
        sender!.send(senderItem, in: toConversation, requestID: nil, correlationID: correlationID)
        if toConversation.conversationVisibility == .archived {
            toConversation.visibility = ConversationEntity.Visibility.default.rawValue as NSNumber
        }
        uploadSema.wait()
        sender = nil
    }
    
    private func sendString(message: String, toConversation: ConversationEntity) {
        Task { @MainActor in
            self.delegate?.setProgress(
                progress: 0.1,
                forItem: self.progressItemKey(item: message, conversation: toConversation)!
            )
            
            Task {
                let textMessages = await BusinessInjector().messageSender.sendTextMessage(
                    containing: message,
                    in: toConversation
                )
                Task { @MainActor in
                    self.textMessageCompletionHandler(textMessages: textMessages)
                }
            }
        }
    }
    
    private func textMessageCompletionHandler(textMessages: [TextMessageEntity]) {
        for textMessage in textMessages {
            delegate?
                .finishedItem(item: [progressItemKey(item: textMessage.text, conversation: textMessage.conversation)])
            
            if textMessage.conversation.conversationVisibility == .archived {
                textMessage.conversation.visibility = ConversationEntity.Visibility.default
                    .rawValue as NSNumber
            }

            persistenceManager.dirtyObjectManager.markAsDirty(objectID: textMessage.objectID) {
                AppGroup.notifySyncNeeded()
            }

            sentItemCount! += 1
            checkIsFinished()
        }
    }
    
    private func progressItemKey(item: String, conversation: ConversationEntity) -> Any? {
        let hash: NSInteger = (item as AnyObject).hash + conversation.hashValue
        return NSNumber(value: hash)
    }
    
    private func checkIsFinished() {
        if sentItemCount == totalSendCount {
            let when = DispatchTime.now() + 0.75
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: when) {
                DispatchQueue.main.async {
                    self.delegate?.setFinished()
                }
            }
        }
    }
}

// MARK: - UploadProgressDelegate

extension ItemSender: UploadProgressDelegate {
    public func blobMessageSenderUploadShouldCancel(_ blobMessageSender: Old_BlobMessageSender) -> Bool {
        shouldCancel
    }
    
    func blobMessageSender(
        _ blobMessageSender: Old_BlobMessageSender,
        uploadProgress progress: NSNumber,
        forMessage messageObject: NSObject
    ) {
        let message = messageObject as! BaseMessageEntity

        delegate?.setProgress(progress: progress, forItem: message.id)
    }
    
    func blobMessageSender(
        _ blobMessageSender: Old_BlobMessageSender,
        uploadSucceededForMessage messageObject: NSObject
    ) {
        let message = messageObject as! BaseMessageEntity

        sentItemCount! += 1
        delegate?.finishedItem(item: message.id)

        persistenceManager.dirtyObjectManager.markAsDirty(objectID: message.objectID) {
            AppGroup.notifySyncNeeded()
        }

        checkIsFinished()
        
        DispatchQueue.global(qos: .userInteractive).async {
            self.uploadSema.signal()
        }
    }
    
    func blobMessageSender(
        _ blobMessageSender: Old_BlobMessageSender,
        uploadFailedForMessage messageObject: NSObject?,
        error: UploadError
    ) {
        DispatchQueue.global(qos: .userInteractive).async {
            self.uploadSema.signal()
        }
        sentItemCount! += 1
        
        let errorTitle = #localize("error_sending_failed")
        let errorMessage = Old_FileMessageSender.message(forError: error)
        
        delegate?.showAlert(with: errorTitle, message: errorMessage!)
        
        if error == UploadErrorSendFailed,
           let message = messageObject as? BaseMessageEntity {
            persistenceManager.dirtyObjectManager.markAsDirty(objectID: message.objectID) {
                AppGroup.notifySyncNeeded()
            }
        }
    }
}
