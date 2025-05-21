//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

enum EntityCreatorError: Error {
    case missingData
    case fileDataCreationFailed
    case entityCreationFailed
}

extension EntityCreator {
    
    public func createFileMessageEntity(
        for item: URLSenderItem,
        in conversation: ConversationEntity,
        with origin: BlobOrigin,
        correlationID: String? = nil,
        webRequestID: String? = nil
    ) throws -> FileMessageEntity {
        
        guard let data = item.getData() else {
            throw EntityCreatorError.missingData
        }
        
        // Create file data entity
        guard let fileData = fileDataEntity() else {
            throw EntityCreatorError.fileDataCreationFailed
        }
        
        fileData.data = data
        
        // Assemble file message entity
        let entity = fileMessageEntity(for: conversation)
        
        guard let entity else {
            throw EntityCreatorError.entityCreationFailed
        }
        
        entity.encryptionKey = NaClCrypto.shared().randomBytes(kBlobKeyLen)
        entity.mimeType = item.getMimeType()
        entity.data = fileData
        entity.progress = nil
        entity.sendFailed = false
        // swiftformat:disable:next acronyms
        entity.webRequestId = webRequestID
        entity.correlationID = correlationID
        entity.caption = item.caption
        entity.fileSize = NSNumber(integerLiteral: data.count)
        entity.fileName = item.getName() // We do not support web in the new file manager yet
        entity.blobOrigin = origin
        
        if let renderType = item.renderType {
            entity.type = renderType
        }
        else {
            entity.type = 0
        }
        
        if entity.renderType == .voiceMessage || entity.renderType == .videoMessage {
            entity.duration = item.getDuration()
        }
        
        if entity.renderType == .imageMessage || entity.renderType == .videoMessage {
            entity.height = Int(item.getHeight())
            entity.width = Int(item.getWidth())
        }
        
        // Thumbnail
        if let thumbnailImage = item.getThumbnail() {
            
            let thumbnailData: Data?
            
            if UTIConverter.isPNGImageMimeType(entity.mimeType) {
                thumbnailData = thumbnailImage.pngData()
                entity.mimeTypeThumbnail = entity.mimeType
            }
            else {
                thumbnailData = MediaConverter.jpegRepresentation(for: thumbnailImage)
            }
            
            if let thumbnailData, let thumbnail = imageDataEntity() {
                thumbnail.data = thumbnailData
                thumbnail.height = Int16(thumbnailImage.size.height)
                thumbnail.width = Int16(thumbnailImage.size.width)
                entity.thumbnail = thumbnail
            }
            else {
                DDLogError("Unable to create thumbnail data for item")
            }
        }
        
        // Create JSON
        entity.json = FileMessageEncoder.jsonString(for: entity)
        
        return entity
    }
}
