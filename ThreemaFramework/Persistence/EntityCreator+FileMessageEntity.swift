import CocoaLumberjackSwift
import Foundation

enum EntityCreatorError: Error {
    case missingData
    case fileDataCreationFailed
    case entityCreationFailed
}

extension EntityCreator {

    public func createFileMessageEntity(
        data: Data?,
        mimeType: String?,
        caption: String?,
        fileName: String?,
        type: FileMessageEntity.FileMessageBaseType,
        duration: Double?,
        height: Int?,
        width: Int?,
        thumbnailData: Data?,
        thumbnailSize: CGSize?,
        encryptionKey: Data,
        origin: NSNumber,
        in conversation: ConversationEntity,
        correlationID: String? = nil,
        webRequestID: String? = nil
    ) throws -> FileMessageEntity {
        
        guard let data else {
            throw EntityCreatorError.missingData
        }
        
        // Create file data entity
        let fileData = fileDataEntity(data: data)
        
        // Assemble file message entity
        let entity = fileMessageEntity(in: conversation)
        entity.encryptionKey = encryptionKey
        entity.mimeType = mimeType
        entity.data = fileData
        entity.progress = nil
        entity.sendFailed = false
        entity.webRequestID = webRequestID
        entity.correlationID = correlationID
        entity.caption = caption
        entity.fileSize = NSNumber(integerLiteral: data.count)
        entity.fileName = fileName // We do not support web in the new file manager yet
        entity.origin = origin
        entity.type = NSNumber(integerLiteral: type.rawValue)
        entity.duration = duration
        entity.height = height
        entity.width = width

        // Thumbnail
        if let thumbnailData, let thumbnailSize {
            entity.thumbnail = imageDataEntity(
                data: thumbnailData,
                size: thumbnailSize
            )
        }
        
        return entity
    }
}
