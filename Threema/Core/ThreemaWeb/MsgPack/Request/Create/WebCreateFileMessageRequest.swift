//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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
import Foundation
import ThreemaFramework

public class WebCreateFileMessageRequest: WebAbstractMessage {
    
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
    
    var baseMessage: BaseMessage?
    
    var session: WCSession?
    
    override init(message: WebAbstractMessage) {
        
        self.type = message.args!["type"] as! String
        if type == "contact" {
            self.id = message.args!["id"] as? String
        }
        else {
            let idString = message.args!["id"] as! String
            self.groupID = idString.hexadecimal()
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
            self.groupID = idString.hexadecimal()
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
        var conversation: Conversation?
        let entityManager = EntityManager()
        if type == "contact" {
            let contact = entityManager.entityFetcher.contact(for: id)
            if contact == nil {
                baseMessage = nil
                tmpError = "internalError"
                completion()
                return
            }

            conversation = entityManager.entityFetcher.conversation(for: contact)
            if conversation == nil {
                entityManager.performSyncBlockAndSafe {
                    conversation = entityManager.entityCreator.conversation()
                    conversation?.contact = contact
                }
            }
        }
        else {
            conversation = entityManager.entityFetcher.conversation(for: groupID)
        }
        
        if conversation != nil {
            let groupManager = GroupManager(entityManager: entityManager)
            let messagePermission = MessagePermission(
                myIdentityStore: MyIdentityStore.shared(),
                userSettings: UserSettings.shared(),
                groupManager: groupManager,
                entityManager: entityManager
            )

            if let group = groupManager.getGroup(conversation: conversation!),
               !messagePermission.canSend(
                   groudID: group.groupID,
                   groupCreatorIdentity: group.groupCreatorIdentity
               ).isAllowed {
                baseMessage = nil
                tmpError = "blocked"
                completion()
                return
            }
            else if let identity = id, !messagePermission.canSend(to: identity).isAllowed {
                baseMessage = nil
                tmpError = "blocked"
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
            ) {
                if !self.sendAsFile,
                   self.fileType == "image/jpeg" || self.fileType == "image/pjpeg" || self
                   .fileType == "image/png" || self.fileType == "image/x-png" || UTIConverter
                   .isGifMimeType(self.fileType) {
                    let imageSender = ImageURLSenderItemCreator()
                    guard let uti = UTIConverter.uti(fromMimeType: self.fileType) else {
                        DDLogError("Image does not have proper UTI")
                        return
                    }
                    guard let item = imageSender.senderItem(from: self.fileData!, uti: uti) else {
                        DDLogError("Could not create URLSenderItem from image")
                        return
                    }
                    item.caption = self.caption
                    let sender = Old_FileMessageSender()
                    self.sendMessage(sender: sender, item: item, conversation: conversation, completion: completion)
                }
                else if !self.sendAsFile,
                        self.fileType == "video/mp4" || self.fileType == "video/mpeg4" || self
                        .fileType == "video/x-m4v" {
                    let creator = VideoURLSenderItemCreator()
                    guard let data = self.fileData else {
                        return
                    }
                    guard let videoURL = VideoURLSenderItemCreator.writeToTemporaryDirectory(data: data) else {
                        return
                    }
                    guard let senderItem = creator.senderItem(from: videoURL) else {
                        return
                    }
                    let fileSender = Old_FileMessageSender()
                    self.sendMessage(sender: fileSender, item: senderItem, conversation: conversation, completion: {
                        do {
                            try FileManager.default.removeItem(at: videoURL)
                        }
                        catch {
                            DDLogError("Could not clear temporary directory \(error)")
                        }

                        completion()
                    })
                }
                // Note: Audio files are always sent as file messages except when they are recorded voice
                // messages inside the app. Thus we don't have a special case for them here.
                else {
                    DispatchQueue.main.async {
                        let blobSender = Old_FileMessageSender()
                        blobSender.fileNameFromWeb = self.name
                        let item = URLSenderItem(
                            data: self.fileData,
                            fileName: blobSender.fileNameFromWeb,
                            type: UTIConverter.uti(fromMimeType: self.fileType),
                            renderType: 0,
                            sendAsFile: true
                        )
                        item?.caption = self.caption
                        self.sendMessage(
                            sender: blobSender,
                            item: item,
                            conversation: conversation,
                            completion: completion
                        )
                    }
                }
            }
        }
        else {
            baseMessage = nil
            tmpError = "internalError"
            completion()
            return
        }
    }
    
    private func sendMessage(
        sender: Old_FileMessageSender,
        item: URLSenderItem?,
        conversation: Conversation?,
        completion: @escaping () -> Void
    ) {
        ServerConnectorHelper.connectAndWaitUntilConnected(initiator: .threemaWeb, timeout: 10) {
            sender.send(item, in: conversation, requestID: self.requestID)
            completion()
            conversation?.conversationVisibility = .default
        } onTimeout: {
            DDLogError("Sending file message timed out")
            completion()
        }
    }
}
