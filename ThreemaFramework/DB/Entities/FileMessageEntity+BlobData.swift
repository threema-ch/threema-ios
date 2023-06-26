//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

extension FileMessageEntity: BlobData {
    
    public var blobIdentifier: Data? {
        get {
            blobID
        }
        set {
            blobID = newValue
        }
    }
    
    public var blobThumbnailIdentifier: Data? {
        get {
            blobThumbnailID
        }
        set {
            blobThumbnailID = newValue
        }
    }
    
    public var blobData: Data? {
        get {
            data?.data
        }
        set {
            guard newValue != nil else {
                if let data {
                    managedObjectContext?.delete(data)
                    self.data = nil
                }
                
                return
            }
            
            let fileData: FileData
            
            // We only create a new data if we do not have one already
            if let data {
                fileData = data
            }
            else if let managedObjectContext,
                    let newData = NSEntityDescription.insertNewObject(
                        forEntityName: "FileData",
                        into: managedObjectContext
                    ) as? FileData {
                fileData = newData
            }
            else {
                DDLogError("Unable to load managed object context or create new file data entity")
                return
            }
            
            fileData.data = newValue
            data = fileData
        }
    }
    
    public var blobThumbnail: Data? {
        get {
            thumbnail?.data
        }
        set {
            guard let newValue else {
                if let thumbnail {
                    managedObjectContext?.delete(thumbnail)
                    self.thumbnail = nil
                }
                
                return
            }
            
            let thumbnailData: ImageData
            
            // We only create a new data if we do not have one already
            if let thumbnail {
                thumbnailData = thumbnail
            }
            else if let managedObjectContext,
                    let newData = NSEntityDescription.insertNewObject(
                        forEntityName: "ImageData",
                        into: managedObjectContext
                    ) as? ImageData {
                thumbnailData = newData
            }
            else {
                DDLogError("Unable to load managed object context or create new image data entity for thumbnail")
                return
            }
            
            // Load thumbnail image to get dimensions
            if let temporaryImage = UIImage(data: newValue) {
                thumbnailData.width = NSNumber(floatLiteral: temporaryImage.size.width)
                thumbnailData.height = NSNumber(floatLiteral: temporaryImage.size.height)
            }
            
            thumbnailData.data = newValue
            thumbnail = thumbnailData
        }
    }
    
    public var blobIsOutgoing: Bool {
        isOwnMessage
    }
    
    public var blobEncryptionKey: Data? {
        encryptionKey
    }
    
    public var blobUTTypeIdentifier: String? {
        UTIConverter.uti(fromMimeType: mimeType)
    }
    
    public var blobSize: Int {
        Int(truncating: fileSize ?? 0)
    }
    
    public var blobOrigin: BlobOrigin {
        get {
            guard let value = origin as? Int else {
                return .public
            }
            return BlobOrigin(rawValue: value) ?? .public
        }
        set {
            origin = NSNumber(integerLiteral: newValue.rawValue)
        }
    }
    
    public var blobProgress: NSNumber? {
        get {
            progress
        }
        set {
            progress = newValue
        }
    }
    
    public var blobError: Bool {
        get {
            sendFailed?.boolValue ?? false
        }
        set {
            sendFailed = NSNumber(booleanLiteral: newValue)
        }
    }
    
    public var blobFilename: String? {
        "\(id.hexString)-\(fileName ?? "")"
    }
    
    public var blobWebFilename: String {
        fileName ?? "unknown-file-name"
    }
    
    public var blobExternalFilename: String? {
        data?.getFilename()
    }
    
    public var blobThumbnailExternalFilename: String? {
        thumbnail?.getFilename()
    }
}
