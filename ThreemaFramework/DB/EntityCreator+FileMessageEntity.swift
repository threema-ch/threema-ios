//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

enum EntityCreatorError: Error {
    case missingData
    case fileDataCreationFailed
    case entityCreationFailed
}

extension EntityCreator {
    
    public func createFileMessageEntity(
        for item: URLSenderItem,
        in conversation: Conversation,
        with origin: BlobOrigin,
        correlationID: String? = nil,
        webRequestID: String? = nil
    ) throws -> FileMessageEntity {
        
        guard let data = item.getData() else {
            throw EntityCreatorError.missingData
        }
        
        // Create file data
        guard let fileData = fileData() else {
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
        entity.webRequestID = webRequestID
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
            entity.duration = item.getDuration() as NSNumber
        }
        
        if entity.renderType == .imageMessage || entity.renderType == .videoMessage {
            entity.height = item.getHeight() as NSNumber
            entity.width = item.getWidth() as NSNumber
        }
        
        // Thumbnail
        if let thumbnailImage = item.getThumbnail() {
            
            let thumbnailData: Data!
            
            if UTIConverter.isPNGImageMimeType(entity.mimeType) {
                thumbnailData = thumbnailImage.pngData()
                entity.mimeTypeThumbnail = entity.mimeType
            }
            else {
                thumbnailData = MediaConverter.jpegRepresentation(for: thumbnailImage)
            }
            
            if let thumbnail = imageData() {
                thumbnail.data = thumbnailData
                thumbnail.height = thumbnailImage.size.height as NSNumber
                thumbnail.width = thumbnailImage.size.width as NSNumber
                entity.thumbnail = thumbnail
            }
        }
        
        // Create JSON
        entity.json = FileMessageEncoder.jsonString(for: entity)
        
        return entity
    }
}
