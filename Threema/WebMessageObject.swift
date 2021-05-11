//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

import UIKit
import ThreemaFramework

class WebMessageObject: NSObject {
    var baseMessage: BaseMessage
    var type: String
    var id: String
    var body: String?
    var thumbnail: Dictionary<AnyHashable, Any>?
    var date: Int
    var events: [[String: Any]]?
    var sortKey: UInt64
    var partnerId: String?
    var isOutbox: Bool
    var isStatus: Bool = false
    var caption: String?
    var statusType: String?
    var unread: Bool?
    var state: String?
    var quote: Dictionary<AnyHashable, Any>?
    var file: Dictionary<AnyHashable, Any>?
    var video: Dictionary<AnyHashable, Any>?
    var audio: Dictionary<AnyHashable, Any>?
    var location: Dictionary<AnyHashable, Any>?
    var voip: Dictionary<AnyHashable, Any>?
    
    init(message:BaseMessage, conversation: Conversation, forConversationsRequest: Bool, session: WCSession) {
        baseMessage = message
        type = conversation.isGroup() ? "group" : "contact"
        
        id = message.id.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        let currentDate = message.dateForCurrentState() ?? message.date
        date = Int((currentDate?.timeIntervalSince1970)!)
        let messageEvents = MessageEvents.init(baseMessage: baseMessage)
        events = messageEvents.events
        sortKey = UInt64((message.date.timeIntervalSince1970 * 1000.0).rounded())
        
        if message.sender != nil {
            if message.isOwn.boolValue {
                partnerId = MyIdentityStore.shared().identity
            } else {
                partnerId = message.sender.identity
            }
        }
        else if conversation.contact != nil {
            if message.isOwn.boolValue {
                partnerId = MyIdentityStore.shared().identity
            } else {
                partnerId = conversation.contact.identity
            }
        }
        
        isOutbox = message.isOwn.boolValue
        unread = !message.read.boolValue
        let messageState = message.messageState
        switch messageState {
            case MESSAGE_STATE_SENDING:
                state = "sending"
                break
            case MESSAGE_STATE_SENT:
                state = "sent"
                break
            case MESSAGE_STATE_DELIVERED:
                state = "delivered"
                break
            case MESSAGE_STATE_READ:
                state = "read"
                break
            case MESSAGE_STATE_USER_ACK:
                state = "user-ack"
                break
            case MESSAGE_STATE_USER_DECLINED:
                state = "user-dec"
                break
            case MESSAGE_STATE_FAILED:
                state = "send-failed"
                break
            default:
                state = nil
        }
        
        super.init()
        
        switch message {
        case is TextMessage:
            addTextMessage(message)
        case is ImageMessage:
            addImageMessage(message, forConversationsRequest: forConversationsRequest, session: session)
        case is VideoMessage:
            addVideoMessage(message, forConversationsRequest: forConversationsRequest, session: session)
        case is AudioMessage:
            addAudioMessage(message)
        case is LocationMessage:
            addLocationMessage(message)
        case is FileMessage:
            addFileMessage(message, forConversationsRequest: forConversationsRequest, session: session)
        case is SystemMessage:
            addSystemMessage(message)
        case is BallotMessage:
            addBallotMessage(message)
        default:
            break
        }
    }
    
    init(message:BaseMessage, conversation: Conversation) {
        baseMessage = message
        if conversation.isGroup() {
            type = "group"
        } else {
            type = "contact"
        }
        
        id = message.id.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        var currentDate = message.dateForCurrentState()
        if currentDate == nil {
            currentDate = message.date
        }
        date = Int((currentDate?.timeIntervalSince1970)!)
        sortKey = UInt64((currentDate?.timeIntervalSince1970)!)
        
        isOutbox = message.isOwn.boolValue
        
        if message is SystemMessage {
            let systemMessage = message as! SystemMessage
            if !systemMessage.isCallType() {
                isStatus = true
            }
        }
    }
        
    func objectDict() -> [String: Any] {
        
        var objectDict:[String: Any] = ["type": type, "id": id, "date": date, "isOutbox": isOutbox, "isStatus": isStatus, "sortKey": sortKey]
        
        if events != nil {
             objectDict.updateValue(events!, forKey: "events")
        }
        
        if body != nil {
            objectDict.updateValue(body!, forKey: "body")
        }
        
        if thumbnail != nil {
            objectDict.updateValue(thumbnail!, forKey: "thumbnail")
        }
        
        if partnerId != nil {
            objectDict.updateValue(partnerId!, forKey: "partnerId")
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
        
        return objectDict
    }
    
    func removedObjectDict() -> [String: Any] {
        return ["type": type, "id": id, "date": date, "isOutbox": isOutbox, "isStatus": isStatus, "sortKey": sortKey]
    }
    
    private func addTextMessage(_ message: BaseMessage) {
        let textMessage = message as! TextMessage
        type = "text"
        body = textMessage.text
        thumbnail = nil
        caption = nil
        statusType = "text"
        var remainingBody: NSString?
        var quotedIdentity: String = MyIdentityStore.shared().identity
        if let quotedMessageId = textMessage.quotedMessageId {
            let entityManager = EntityManager()
            if let quotedMessage = entityManager.entityFetcher.message(withId: quotedMessageId, conversation: textMessage.conversation) {
                if let sender = quotedMessage.sender, !quotedMessage.isOwn.boolValue {
                    quotedIdentity = sender.identity
                }
                else if let contact = quotedMessage.conversation.contact, !quotedMessage.isOwn.boolValue {
                    quotedIdentity = contact.identity
                }

                let quotedText = quotedMessage.previewText() ?? ""

                quote = ["identity": quotedIdentity, "text": quotedText, "messageId": quotedMessageId.hexEncodedString()]
                body = textMessage.text
            } else {
                quote = ["identity": "", "text": BundleUtil.localizedString(forKey: "quote_not_found"), "messageId": quotedMessageId.hexEncodedString()]
                body = textMessage.text
            }
        } else {
            var quotedIdentity: NSString?
            
            if let quotedText = QuoteParser.parseQuote(fromMessage: textMessage.text, quotedIdentity: &quotedIdentity, remainingBody: &remainingBody) {
                quote = ["identity": quotedIdentity!, "text": quotedText]
                body = remainingBody as String?
            }
        }
    }
    
    private func addImageMessage(_ message: BaseMessage, forConversationsRequest: Bool, session: WCSession) {
        let imageMessage = message as! ImageMessage
        type = "image"
        body = nil
        statusType = "text"
        
        if imageMessage.image == nil && imageMessage.thumbnail == nil  {
            return
        }
        else if imageMessage.image == nil {
            if imageMessage.thumbnail.data == nil {
                return
            }
        }
        else if imageMessage.thumbnail == nil {
            if imageMessage.image.data == nil {
                return
            }
        }
        else if imageMessage.image.data == nil && imageMessage.thumbnail.data == nil {
            return
        }
        
        if !session.requestedThumbnails(contains: baseMessage.id) {
            let webThumbnail = WebThumbnail.init(imageMessage: imageMessage, onlyThumbnail: true)
            thumbnail = webThumbnail.objectDict()
            
            if !forConversationsRequest {
                session.addRequestedThumbnail(messageId: baseMessage.id)
            }
        }
        
        if let image = imageMessage.image, let imageCaption = image.getCaption() {
            caption = imageCaption
        }
    }
        
    private func addVideoMessage(_ message: BaseMessage, forConversationsRequest: Bool, session: WCSession) {
        let videoMessage = message as! VideoMessage
        type = "video"
        body = nil
        if (videoMessage.thumbnail != nil), !session.requestedThumbnails(contains: baseMessage.id) {
            let webThumbnail = WebThumbnail.init(videoMessage, onlyThumbnail: true)
            thumbnail = webThumbnail.objectDict()
            
            if !forConversationsRequest {
                session.addRequestedThumbnail(messageId: baseMessage.id)
            }
        }
        caption = nil
        statusType = "text"
        let webVideo = WebVideo.init(videoMessage)
        video = webVideo.objectDict()
    }
    
    private func addAudioMessage(_ message: BaseMessage) {
        let audioMessage = message as! AudioMessage
        type = "audio"
        body = nil
        thumbnail = nil
        caption = nil
        statusType = "text"
        let webAudio = WebAudio.init(audioMessage)
        audio = webAudio.objectDict()
    }
    
    private func addLocationMessage(_ message: BaseMessage) {
        let locationMessage = message as! LocationMessage
        type = "location"
        body = nil
        thumbnail = nil
        caption = nil
        statusType = "text"
        let webLocation = WebLocation.init(locationMessage)
        location = webLocation.objectDict()
    }
    
    private func addFileMessage(_ message: BaseMessage, forConversationsRequest: Bool, session: WCSession) {
        let fileMessage = message as! FileMessage
        body = nil
        thumbnail = nil
        
        if let fileThumbnail = fileMessage.thumbnail, fileThumbnail.data != nil {
            if let thumbnailID = fileMessage.blobThumbnailId {
                if !session.requestedThumbnails(contains: thumbnailID) {
                    let webThumbnail = WebThumbnail.init(fileMessage, onlyThumbnail: true)
                    thumbnail = webThumbnail.objectDict()
                    
                    if !forConversationsRequest {
                        session.addRequestedThumbnail(messageId: thumbnailID)
                    }
                }
            } else {
                let webThumbnail = WebThumbnail.init(fileMessage, onlyThumbnail: true)
                thumbnail = webThumbnail.objectDict()
            }
        }
        
        if let fileCaption = fileMessage.caption {
            caption = fileCaption
        }
        statusType = "text"
        
        if fileMessage.renderFileImageMessage() {
            type = "image"
        }
        else if fileMessage.renderFileVideoMessage() {
            type = "video"
            let webVideo = WebVideo.init(fileMessage)
            video = webVideo.objectDict()
        }
        else if fileMessage.renderFileAudioMessage() {
            type = "audio"
            let webAudio = WebAudio.init(fileMessage)
            audio = webAudio.objectDict()
        }
        else {
            type = "file"
            let webFile = WebFile.init(fileMessage)
            file = webFile.objectDict()
        }
    }
    
    private func addSystemMessage(_ message: BaseMessage) {
        let systemMessage = message as! SystemMessage
        if systemMessage.isCallType() {
            // voip
            type = "voipStatus"
            body = nil
            thumbnail = nil
            caption = nil
            state = nil
            statusType = "text"
            
            if systemMessage.arg != nil {
                do {
                    let argDict = try JSONSerialization.jsonObject(with: systemMessage.arg, options: .allowFragments) as! [AnyHashable: Any]
                    isOutbox = argDict["CallInitiator"] as! Bool
                }
                catch {
                    isOutbox = false
                }
            } else {
                isOutbox = true
            }
            
            let webVoip = WebVoip.init(systemMessage)
            voip = webVoip.objectDict()
        } else {
            type = "text"
            body = systemMessage.format()
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
        if baseMessage.isOwn.boolValue == true {
            if baseMessage.remoteSentDate != nil {
                var event = [String: Any]()
                event.updateValue("sent", forKey: "type")
                event.updateValue(Int((baseMessage.remoteSentDate.timeIntervalSince1970)), forKey: "date")
                events.append(event)
            }
            if baseMessage.deliveryDate != nil {
                var event = [String: Any]()
                event.updateValue("delivered", forKey: "type")
                event.updateValue(Int((baseMessage.deliveryDate.timeIntervalSince1970)), forKey: "date")
                events.append(event)
            }
            if baseMessage.readDate != nil {
                var event = [String: Any]()
                event.updateValue("read", forKey: "type")
                event.updateValue(Int((baseMessage.readDate.timeIntervalSince1970)), forKey: "date")
                events.append(event)
            }
        } else {
            if baseMessage.date != nil {
                var event = [String: Any]()
                event.updateValue("sent", forKey: "type")
                event.updateValue(Int((baseMessage.remoteSentDate.timeIntervalSince1970)), forKey: "date")
                events.append(event)
            }
            if baseMessage.deliveryDate != nil {
                var event = [String: Any]()
                event.updateValue("delivered", forKey: "type")
                event.updateValue(Int((baseMessage.deliveryDate.timeIntervalSince1970)), forKey: "date")
                events.append(event)
            }
            if baseMessage.readDate != nil {
                var event = [String: Any]()
                event.updateValue("read", forKey: "type")
                event.updateValue(Int((baseMessage.readDate.timeIntervalSince1970)), forKey: "date")
                events.append(event)
            }
            if baseMessage.userackDate != nil {
                var event = [String: Any]()
                event.updateValue("acked", forKey: "type")
                event.updateValue(Int((baseMessage.userackDate.timeIntervalSince1970)), forKey: "date")
                events.append(event)
            }
        }
    }
}

struct WebBlob {
    var blob: Data?
    var type: String
    var name: String
    
    init(imageMessage: ImageMessage) {
        if imageMessage.image.data != nil {
            blob = imageMessage.image.data
        }
        name = imageMessage.blobGetWebFilename()
        type = "image/\(MEDIA_EXTENSION_IMAGE)"
    }
    
    init(videoMessage: VideoMessage) {
        if videoMessage.video.data != nil {
            blob = videoMessage.video.data
        }
        name = videoMessage.blobGetWebFilename()
        type = "video/\(MEDIA_EXTENSION_VIDEO)"
    }
    
    init(audioMessage: AudioMessage) {
        if audioMessage.audio.data != nil {
            blob = audioMessage.audio.data
        }
        name = audioMessage.blobGetWebFilename()
        type = "audio/\(MEDIA_EXTENSION_VIDEO)"
    }
    
    init(fileMessage: FileMessage) {
        if let fileMessageData = fileMessage.data {
            blob = fileMessageData.data
        }
        name = fileMessage.blobGetWebFilename()
        if fileMessage.renderFileAudioMessage() {
            type = "audio/\(MEDIA_EXTENSION_VIDEO)"
        } else {
            type = fileMessage.mimeType ?? "application/octet-stream"
        }
    }
    
    func objectDict() -> [String: Any] {
        var objectDict:[String: Any] = ["type": type, "name": name]
        
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
    
    init(imageMessage: ImageMessage, onlyThumbnail: Bool) {
        if !onlyThumbnail, let origImage = imageMessage.image, let origImageData = origImage.data, let tmpPreview = MediaConverter.getWebPreviewData(origImageData) {
            let size = MediaConverter.getWebThumbnailSize(forImageData: origImageData)
            height = Int(size.height)
            width = Int(size.width)
            preview = tmpPreview
            image = MediaConverter.getWebThumbnailData(origImageData)
        }
        else if let thumbnail = imageMessage.thumbnail, let thumbnailData = thumbnail.data, let tmpPreview = MediaConverter.getWebPreviewData(thumbnailData) {
            let size = MediaConverter.getWebThumbnailSize(forImageData: thumbnailData)
            height = Int(size.height)
            width = Int(size.width)
            preview = tmpPreview
            var thumbnailImageData : Data
            if !onlyThumbnail, let image = imageMessage.image, let imageData = image.data {
                thumbnailImageData = imageData
            } else {
                thumbnailImageData = thumbnailData
            }
            image = MediaConverter.getWebThumbnailData(thumbnailImageData)
        }
        else if let origImage = imageMessage.image, let origImageData = origImage.data, let tmpPreview = MediaConverter.getWebPreviewData(origImageData) {
            let size = MediaConverter.getWebThumbnailSize(forImageData: origImageData)
            height = Int(size.height)
            width = Int(size.width)
            preview = tmpPreview
            image = MediaConverter.getWebThumbnailData(origImageData)
        }
        else {
            height = Int(44)
            width = Int(44)
            preview = UIImage.init(named: "Thumbnail")!.pngData()!
            image = preview
        }
    }
    
    init(_ videoMessage: VideoMessage, onlyThumbnail: Bool) {
        let size = MediaConverter.getWebThumbnailSize(forImageData: videoMessage.thumbnail.data)
        height = Int(size.height)
        width = Int(size.width)
        if let tmpPreview = MediaConverter.getWebPreviewData(videoMessage.thumbnail.data) {
            preview = tmpPreview
        } else {
            height = Int(44)
            width = Int(44)
            preview = UIImage.init(named: "Thumbnail")!.pngData()!
        }
        
        if !onlyThumbnail, let thumbnail = videoMessage.thumbnail, let thumbnailData = thumbnail.data {
            image = MediaConverter.getWebThumbnailData(thumbnailData)
        }
    }
    
    init(_ fileMessage: FileMessage, onlyThumbnail: Bool) {
        if let thumbnail = fileMessage.thumbnail, let thumbnailData = thumbnail.data, let tmpPreview = MediaConverter.getWebPreviewData(thumbnailData) {
            let size = MediaConverter.getWebThumbnailSize(forImageData: thumbnailData)
            height = Int(size.height)
            width = Int(size.width)
            preview = tmpPreview
        } else {
            height = Int(44)
            width = Int(44)
            preview = UIImage.init(named: "Thumbnail")!.pngData()!
        }
        
        if !onlyThumbnail, let thumbnail = fileMessage.thumbnail, let thumbnailData = thumbnail.data {
            image = MediaConverter.getWebThumbnailData(thumbnailData)
        }
    }
    
    func objectDict() -> [String: Any] {
        return ["height": height, "width": width, "preview": preview]
    }
}

struct WebVideo {
    var duration: Int
    var size: Int
    
    init(_ videoMessage: VideoMessage) {
        duration = videoMessage.duration.intValue
        size = videoMessage.videoSize.intValue
    }
    
    init (_ fileMessage: FileMessage) {
        if let videoDuration = fileMessage.duration {
            duration = videoDuration.intValue
        } else {
            duration = 0
        }
        if let videoSize = fileMessage.fileSize {
            size = videoSize.intValue
        } else {
            size = 0
        }
    }
    
    func objectDict() -> [String: Any] {
        return ["duration": duration, "size": size]
    }
}

struct WebAudio {
    var duration: Int
    
    init(_ audioMessage: AudioMessage) {
        duration = audioMessage.duration.intValue
    }
    
    init (_ fileMessage: FileMessage) {
        if let audioDuration = fileMessage.duration {
            duration = audioDuration.intValue
        } else {
            duration = 0
        }
    }
    
    func objectDict() -> [String: Any] {
        return ["duration": duration]
    }
}

struct WebLocation {
    var lat: Float
    var lon: Float
    var accuracy: Float
    var address: String?
    var description: String?
    
    init(_ locationMessage: LocationMessage) {
        lat = locationMessage.latitude.floatValue
        lon = locationMessage.longitude.floatValue
        accuracy = locationMessage.accuracy.floatValue
        address = nil
        description = locationMessage.poiName
    }
    
    func objectDict() -> [String: Any] {
        var objectDict:[String: Any] = ["lat": lat, "lon": lon, "accuracy": accuracy]
        
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
    
    init(_ fileMessage: FileMessage) {
        name = fileMessage.fileName!
        size = fileMessage.fileSize!.intValue
        type = fileMessage.mimeType!
        inApp = false
    }
    
    func objectDict() -> [String: Any] {
        return ["name": name, "size": size, "type": type, "inApp": inApp]
    }
}

struct WebVoip {
    var status: Int
    var duration: Int?
    var reason: Int?
    
    init(_ systemMessage: SystemMessage) {
        switch systemMessage.type.intValue {
            case kSystemMessageCallMissed:
                status = 1
                break
            case kSystemMessageCallRejected:
                status = 3
                break
            case kSystemMessageCallRejectedBusy:
                status = 3
                break
            case kSystemMessageCallRejectedTimeout:
                status = 3
                break
            case kSystemMessageCallEnded:
                if systemMessage.haveCallTime() {
                    status = 2
                } else {
                    status = 4
                }
                break
            case kSystemMessageCallRejectedDisabled:
                status = 3
                break
            default:
                status = 2
        }
        
        if let callTime = systemMessage.callTime() {
            duration = Int(DateFormatter.totalSeconds(callTime))
        }

        switch systemMessage.type.intValue {
        case kSystemMessageCallRejected:
            reason = 3
            break
        case kSystemMessageCallRejectedBusy:
            reason = 1
            break
        case kSystemMessageCallRejectedTimeout:
            reason = 2
            break
        case kSystemMessageCallRejectedDisabled:
            reason = 4
            break
        default:
            break
        }
    }
    
    func objectDict() -> [String: Any] {
        var objectDict:[String: Any] = ["status": status]
        
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
        return withUnsafeBytes { $0.pointee }
    }
}

extension Numeric {
    var makeData: Data {
        var source = self
        // This will return 1 byte for 8-bit, 2 bytes for 16-bit, 4 bytes for 32-bit and 8 bytes for 64-bit binary integers. For floating point types it will return 4 bytes for single-precision, 8 bytes for double-precision and 16 bytes for extended precision.
        return Data(bytes: &source, count: MemoryLayout<Self>.size)
    }
}

