//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaMacros

extension FileMessageEntity {

    @objc public func exportData(to url: URL) {
        guard let blobData else {
            DDLogError("No data to write to temporary file found.")
            return
        }
        
        guard FileUtility.shared.write(contents: blobData, to: url) else {
            DDLogError("Writing file data to temporary file failed.")
            return
        }
    }
    
    @objc public func tempFileURL(fallBackFileName: String) -> URL {
        var tempFileURL: URL?
        let tempDirURL = URL(
            fileURLWithPath: FileUtility.shared.appTemporaryUnencryptedDirectory.path,
            isDirectory: true
        )
        var tempFileName: NSString?
        
        if let fileName {
            let cleanedFileName = fileName.replacingOccurrences(of: "/", with: "")
            tempFileName = cleanedFileName as NSString
            tempFileURL = tempDirURL.appendingPathComponent(cleanedFileName)
        }
        else if let dataFileName = data?.getFilename() {
            tempFileName = dataFileName as NSString
        }
        
        if var tempFileName {
            var fileExtension = UTIConverter.preferredFileExtension(forMimeType: mimeType)

            // Workaround for audio messages from Android
            if mimeType == "audio/aac" {
                fileExtension = "m4a"
            }
            
            // The mime type might not return an extension. If it does not, we check the path extension. If there is
            // none,
            // we use an empty extension.
            if fileExtension == nil {
                fileExtension = tempFileName.pathExtension
            }

            // Check if the filename already contains the suffix to avoid appending it twice
            if tempFileName.hasSuffix(".\(fileExtension!)") {
                tempFileName = tempFileName.replacingOccurrences(of: ".\(fileExtension!)", with: "") as NSString
            }

            // Get unique filename in temporary directory, to allow sharing multiple files with the same name
            let uniqueFileName = FileUtility.shared.getUniqueFilename(
                from: tempFileName as String,
                directoryURL: tempDirURL,
                pathExtension: fileExtension
            )
            tempFileName = uniqueFileName as NSString

            tempFileURL = tempDirURL.appendingPathComponent(tempFileName as String)
                .appendingPathExtension(fileExtension!)
        }
        
        if let tempFileURL {
            return tempFileURL
        }
        else {
            let fileExtension = UTIConverter.preferredFileExtension(forMimeType: mimeType) ?? ""
            return tempDirURL.appendingPathComponent(fallBackFileName).appendingPathExtension(fileExtension)
        }
    }
    
    @objc public var sendAsFileImageMessage: Bool {
        guard let mimeType else {
            return false
        }
        
        return UTIConverter.isImageMimeType(mimeType) && UTIConverter.isRenderingImageMimeType(mimeType)
    }

    @objc public var sendAsFileVideoMessage: Bool {
        guard let mimeType else {
            return false
        }
        
        return UTIConverter.isMovieMimeType(mimeType) && UTIConverter.isRenderingVideoMimeType(mimeType)
    }
    
    @objc public var sendAsFileAudioMessage: Bool {
        guard let type else {
            return false
        }
        
        return type.intValue != 0
    }
    
    @objc public var sendAsFileGifMessage: Bool {
        guard let mimeType else {
            return false
        }
        
        return UTIConverter.isGifMimeType(mimeType)
    }

    @objc public var renderFileImageMessage: Bool {
        guard let type, let mimeType else {
            return false
        }
        
        return (type.intValue == 1 || type.intValue == 2) && UTIConverter.isImageMimeType(mimeType) && UTIConverter
            .isRenderingImageMimeType(mimeType)
    }
    
    @objc public var renderFileVideoMessage: Bool {
        guard let type, let mimeType else {
            return false
        }
        
        return (type.intValue == 1 || type.intValue == 2) && UTIConverter.isRenderingVideoMimeType(mimeType)
    }
    
    public var renderFileAudioMessage: Bool {
        guard let type, let mimeType else {
            return false
        }
        
        return (type.intValue == 1 || type.intValue == 2) && UTIConverter.isRenderingAudioMimeType(mimeType)
    }
    
    @objc public var renderMediaFileMessage: Bool {
        guard let type else {
            return false
        }
        
        return type.intValue == 1
    }

    @objc public var renderStickerFileMessage: Bool {
        guard let type else {
            return false
        }
        
        return type.intValue == 2
    }
}
