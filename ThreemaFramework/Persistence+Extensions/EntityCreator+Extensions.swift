//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import Foundation

extension EntityCreator {
    
    // MARK: Text message
    
    func textMessageEntity(
        from abstractMessage: BoxTextMessage,
        in conversation: ConversationEntity
    ) -> TextMessageEntity {
        textMessageEntity(
            messageID: abstractMessage.messageID,
            text: abstractMessage.text,
            quotedMessageID: abstractMessage.quotedMessageID,
            date: abstractMessage.date,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversation
        )
    }
    
    func textMessageEntity(
        from abstractMessage: GroupTextMessage,
        in conversation: ConversationEntity
    ) -> TextMessageEntity {
        textMessageEntity(
            messageID: abstractMessage.messageID,
            text: abstractMessage.text,
            quotedMessageID: abstractMessage.quotedMessageID,
            date: abstractMessage.date,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversation
        )
    }
    
    // MARK: File message
    
    func fileMessageEntity(
        from abstractMessage: AbstractMessage,
        in conversationEntity: ConversationEntity
    ) -> FileMessageEntity {
        assert(abstractMessage is BoxFileMessage || abstractMessage is GroupFileMessage)
        
        return fileMessageEntity(
            messageID: abstractMessage.messageID,
            date: abstractMessage.date,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversationEntity
        )
    }

    // MARK: Location message
    
    func locationMessageEntity(
        from abstractMessage: BoxLocationMessage,
        in conversation: ConversationEntity
    ) -> LocationMessageEntity {
        
        locationMessageEntity(
            messageID: abstractMessage.messageID,
            date: abstractMessage.date,
            accuracy: abstractMessage.accuracy,
            latitude: abstractMessage.latitude,
            longitude: abstractMessage.longitude,
            poiAddress: abstractMessage.poiAddress,
            poiName: abstractMessage.poiName,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversation
        )
    }
    
    // MARK: Location message
    
    func locationMessageEntity(
        from abstractMessage: GroupLocationMessage,
        in conversation: ConversationEntity
    ) -> LocationMessageEntity {
        
        locationMessageEntity(
            messageID: abstractMessage.messageID,
            date: abstractMessage.date,
            accuracy: abstractMessage.accuracy,
            latitude: abstractMessage.latitude,
            longitude: abstractMessage.longitude,
            poiAddress: abstractMessage.poiAddress,
            poiName: abstractMessage.poiName,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversation
        )
    }
    
    // MARK: Ballot message
    
    func ballotMessageEntity(
        from abstractMessage: AbstractMessage,
        in conversationEntity: ConversationEntity
    ) -> BallotMessageEntity {
        assert(abstractMessage is BoxBallotCreateMessage || abstractMessage is GroupBallotCreateMessage)
        
        return ballotMessageEntity(
            messageID: abstractMessage.messageID,
            date: abstractMessage.date,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversationEntity
        )
    }
    
    // MARK: - Legacy messages
    
    // MARK: Audio message
    
    func audioMessageEntity(
        from abstractMessage: BoxAudioMessage,
        in conversation: ConversationEntity
    ) -> AudioMessageEntity {
        audioMessageEntity(
            messageID: abstractMessage.messageID,
            audioBlobID: abstractMessage.audioBlobID,
            audioSize: Int(abstractMessage.audioSize),
            duration: Int(abstractMessage.duration),
            encryptionKey: abstractMessage.encryptionKey,
            date: abstractMessage.date,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversation
        )
    }
    
    func audioMessageEntity(
        from abstractMessage: GroupAudioMessage,
        in conversation: ConversationEntity
    ) -> AudioMessageEntity {
        audioMessageEntity(
            messageID: abstractMessage.messageID,
            audioBlobID: abstractMessage.audioBlobID,
            audioSize: Int(abstractMessage.audioSize),
            duration: Int(abstractMessage.duration),
            encryptionKey: abstractMessage.encryptionKey,
            date: abstractMessage.date,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversation
        )
    }
    
    // MARK: Image message
    
    func imageMessageEntity(
        from abstractMessage: BoxImageMessage,
        in conversation: ConversationEntity
    ) -> ImageMessageEntity {
        imageMessageEntity(
            messageID: abstractMessage.messageID,
            imageBlobID: abstractMessage.blobID,
            imageNonce: abstractMessage.imageNonce,
            imageSize: abstractMessage.size as NSNumber,
            date: abstractMessage.date,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversation
        )
    }
    
    func imageMessageEntity(
        from abstractMessage: GroupImageMessage,
        in conversation: ConversationEntity
    ) -> ImageMessageEntity {
        imageMessageEntity(
            messageID: abstractMessage.messageID,
            imageBlobID: abstractMessage.blobID,
            imageNonce: nil,
            imageSize: abstractMessage.size as NSNumber,
            date: abstractMessage.date,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversation
        )
    }
    
    // MARK: Video message
    
    func videoMessageEntity(
        from abstractMessage: BoxVideoMessage,
        in conversation: ConversationEntity
    ) -> VideoMessageEntity {
        videoMessageEntity(
            messageID: abstractMessage.messageID,
            duration: Int(abstractMessage.duration),
            encryptionKey: abstractMessage.encryptionKey,
            videoBlobID: abstractMessage.videoBlobID,
            videoSize: Int(abstractMessage.videoSize),
            date: abstractMessage.date,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversation
        )
    }
    
    func videoMessageEntity(
        from abstractMessage: GroupVideoMessage,
        in conversation: ConversationEntity
    ) -> VideoMessageEntity {
        videoMessageEntity(
            messageID: abstractMessage.messageID,
            duration: Int(abstractMessage.duration),
            encryptionKey: abstractMessage.encryptionKey,
            videoBlobID: abstractMessage.videoBlobID,
            videoSize: Int(abstractMessage.videoSize),
            date: abstractMessage.date,
            flags: abstractMessage.flags,
            forwardSecurityMode: Int(abstractMessage.forwardSecurityMode.rawValue),
            in: conversation
        )
    }
}
