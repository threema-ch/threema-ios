//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import FileUtility
import Foundation
import ThreemaFramework

public final class WebCreateFileMessageRequest: WebAbstractMessage {
    
    var backgroundIdentifier: String?
    
    var type: String
    var id: String?
    var groupID: Data?
    
    var name: String
    var fileType: String
    var sendAsFile: Bool
    var size: Int
    var fileData: Data?
    var caption: String?
    var tmpError: String?
    
    var baseMessage: BaseMessageEntity?
    
    var session: WCSession?
    
    override init(message: WebAbstractMessage) {
        self.type = message.args!["type"] as! String
        if type == "contact" {
            self.id = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as! String
            self.groupID = idString.hexadecimal
        }
        
        let data = message.data! as! [AnyHashable: Any?]
        self.name = data["name"] as! String
        self.fileType = data["fileType"] as! String
        self.sendAsFile = data["sendAsFile"] as! Bool
        
        if let tmpSize = data["size"] as? UInt8 {
            self.size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt16 {
            self.size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt32 {
            self.size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt64 {
            self.size = Int(tmpSize)
        }
        else {
            self.size = 0
        }
        
        self.fileData = data["data"] as? Data
        self.caption = data["caption"] as? String
        super.init(message: message)
    }
    
    init(message: WebAbstractMessage, session: WCSession) {
        
        self.type = message.args!["type"] as! String
        if type == "contact" {
            self.id = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as! String
            self.groupID = idString.hexadecimal
        }
        
        let data = message.data! as! [AnyHashable: Any?]
        self.name = data["name"] as! String
        self.fileType = data["fileType"] as! String
        self.sendAsFile = data["sendAsFile"] as! Bool
        
        if let tmpSize = data["size"] as? UInt8 {
            self.size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt16 {
            self.size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt32 {
            self.size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt64 {
            self.size = Int(tmpSize)
        }
        else {
            self.size = 0
        }
        
        self.fileData = data["data"] as? Data
        self.caption = data["caption"] as? String
        self.session = session
        super.init(message: message)
    }
    
    func sendMessage(completion: @escaping () -> Void) {
        let entityManager = BusinessInjector.ui.entityManager
        let groupManager = BusinessInjector.ui.groupManager
        let messagePermission = MessagePermission(
            myIdentityStore: MyIdentityStore.shared(),
            userSettings: UserSettings.shared(),
            groupManager: groupManager,
            entityManager: entityManager
        )

        let type = type
        let id = id
        let groupID = groupID
        let result: Result<ConversationEntity, WebRequestError> = entityManager.performAndWait {
            var conversation: ConversationEntity?
            if type == "contact", let id {
                guard let contact = entityManager.entityFetcher.contactEntity(for: id) else {
                    return .failure(WebRequestError(message: "internalError"))
                }

                conversation = entityManager.entityFetcher.conversationEntity(for: contact.identity)
                if conversation == nil {
                    entityManager.performAndWaitSave {
                        conversation = entityManager.entityCreator.conversationEntity()
                        conversation?.contact = contact
                    }
                }
            }
            else {
                conversation = entityManager.entityFetcher.legacyConversationEntity(for: groupID)
            }

            guard let conversation else {
                return .failure(WebRequestError(message: "internalError"))
            }

            if let group = groupManager.getGroup(conversation: conversation),
               !messagePermission.canSend(
                   groudID: group.groupID,
                   groupCreatorIdentity: group.groupCreatorIdentity
               ).isAllowed {
                return .failure(WebRequestError(message: "blocked"))
            }
            else if let identity = id, !messagePermission.canSend(to: identity).isAllowed {
                return .failure(WebRequestError(message: "blocked"))
            }

            return .success(conversation)
        }

        guard case let .success(conversation) = result else {
            if case let .failure(error) = result {
                baseMessage = nil
                tmpError = error.message
            }
            completion()
            return
        }

        if size > kMaxFileSize {
            baseMessage = nil
            tmpError = "fileTooLarge"
            completion()
            return
        }

        if fileData == nil {
            baseMessage = nil
            tmpError = "internalError"
            completion()
            return
        }

        backgroundIdentifier = BackgroundTaskManager.shared.counter(identifier: kAppSendingBackgroundTask)
        BackgroundTaskManager.shared.newBackgroundTask(
            key: backgroundIdentifier!,
            timeout: Int(kAppSendingBackgroundTaskTime)
        ) { [weak self] in
            guard let self else {
                return
            }

            if !sendAsFile,
               fileType == "image/jpeg" ||
               fileType == "image/pjpeg" ||
               fileType == "image/png" ||
               fileType == "image/x-png" ||
               UTIConverter.isGifMimeType(fileType) {
                let imageSender = ImageURLSenderItemCreator()
                guard let fileData,
                      let uti = UTIConverter.uti(fromMimeType: fileType),
                      let item = imageSender.senderItem(from: fileData, uti: uti) else {
                    DDLogError("Could not create URLSenderItem from image")
                    return
                }
                item.caption = caption
                let sender = Old_FileMessageSender()
                sendMessage(sender: sender, item: item, conversation: conversation, completion: completion)
            }
            else if !sendAsFile,
                    fileType == "video/mp4" ||
                    fileType == "video/mpeg4" ||
                    fileType == "video/x-m4v" {
                let creator = VideoURLSenderItemCreator()
                guard let data = fileData else {
                    return
                }
                guard let videoURL = VideoURLSenderItemCreator.writeToTemporaryDirectory(data: data) else {
                    return
                }
                guard let senderItem = creator.senderItem(from: videoURL) else {
                    return
                }
                let fileSender = Old_FileMessageSender()
                sendMessage(
                    sender: fileSender,
                    item: senderItem,
                    conversation: conversation,
                    completion: { [weak self] in
                        guard let self else {
                            return
                        }

                        do {
                            try FileUtility.shared.delete(at: videoURL)
                        }
                        catch {
                            DDLogError("Could not clear temporary directory \(error)")
                        }

                        completion()
                    }
                )
            }
            // Note: Audio files are always sent as file messages except when they are recorded voice
            // messages inside the app. Thus we don't have a special case for them here.
            else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    let blobSender = Old_FileMessageSender()
                    blobSender.fileNameFromWeb = name
                    let item = URLSenderItem(
                        data: fileData,
                        fileName: blobSender.fileNameFromWeb,
                        type: UTIConverter.uti(fromMimeType: fileType),
                        renderType: 0,
                        sendAsFile: true
                    )
                    item?.caption = caption
                    sendMessage(
                        sender: blobSender,
                        item: item,
                        conversation: conversation,
                        completion: completion
                    )
                }
            }
        }
    }
    
    private func sendMessage(
        sender: Old_FileMessageSender,
        item: URLSenderItem?,
        conversation: ConversationEntity?,
        completion: @escaping () -> Void
    ) {
        ServerConnectorHelper.connectAndWaitUntilConnected(
            initiator: .threemaWeb,
            timeout: 10
        ) { [weak self, weak sender, weak item, weak conversation] in
            guard let self,
                  let sender,
                  let item else {
                return
            }
            
            sender.send(item, in: conversation, requestID: requestID)
            completion()
            
            guard let conversation,
                  conversation.conversationVisibility == .archived else {
                return
            }
            conversation.changeVisibility(to: .default)
        } onTimeout: {
            DDLogError("Sending file message timed out")
            completion()
        }
    }
}
