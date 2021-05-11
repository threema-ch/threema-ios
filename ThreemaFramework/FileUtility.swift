//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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
import CocoaLumberjackSwift

@objc public class FileUtility: NSObject {
    
    @objc public static let appDataDirectory: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.groupId())
    @objc public static let appDocumentsDirectory: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
    
    /**
     Get total size and total free size of the device.
     
     - Returns:
        - totalSize: total size in bytes of device
        - totalFreeSize: total free size in bytes on device
    */
    public static func deviceSizeInBytes() -> (totalSize: Int64?, totalFreeSize: Int64?) {
        var size: Int64?
        var freeSize: Int64?
        
        if #available(iOS 11.0, *) {
            let homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())
            if let systemResources = try? homeDirectory.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
                size = systemResources.allValues[.volumeTotalCapacityKey] as? Int64
                freeSize = systemResources.allValues[.volumeAvailableCapacityForImportantUsageKey] as? Int64
            }
        }
        else {
            if let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last,
                let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: documentDirectory) {
                
                size = systemAttributes[FileAttributeKey.systemSize] as? Int64
                freeSize = systemAttributes[.systemFreeSize] as? Int64
            }
        }

        return (size, freeSize)
    }

    /**
     Get size of dictionary, including subdirectries.
     
     - Parameters:
        - pathUrl: root url to get size
        - size: total size of directory
    */
    public static func pathSizeInBytes(pathUrl: URL, size: inout Int64) {
        let fileManager = FileManager.default
        
        do {
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
            
            if let urls = fileManager.enumerator(at: pathUrl, includingPropertiesForKeys: resourceKeys) {
                for case let url as URL in urls {
                    let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                    DDLogVerbose("\(url.path) \(resourceValues.creationDate!) \(resourceValues.isDirectory!)")
                    
                    if let isDirectory = resourceValues.isDirectory,
                        !isDirectory {
                        
                        if let fileSize = fileSizeInBytes(fileUrl: url) {
                            size = size + fileSize
                        }
                    }
                }
            }
        }
        catch {
            DDLogError(error.localizedDescription)
        }
    }
    
    /**
     Get size of file.
 
     - Parameters:
        - fileUrl: url of file
     
     - Returns: file size in bytes
    */
    public static func fileSizeInBytes(fileUrl: URL) -> Int64? {
        let fileManager = FileManager.default
        
        do {
            let fileAttr = try fileManager.attributesOfItem(atPath: fileUrl.path)
            return fileAttr[FileAttributeKey.size] as? Int64
        }
        catch {
            DDLogError(error.localizedDescription)
        }
        
        return nil
    }
    
    @objc public static func getTemporaryFileName() -> String {
        var filename = ProcessInfo().globallyUniqueString
        let url = FileManager.default.temporaryDirectory
        var fileURL = url.appendingPathComponent(filename)

        while FileUtility.isExists(fileUrl: fileURL) {
            filename = ProcessInfo().globallyUniqueString
            fileURL = url.appendingPathComponent(filename)
        }
        return filename
    }
    
    @objc public static func getTemporarySendableFileName(base : String, directoryURL : URL, pathExtension : String? = nil) -> String {
        let filename = base + "-" + DateFormatter.getDateForWeb(Date())
        
        return FileUtility.getUniqueFilename(from: filename, directoryURL: directoryURL, pathExtension: pathExtension)
    }
    
    @objc public static func getUniqueFilename(from filename : String, directoryURL : URL, pathExtension : String? = nil) -> String {
        var newFilename = filename
        
        var fileURL = directoryURL.appendingPathComponent(filename)
        if let pathExtension = pathExtension {
            fileURL = fileURL.appendingPathExtension(pathExtension)
        }
        
        var i = 0
        while FileUtility.isExists(fileUrl: fileURL) {
            newFilename = filename.appending("-\(i)")
            fileURL = directoryURL.appendingPathComponent(newFilename)
            if let pathExtension = pathExtension {
                fileURL = fileURL.appendingPathExtension(pathExtension)
            }
            i += 1
        }
        
        return newFilename
    }
    
    @objc public static func getTemporarySendableFileName(base : String) -> String {
        let url = FileManager.default.temporaryDirectory
        return getTemporarySendableFileName(base: base, directoryURL: url)
    }
    
    public static func isExists(fileUrl: URL?) -> Bool {
        guard let fileUrl = fileUrl else {
            return false;
        }
        
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: fileUrl.path)
    }
    
    @objc public static func dir(pathUrl: URL?) -> [String]? {
        guard let pathUrl = pathUrl else {
            return nil;
        }
    
        var items: [String]?
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: pathUrl.path) {
            items = try? fileManager.contentsOfDirectory(atPath: pathUrl.path)
        }
        return items
    }
    
    /**
     Delete file or directory if exists.
     
     - Parameters:
        - at: URL to file or directory
    */
    @objc public static func delete(at: URL?) {
        guard let atUrl = at else {
            return;
        }
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: atUrl.path) {
            try? fileManager.removeItem(atPath: atUrl.path)
        }
    }

    /**
     Create directory, but no intermediate directories.
     
     - Parameters:
        - at: URL of directory
     
     - Returns: True was successfully created
     */
    public static func mkDir(at: URL) -> Bool {
        let fileManager = FileManager.default
        
        do {
            try fileManager.createDirectory(at: at, withIntermediateDirectories: false, attributes: nil)
            
            return true
        }
        catch {
            DDLogError(error.localizedDescription)
        }
        
        return false
    }
    
    public static func move(source: URL, destination: URL) -> Bool {
        let fileManager = FileManager.default
        
        do {
            try fileManager.moveItem(at: source, to: destination)
            
            return true
        }
        catch {
            DDLogError(error.localizedDescription)
        }
        
        return false
    }

    public static func write(fileUrl: URL?, text: String) -> Bool {
        guard let fileUrl = fileUrl else {
            return false
        }
        
        return FileUtility.write(fileUrl: fileUrl, contents: text.data(using: .utf8))
    }
    
    public static func write(fileUrl: URL?, contents: Data? ) -> Bool {
        guard let fileUrl = fileUrl else {
            return false;
        }
        
        let fileManager = FileManager.default
        return fileManager.createFile(atPath: fileUrl.path, contents: contents, attributes: nil)
    }
    
    /**
     Append text to the end of file.
     
     - Parameters:
        - filePath: path to appending file
        - text: content to addend
    */
    public static func append(fileUrl:URL?, text: String) -> Bool {
        guard let fileUrl = fileUrl else {
            return false;
        }
        
        var result: Bool = false

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileUrl.path) {
            if let data = text.data(using: .utf8) {
                do {
                    let fileHandle = try FileHandle(forWritingTo: fileUrl)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
                catch {
                    DDLogError(error.localizedDescription)
                }
            }
            result = true;
        }
        else {
            result = FileUtility.write(fileUrl: fileUrl, text: text)
        }
        
        return result
    }

    /**
     Log list directories and files and write log file to application documents folder.
     
     - Parameters:
        - path: Root directory to list objects
        - logFileName: Name of log file stored in application documents folder
    */
    @objc public static func logDirectoriesAndFiles(path: URL, logFileName: String) {
        let fileManager = FileManager.default
        
        do {
            DDLogInfo("Log files form \(path.path) into \(logFileName)")
            
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey, .fileSizeKey]
            
            var logFiles: String = ""
            
            if let urls = fileManager.enumerator(at: path, includingPropertiesForKeys: resourceKeys) {
                for case let url as URL in urls {
                    let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                    let logFile: String = "\(url.path) \(ByteCountFormatter.string(fromByteCount: Int64(resourceValues.fileSize ?? 0), countStyle: ByteCountFormatter.CountStyle.file)) \(resourceValues.creationDate!) \(resourceValues.isDirectory!)"
                    DDLogVerbose(logFile)
                    logFiles += "\(logFile)\n"
                }
            }

            if let appDocuments = appDocumentsDirectory {
                let documentsPath = URL(fileURLWithPath: appDocuments.path)
                let filePath = documentsPath.appendingPathComponent(logFileName)
                
                do {
                    if fileManager.fileExists(atPath: filePath.path) {
                        try fileManager.removeItem(at: filePath)
                    }
                    
                    if logFiles.count > 0 {
                        try logFiles.write(to: filePath, atomically: false, encoding: .utf8)
                    }
                }
                catch {
                    DDLogError(error.localizedDescription)
                }
            }
        }
        catch {
            DDLogError(error.localizedDescription)
        }
    }
    
    @objc public static func cleanTemporaryDirectory(olderThan : Date?) {
        guard let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date()) else {
            DDLogError("Could not get date for five days ago")
            return
        }
        let directoryURL = FileManager.default.temporaryDirectory
        do {
            let oldTempFiles = try
                FileManager.default.contentsOfDirectory(at: directoryURL,
                                                        includingPropertiesForKeys:[.contentModificationDateKey],
                                                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                .filter { try $0.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate! <  olderThan ?? fiveDaysAgo}
            
            for item in oldTempFiles {
                DDLogInfo("Removing file: \(item)")
                try FileManager.default.removeItem(at: item)
            }
        } catch {
            DDLogError("An error occured while cleaning the temporary directory \(error)")
        }
    }
}
