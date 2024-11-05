//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import CoreData
import Foundation

@objc(FileMessageEntity)
public final class FileMessageEntity: BaseMessage {
    
    // Attributes
    // swiftformat:disable: acronyms
    @NSManaged @objc(blobId) public var blobId: Data?
    @NSManaged @objc(blobThumbnailId) public var blobThumbnailId: Data?
    // swiftformat:enable: acronyms
    @NSManaged @objc(caption) public var caption: String?
    @NSManaged @objc(consumed) public var consumed: Date?
    @NSManaged @objc(encryptionKey) public var encryptionKey: Data?
    @NSManaged @objc(fileName) public var fileName: String?
    @NSManaged @objc(fileSize) public var fileSize: NSNumber?
    @NSManaged @objc(json) public var json: String?
    @NSManaged @objc(mimeType) public var mimeType: String?
    @NSManaged @objc(origin) public var origin: NSNumber?
    @NSManaged @objc(progress) public var progress: NSNumber?
    @NSManaged @objc(type) public var type: NSNumber?

    // Relationships
    @NSManaged public var thumbnail: ImageDataEntity?
    @NSManaged public var data: FileDataEntity?
    
    enum FileMessageJSONKeys: String {
        case correlationID = "c"
        case mimeTypeThumbnail = "p"
        case metaData = "x"
        case height = "h"
        case width = "w"
        case durationJSONCaption = "d"
    }

    // Lifecycle
    
    // TODO: (IOS-4752) Use in EntityCreator/DB Preparer
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - blobId: Blob id of the file data
    ///   - blobThumbnailId: Blob id of the thumbnail data
    ///   - caption: Caption describing the data
    ///   - consumed: Has the file been consumed?
    ///   - encryptionKey: Key the file data is encrypted with
    ///   - fileName: Name of the file
    ///   - fileSize: Size of the file
    ///   - json: JSON where additional info is stored in
    ///   - mimeType: MIME type of the data
    ///   - origin: Origin of the blob
    ///   - progress: Download progress of the data
    ///   - type: Type of the file
    ///   - thumbnail: Thumbnail of the data
    ///   - data: Data of the file
    public init(
        context: NSManagedObjectContext,
        blobID: Data? = nil,
        blobThumbnailID: Data? = nil,
        caption: String? = nil,
        consumed: Date? = nil,
        encryptionKey: Data? = nil,
        fileName: String? = nil,
        fileSize: NSNumber? = nil,
        json: String? = nil,
        mimeType: String? = nil,
        origin: NSNumber? = nil,
        progress: NSNumber? = nil,
        type: NSNumber? = nil,
        thumbnail: ImageDataEntity? = nil,
        data: FileDataEntity? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "FileMessage", in: context)!
        super.init(entity: entity, insertInto: context)
        
        // swiftformat:disable: acronyms
        self.blobId = blobID
        self.blobThumbnailId = blobThumbnailID
        // swiftformat:enable: acronyms
        self.caption = caption
        self.consumed = consumed
        self.encryptionKey = encryptionKey
        self.fileName = fileName
        self.fileSize = fileSize
        self.json = json
        self.mimeType = mimeType
        self.origin = origin
        self.progress = progress
        self.type = type
        
        self.thumbnail = thumbnail
        self.data = data
    }
    
    @objc override private init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    @available(*, unavailable)
    public init() {
        fatalError("\(#function) not implemented")
    }
    
    @available(*, unavailable)
    public convenience init(context: NSManagedObjectContext) {
        fatalError("\(#function) not implemented")
    }
    
    // Properties
    
    @objc public lazy var correlationID: String? = {
        guard let json else {
            return nil
        }
        
        let jsonData = Data(json.utf8)
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        
        return jsonObject[FileMessageJSONKeys.correlationID.rawValue] as? String
    }()
    
    @objc public lazy var mimeTypeThumbnail: String? = {
        guard let json else {
            return nil
        }
        
        let jsonData = Data(json.utf8)
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        
        return jsonObject[FileMessageJSONKeys.mimeTypeThumbnail.rawValue] as? String
    }()
    
    public lazy var height: Int? = {
        guard let json else {
            return nil
        }
        
        let jsonData = Data(json.utf8)
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        
        guard let meta = jsonObject[FileMessageJSONKeys.metaData.rawValue] as? [String: Any] else {
            return nil
        }
        
        return meta[FileMessageJSONKeys.height.rawValue] as? Int
    }()
    
    @objc public lazy var heightObjc: NSNumber? = height as? NSNumber
    
    public lazy var width: Int? = {
        guard let json else {
            return nil
        }
        
        let jsonData = Data(json.utf8)
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        
        guard let meta = jsonObject[FileMessageJSONKeys.metaData.rawValue] as? [String: Any] else {
            return nil
        }
        
        return meta[FileMessageJSONKeys.width.rawValue] as? Int
    }()
    
    @objc public lazy var widthObjc: NSNumber? = width as? NSNumber
    
    public lazy var duration: Double? = {
        guard let json else {
            return nil
        }
        
        let jsonData = Data(json.utf8)
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        
        guard let meta = jsonObject[FileMessageJSONKeys.metaData.rawValue] as? [String: Any] else {
            return nil
        }
        
        return meta[FileMessageJSONKeys.durationJSONCaption.rawValue] as? Double
    }()
    
    public lazy var jsonCaption: String? = {
        guard let json else {
            return nil
        }
        
        let jsonData = Data(json.utf8)
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        
        return jsonObject[FileMessageJSONKeys.durationJSONCaption.rawValue] as? String
    }()
    
    @objc public lazy var durationObjc: NSNumber? = duration as? NSNumber
    
    @objc public lazy var sendAsFileImageMessage = {
        guard let mimeType else {
            return false
        }
        
        return UTIConverter.isImageMimeType(mimeType) && UTIConverter.isRenderingImageMimeType(mimeType)
    }()

    @objc public lazy var sendAsFileVideoMessage = {
        guard let mimeType else {
            return false
        }
        
        return UTIConverter.isMovieMimeType(mimeType) && UTIConverter.isRenderingVideoMimeType(mimeType)
    }()
    
    @objc public lazy var sendAsFileAudioMessage = {
        guard let type else {
            return false
        }
        
        return type.intValue != 0
    }()
    
    @objc public lazy var sendAsFileGifMessage = {
        guard let mimeType else {
            return false
        }
        
        return UTIConverter.isGifMimeType(mimeType)
    }()

    @objc public lazy var renderFileImageMessage = {
        guard let type, let mimeType else {
            return false
        }
        
        return (type.intValue == 1 || type.intValue == 2) && UTIConverter.isImageMimeType(mimeType) && UTIConverter
            .isRenderingImageMimeType(mimeType)
    }()
    
    @objc public lazy var renderFileVideoMessage = {
        guard let type, let mimeType else {
            return false
        }
        
        return (type.intValue == 1 || type.intValue == 2) && UTIConverter.isRenderingVideoMimeType(mimeType)
    }()
    
    @objc public lazy var renderFileAudioMessage = {
        guard let type, let mimeType else {
            return false
        }
        
        return (type.intValue == 1 || type.intValue == 2) && UTIConverter.isRenderingAudioMimeType(mimeType)
    }()
    
    @objc public lazy var renderMediaFileMessage = {
        guard let type else {
            return false
        }
        
        return type.intValue == 1
    }()
    
    @objc public lazy var renderStickerFileMessage = {
        guard let type else {
            return false
        }
        
        return type.intValue == 2
    }()
}
