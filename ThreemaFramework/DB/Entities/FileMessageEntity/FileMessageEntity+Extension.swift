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
import Foundation
import ThreemaMacros

extension FileMessageEntity {
    
    override public func contentToCheckForMentions() -> String? {
        caption
    }
    
    @objc func exportData(to url: URL) {
        guard let blobData else {
            DDLogError("No data to write to temporary file found.")
            return
        }
        
        do {
            try blobData.write(to: url)
        }
        catch {
            DDLogError("Writing file data to temporary file failed.")
        }
    }
    
    override public func additionalExportInfo() -> String? {
        
        var info = "\(#localize("file")): \(logFileName())"
        
        if let caption {
            let cap = " \(#localize("caption")) \(caption)"
            info += cap
        }
        
        return info
    }
    
    #if !DEBUG
        override public var debugDescription: String {
            "<\(Swift.type(of: self))>:\(FileMessageEntity.self), encryptionKey = ***, blobId = ***, blobThumbnailID = ****, fileName = \(fileName?.description ?? "nil"), progress = \(progress?.description ?? "nil"), type = \(type?.description ?? "nil"), mimeType = \(mimeType?.description ?? "nil"), data = \(data?.description ?? "nil"), thumbnail = \(thumbnail?.description ?? "nil"), json = ****,"
        }
    #endif
    
    private func logFileName() -> String {
        let name = blobFilename
        if var name, blobData == nil {
            name += " \(#localize("fileNotDownloaded"))"
        }
        
        return name ?? ""
    }
 
    @objc func tempFileURL(fallBackFileName: String) -> URL? {
        var tempFileURL: URL?
        let tempDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
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
}
