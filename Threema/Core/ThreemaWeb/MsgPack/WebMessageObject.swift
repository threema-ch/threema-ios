//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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

import ThreemaFramework
import ThreemaMacros
import UIKit

class WebMessageObject: NSObject {
    var baseMessage: BaseMessage
    var type: String
    var id: String
    var body: String?
    var thumbnail: [AnyHashable: Any]?
    var date: Int
    var events: [[String: Any]]?
    var sortKey: UInt64
    var partnerID: String?
    var isOutbox: Bool
    var isStatus = false
    var caption: String?
    var statusType: String?
    var unread: Bool?
    var state: String?
    var quote: [AnyHashable: Any]?
    var file: [AnyHashable: Any]?
    var video: [AnyHashable: Any]?
    var audio: [AnyHashable: Any]?
    var location: [AnyHashable: Any]?
    var voip: [AnyHashable: Any]?
    var reactions: [AnyHashable: [String]]?
    var lastEditedAt: UInt64?

    init(message: BaseMessage, conversation: ConversationEntity, forConversationsRequest: Bool, session: WCSession) {
        self.baseMessage = message
        self.type = conversation.isGroup ? "group" : "contact"
        
        self.id = message.id.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        self.date = Int(message.displayDate.timeIntervalSince1970)
        let messageEvents = MessageEvents(baseMessage: baseMessage)
        self.events = messageEvents.events
        self.sortKey = UInt64((message.date.timeIntervalSince1970 * 1000.0).rounded())
        
        if let sender = message.sender {
            if message.isOwnMessage {
                // This should never be true
                self.partnerID = MyIdentityStore.shared().identity
            }
            else {
                self.partnerID = sender.identity
            }
        }
        else if let contact = conversation.contact {
            if message.isOwnMessage {
                self.partnerID = MyIdentityStore.shared().identity
            }
            else {
                self.partnerID = contact.identity
            }
        }
        
        self.isOutbox = message.isOwnMessage
        self.unread = !message.read.boolValue
        let messageState = message.messageState
        switch messageState {
        case .sending:
            self.state = "sending"
        case .sent:
            self.state = "sent"
        case .delivered:
            self.state = "delivered"
        case .read:
            self.state = "read"
        case .received:
            self.state = "sent"
        case .userAcknowledged:
            self.state = "user-ack"
        case .userDeclined:
            self.state = "user-dec"
        case .failed:
            self.state = "send-failed"
        }
        
        if conversation.isGroup {
            self.reactions = message.groupReactionsDictForWeb()
        }

        if let lastEditedAt = message.lastEditedAt {
            self.lastEditedAt = lastEditedAt.millisecondsSince1970 / 1000
        }

        super.init()
        
        switch message {
        case is TextMessageEntity:
            addTextMessage(message)
        case is ImageMessageEntity:
            addImageMessage(message, forConversationsRequest: forConversationsRequest, session: session)
        case is VideoMessageEntity:
            addVideoMessage(message, forConversationsRequest: forConversationsRequest, session: session)
        case is AudioMessageEntity:
            addAudioMessage(message)
        case is LocationMessageEntity:
            addLocationMessage(message)
        case is FileMessageEntity:
            addFileMessage(message, forConversationsRequest: forConversationsRequest, session: session)
        case is SystemMessageEntity:
            addSystemMessage(message)
        case is BallotMessage:
            addBallotMessage(message)
        default:
            break
        }
    }
    
    init(message: BaseMessage, conversation: ConversationEntity) {
        self.baseMessage = message
        if conversation.isGroup {
            self.type = "group"
        }
        else {
            self.type = "contact"
        }
        
        self.id = message.id.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        let currentDate = message.displayDate
        self.date = Int(currentDate.timeIntervalSince1970)
        self.sortKey = UInt64(currentDate.timeIntervalSince1970)
        
        self.isOutbox = message.isOwnMessage
        
        if let systemMessage = message as? SystemMessageEntity {
            if case .callMessage = systemMessage.systemMessageType {
                self.isStatus = false
            }
            else {
                self.isStatus = true
            }
        }
    }
        
    func objectDict() -> [String: Any] {
        
        var objectDict: [String: Any] = [
            "type": type,
            "id": id,
            "date": date,
            "isOutbox": isOutbox,
            "isStatus": isStatus,
            "sortKey": sortKey,
        ]
        
        if events != nil {
            objectDict.updateValue(events!, forKey: "events")
        }
        
        if body != nil {
            objectDict.updateValue(body!, forKey: "body")
        }
        
        if thumbnail != nil {
            objectDict.updateValue(thumbnail!, forKey: "thumbnail")
        }
        
        if partnerID != nil {
            objectDict.updateValue(partnerID!, forKey: "partnerId")
        }
        
        if caption != nil {
            objectDict.updateValue(caption!, forKey: "caption")
        }
        
        if statusType != nil {
            objectDict.updateValue(statusType!, forKey: "statusType")
        }
        
        if unread != nil {
            objectDict.updateValue(unread!, forKey: "unread")
        }
        
        if state != nil {
            objectDict.updateValue(state!, forKey: "state")
        }
        
        if quote != nil {
            objectDict.updateValue(quote!, forKey: "quote")
        }
        
        if file != nil {
            objectDict.updateValue(file!, forKey: "file")
        }
        
        if video != nil {
            objectDict.updateValue(video!, forKey: "video")
        }
        
        if audio != nil {
            objectDict.updateValue(audio!, forKey: "audio")
        }
        
        if location != nil {
            objectDict.updateValue(location!, forKey: "location")
        }
        
        if voip != nil {
            objectDict.updateValue(voip!, forKey: "voip")
        }
        
        if let reactions {
            objectDict.updateValue(reactions, forKey: "reactions")
        }

        if let lastEditedAt {
            objectDict.updateValue(lastEditedAt, forKey: "lastEditedAt")
        }

        return objectDict
    }
    
    func removedObjectDict() -> [String: Any] {
        ["type": type, "id": id, "date": date, "isOutbox": isOutbox, "isStatus": isStatus, "sortKey": sortKey]
    }
    
    private func addTextMessage(_ message: BaseMessage) {
        let textMessage = message as! TextMessageEntity
        type = "text"
        body = textMessage.text
        thumbnail = nil
        caption = nil
        statusType = "text"
        var remainingBody: NSString?
        var quotedIdentity: String = MyIdentityStore.shared().identity
        // swiftformat:disable:next acronyms
        if let quotedMessageID = textMessage.quotedMessageId {
            let entityManager = EntityManager()
            if let quotedMessage = entityManager.entityFetcher.message(
                with: quotedMessageID,
                conversation: textMessage.conversation
            ) as? PreviewableMessage {
                if let sender = quotedMessage.sender, !quotedMessage.isOwnMessage {
                    quotedIdentity = sender.identity
                }
                else if let contact = quotedMessage.conversation?.contact, !quotedMessage.isOwnMessage {
                    quotedIdentity = contact.identity
                }
                
                let quotedText = quotedMessage.previewText

                quote = [
                    "identity": quotedIdentity,
                    "text": quotedText,
                    "messageId": quotedMessageID.hexEncodedString(),
                ]
                body = textMessage.text
            }
            else {
                quote = [
                    "identity": "",
                    "text": #localize("quote_not_found"),
                    "messageId": quotedMessageID.hexEncodedString(),
                ]
                body = textMessage.text
            }
        }
        else {
            var quotedIdentity: NSString?
            
            if let quotedText = QuoteUtil.parseQuote(
                fromMessage: textMessage.text,
                quotedIdentity: &quotedIdentity,
                remainingBody: &remainingBody
            ) {
                quote = ["identity": quotedIdentity!, "text": quotedText]
                body = remainingBody as String?
            }
        }
    }
    
    private func addImageMessage(_ message: BaseMessage, forConversationsRequest: Bool, session: WCSession) {
        let imageMessageEntity = message as! ImageMessageEntity
        type = "image"
        body = nil
        statusType = "text"
        
        if imageMessageEntity.image == nil, imageMessageEntity.thumbnail == nil {
            return
        }
        else if imageMessageEntity.image == nil {
            if imageMessageEntity.thumbnail?.data == nil {
                return
            }
        }
        else if imageMessageEntity.thumbnail == nil {
            if imageMessageEntity.image?.data == nil {
                return
            }
        }
        else if imageMessageEntity.image?.data == nil,
                imageMessageEntity.thumbnail?.data == nil {
            return
        }
        
        if !session.requestedThumbnails(contains: baseMessage.id) {
            let webThumbnail = WebThumbnail(imageMessageEntity: imageMessageEntity, onlyThumbnail: true)
            thumbnail = webThumbnail.objectDict()
            
            if !forConversationsRequest {
                session.addRequestedThumbnail(messageID: baseMessage.id)
            }
        }
        
        if let image = imageMessageEntity.image, let imageCaption = image.caption() {
            caption = imageCaption
        }
    }
        
    private func addVideoMessage(_ message: BaseMessage, forConversationsRequest: Bool, session: WCSession) {
        let videoMessageEntity = message as! VideoMessageEntity
        type = "video"
        body = nil
        if videoMessageEntity.thumbnail != nil, !session.requestedThumbnails(contains: baseMessage.id) {
            let webThumbnail = WebThumbnail(videoMessageEntity, onlyThumbnail: true)
            thumbnail = webThumbnail.objectDict()
            
            if !forConversationsRequest {
                session.addRequestedThumbnail(messageID: baseMessage.id)
            }
        }
        caption = nil
        statusType = "text"
        let webVideo = WebVideo(videoMessageEntity)
        video = webVideo.objectDict()
    }
    
    private func addAudioMessage(_ message: BaseMessage) {
        let audioMessageEntity = message as! AudioMessageEntity
        type = "audio"
        body = nil
        thumbnail = nil
        caption = nil
        statusType = "text"
        let webAudio = WebAudio(audioMessageEntity)
        audio = webAudio.objectDict()
    }
    
    private func addLocationMessage(_ message: BaseMessage) {
        let locationMessage = message as! LocationMessageEntity
        type = "location"
        body = nil
        thumbnail = nil
        caption = nil
        statusType = "text"
        let webLocation = WebLocation(locationMessage)
        location = webLocation.objectDict()
    }
    
    private func addFileMessage(_ message: BaseMessage, forConversationsRequest: Bool, session: WCSession) {
        let fileMessageEntity = message as! FileMessageEntity
        body = nil
        thumbnail = nil
        
        if let fileThumbnail = fileMessageEntity.thumbnail {
            // swiftformat:disable:next acronyms
            if let thumbnailID = fileMessageEntity.blobThumbnailId {
                if !session.requestedThumbnails(contains: thumbnailID) {
                    let webThumbnail = WebThumbnail(fileMessageEntity, onlyThumbnail: true)
                    thumbnail = webThumbnail.objectDict()
                    
                    if !forConversationsRequest {
                        session.addRequestedThumbnail(messageID: thumbnailID)
                    }
                }
            }
            else {
                let webThumbnail = WebThumbnail(fileMessageEntity, onlyThumbnail: true)
                thumbnail = webThumbnail.objectDict()
            }
        }
        
        if let fileCaption = fileMessageEntity.caption {
            caption = fileCaption
        }
        statusType = "text"
        
        if fileMessageEntity.renderFileImageMessage {
            type = "image"
        }
        else if fileMessageEntity.renderFileVideoMessage {
            type = "video"
            let webVideo = WebVideo(fileMessageEntity)
            video = webVideo.objectDict()
        }
        else if fileMessageEntity.renderFileAudioMessage {
            type = "audio"
            let webAudio = WebAudio(fileMessageEntity)
            audio = webAudio.objectDict()
        }
        else {
            guard let name = fileMessageEntity.fileName, let size = fileMessageEntity.fileSize?.intValue,
                  let mimeType = fileMessageEntity.mimeType else {
                return
            }
            type = "file"
            let webFile = WebFile(name: name, size: size, mimeType: mimeType)
            file = webFile.objectDict()
        }
    }
    
    private func addSystemMessage(_ message: BaseMessage) {
        let systemMessage = message as! SystemMessageEntity
        if case .callMessage = systemMessage.systemMessageType {
            // voip
            type = "voipStatus"
            body = nil
            thumbnail = nil
            caption = nil
            state = nil
            statusType = "text"
            
            if let arg = systemMessage.arg {
                do {
                    let argDict = try JSONSerialization.jsonObject(
                        with: arg,
                        options: .allowFragments
                    ) as! [AnyHashable: Any]
                    isOutbox = argDict["CallInitiator"] as! Bool
                }
                catch {
                    isOutbox = false
                }
            }
            else {
                isOutbox = true
            }
            
            let webVoip = WebVoip(systemMessage)
            voip = webVoip.objectDict()
        }
        else {
            
            body =
                switch systemMessage.systemMessageType {
                case let .systemMessage(type):
                    type.localizedMessage
                case let .callMessage(type):
                    type.localizedMessage
                case let .workConsumerInfo(type):
                    type.localizedMessage
                }
            type = "text"
            thumbnail = nil
            isStatus = true
            caption = nil
            statusType = "text"
        }
    }
    
    private func addBallotMessage(_ message: BaseMessage) {
        type = "ballot"
        isStatus = false
        statusType = "text"
    }
}

struct MessageEvents {
    
    var events = [[String: Any]]()
    
    init(baseMessage: BaseMessage) {
        if baseMessage.isOwnMessage {
            if baseMessage.remoteSentDate != nil {
                var event = [String: Any]()
                event.updateValue("sent", forKey: "type")
                event.updateValue(Int(baseMessage.remoteSentDate.timeIntervalSince1970), forKey: "date")
                events.append(event)
            }
            if let deliveryDate = baseMessage.deliveryDate {
                var event = [String: Any]()
                event.updateValue("delivered", forKey: "type")
                event.updateValue(Int(deliveryDate.timeIntervalSince1970), forKey: "date")
                events.append(event)
            }
            if let readDate = baseMessage.readDate {
                var event = [String: Any]()
                event.updateValue("read", forKey: "type")
                event.updateValue(Int(readDate.timeIntervalSince1970), forKey: "date")
                events.append(event)
            }
        }
        else {
            if baseMessage.date != nil {
                var event = [String: Any]()
                event.updateValue("sent", forKey: "type")
                event.updateValue(Int(baseMessage.remoteSentDate.timeIntervalSince1970), forKey: "date")
                events.append(event)
            }
            if let deliveryDate = baseMessage.deliveryDate {
                var event = [String: Any]()
                event.updateValue("delivered", forKey: "type")
                event.updateValue(Int(deliveryDate.timeIntervalSince1970), forKey: "date")
                events.append(event)
            }
            if let readDate = baseMessage.readDate {
                var event = [String: Any]()
                event.updateValue("read", forKey: "type")
                event.updateValue(Int(readDate.timeIntervalSince1970), forKey: "date")
                events.append(event)
            }
            if let userackDate = baseMessage.userackDate {
                var event = [String: Any]()
                event.updateValue("acked", forKey: "type")
                event.updateValue(Int(userackDate.timeIntervalSince1970), forKey: "date")
                events.append(event)
            }
        }
    }
}

struct WebBlob {
    var blob: Data?
    var type: String
    var name: String
    
    init(imageMessageEntity: ImageMessageEntity) {
        if let imageMessageData = imageMessageEntity.image?.data {
            self.blob = imageMessageData
        }
        self.name = imageMessageEntity.blobWebFilename
        self.type = "image/\(MEDIA_EXTENSION_IMAGE)"
    }
    
    init(videoMessageEntity: VideoMessageEntity) {
        if let videoMessageData = videoMessageEntity.video?.data {
            self.blob = videoMessageData
        }
        self.name = videoMessageEntity.blobWebFilename
        self.type = "video/\(MEDIA_EXTENSION_VIDEO)"
    }
    
    init(audioMessageEntity: AudioMessageEntity) {
        self.blob = audioMessageEntity.audio?.data
        self.name = audioMessageEntity.blobWebFilename
        self.type = "audio/\(MEDIA_EXTENSION_VIDEO)"
    }
    
    init(fileMessageEntity: FileMessageEntity) {
        if let fileMessageData = fileMessageEntity.data?.data {
            self.blob = fileMessageData
        }
        self.name = fileMessageEntity.blobWebFilename
        if fileMessageEntity.renderType == .voiceMessage {
            self.type = "audio/\(MEDIA_EXTENSION_VIDEO)"
        }
        else {
            self.type = fileMessageEntity.mimeType ?? "application/octet-stream"
        }
    }
    
    func objectDict() -> [String: Any] {
        var objectDict: [String: Any] = ["type": type, "name": name]
        
        if blob != nil {
            objectDict.updateValue(blob!, forKey: "blob")
        }
        
        return objectDict
    }
}

struct WebThumbnail {
    var height: Int
    var width: Int
    var preview: Data
    var image: Data?
    
    init(imageMessageEntity: ImageMessageEntity, onlyThumbnail: Bool) {
        if !onlyThumbnail, let origImage = imageMessageEntity.image,
           let tmpPreview = MediaConverter.getWebPreviewData(origImage.data) {
            let size = MediaConverter.getWebThumbnailSize(forImageData: origImage.data)
            self.height = Int(size.height)
            self.width = Int(size.width)
            self.preview = tmpPreview
            self.image = MediaConverter.getWebThumbnailData(origImage.data)
        }
        else if let thumbnail = imageMessageEntity.thumbnail,
                let tmpPreview = MediaConverter.getWebPreviewData(thumbnail.data) {
            let size = MediaConverter.getWebThumbnailSize(forImageData: thumbnail.data)
            self.height = Int(size.height)
            self.width = Int(size.width)
            self.preview = tmpPreview
            let thumbnailImageData: Data =
                if !onlyThumbnail, let image = imageMessageEntity.image {
                    image.data
                }
                else {
                    thumbnail.data
                }
            self.image = MediaConverter.getWebThumbnailData(thumbnailImageData)
        }
        else if let origImage = imageMessageEntity.image,
                let tmpPreview = MediaConverter.getWebPreviewData(origImage.data) {
            let size = MediaConverter.getWebThumbnailSize(forImageData: origImage.data)
            self.height = Int(size.height)
            self.width = Int(size.width)
            self.preview = tmpPreview
            self.image = MediaConverter.getWebThumbnailData(origImage.data)
        }
        else {
            self.height = Int(44)
            self.width = Int(44)
            self.preview = UIImage(systemName: "questionmark.app.fill")!.pngData()!
            self.image = preview
        }
    }
    
    init(_ videoMessageEntity: VideoMessageEntity, onlyThumbnail: Bool) {
        if let thumbnailData = videoMessageEntity.thumbnail?.data,
           let tmpPreview = MediaConverter.getWebPreviewData(thumbnailData) {
            let size = MediaConverter.getWebThumbnailSize(forImageData: thumbnailData)
            self.height = Int(size.height)
            self.width = Int(size.width)
            
            self.preview = tmpPreview
        }
        else {
            self.height = Int(44)
            self.width = Int(44)
            
            self.preview = UIImage(systemName: "questionmark.app.fill")!.pngData()!
        }
        
        if !onlyThumbnail, let thumbnail = videoMessageEntity.thumbnail {
            self.image = MediaConverter.getWebThumbnailData(thumbnail.data)
        }
    }
    
    init(_ fileMessageEntity: FileMessageEntity, onlyThumbnail: Bool) {
        if let thumbnail = fileMessageEntity.thumbnail,
           let tmpPreview = MediaConverter.getWebPreviewData(thumbnail.data) {
            let size = MediaConverter.getWebThumbnailSize(forImageData: thumbnail.data)
            self.height = Int(size.height)
            self.width = Int(size.width)
            self.preview = tmpPreview
        }
        else {
            self.height = Int(44)
            self.width = Int(44)
            self.preview = UIImage(systemName: "questionmark.app.fill")!.pngData()!
        }
        
        if !onlyThumbnail, let thumbnail = fileMessageEntity.thumbnail {
            self.image = MediaConverter.getWebThumbnailData(thumbnail.data)
        }
    }
    
    func objectDict() -> [String: Any] {
        ["height": height, "width": width, "preview": preview]
    }
}

struct WebVideo {
    var duration: Int
    var size: Int
    
    init(_ videoMessageEntity: VideoMessageEntity) {
        self.duration = videoMessageEntity.duration.intValue
        self.size = videoMessageEntity.videoSize?.intValue ?? 0
    }
    
    init(_ fileMessageEntity: FileMessageEntity) {
        if let videoDuration = fileMessageEntity.duration {
            self.duration = Int(videoDuration)
        }
        else {
            self.duration = 0
        }
        if let videoSize = fileMessageEntity.fileSize {
            self.size = Int(truncating: videoSize)
        }
        else {
            self.size = 0
        }
    }
    
    func objectDict() -> [String: Any] {
        ["duration": duration, "size": size]
    }
}

struct WebAudio {
    var duration: Int
    
    init(_ audioMessageEntity: AudioMessageEntity) {
        self.duration = audioMessageEntity.duration.intValue
    }
    
    init(_ fileMessageEntity: FileMessageEntity) {
        if let audioDuration = fileMessageEntity.duration {
            self.duration = Int(audioDuration)
        }
        else {
            self.duration = 0
        }
    }
    
    func objectDict() -> [String: Any] {
        ["duration": duration]
    }
}

struct WebLocation {
    var lat: Float
    var lon: Float
    var accuracy: Float
    var address: String?
    var description: String?
    
    init(_ locationMessage: LocationMessageEntity) {
        self.lat = locationMessage.latitude.floatValue
        self.lon = locationMessage.longitude.floatValue
        self.accuracy = locationMessage.accuracy?.floatValue ?? 0.0
        self.address = nil
        self.description = locationMessage.poiName
    }
    
    func objectDict() -> [String: Any] {
        var objectDict: [String: Any] = ["lat": lat, "lon": lon, "accuracy": accuracy]
        
        if address != nil {
            objectDict.updateValue(address!, forKey: "address")
        }
        if description != nil {
            objectDict.updateValue(description!, forKey: "description")
        }
        return objectDict
    }
}

struct WebFile {
    var name: String
    var size: Int
    var type: String
    var inApp: Bool
    
    init(name: String, size: Int, mimeType: String) {
        self.name = name
        self.size = size
        self.type = mimeType
        self.inApp = false
    }
    
    func objectDict() -> [String: Any] {
        ["name": name, "size": size, "type": type, "inApp": inApp]
    }
}

struct WebVoip {
    var status: Int
    var duration: Int?
    var reason: Int?
    
    init(_ systemMessage: SystemMessageEntity) {
        switch systemMessage.type.intValue {
        case kSystemMessageCallMissed:
            self.status = 1
        case kSystemMessageCallRejected:
            self.status = 3
        case kSystemMessageCallRejectedBusy:
            self.status = 3
        case kSystemMessageCallRejectedTimeout:
            self.status = 3
        case kSystemMessageCallEnded:
            if systemMessage.callDuration() != nil {
                self.status = 2
            }
            else {
                self.status = 4
            }
        case kSystemMessageCallRejectedDisabled:
            self.status = 3
        default:
            self.status = 2
        }
        
        if let callTime = systemMessage.callDuration() {
            self.duration = Int(DateFormatter.totalSeconds(callTime))
        }

        switch systemMessage.type.intValue {
        case kSystemMessageCallRejected:
            self.reason = 3
        case kSystemMessageCallRejectedBusy:
            self.reason = 1
        case kSystemMessageCallRejectedTimeout:
            self.reason = 2
        case kSystemMessageCallRejectedDisabled:
            self.reason = 4
        default:
            break
        }
    }
    
    func objectDict() -> [String: Any] {
        var objectDict: [String: Any] = ["status": status]
        
        if duration != nil {
            objectDict.updateValue(duration!, forKey: "duration")
        }
        if reason != nil {
            objectDict.updateValue(reason!, forKey: "reason")
        }
        return objectDict
    }
}

extension Data {
    var integer: UInt64 {
        withUnsafeBytes { $0.load(as: UInt64.self) }
    }
}

extension Numeric {
    var makeData: Data {
        var source = self
        // This will return 1 byte for 8-bit, 2 bytes for 16-bit, 4 bytes for 32-bit and 8 bytes for 64-bit binary
        // integers. For floating point types it will return 4 bytes for single-precision, 8 bytes for double-precision
        // and 16 bytes for extended precision.
        return Data(bytes: &source, count: MemoryLayout<Self>.size)
    }
}
