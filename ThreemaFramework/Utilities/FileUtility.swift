//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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

@objc public class FileUtility: NSObject {
    
    @objc public static let appDataDirectory: URL? = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: AppGroup.groupID()
    )
    @objc public static let appDocumentsDirectory: URL? = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).last
    @objc public static let appCachesDirectory: URL? = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
    ).last
    @objc public static let appTemporaryDirectory: URL? = FileManager.default.temporaryDirectory
    
    /// Get size of dictionary, including subdirectries.
    ///
    /// - Parameters:
    ///    - pathURL: root url to get size
    ///    - size: total size of directory
    public static func pathSizeInBytes(pathURL: URL, size: inout Int64) {
        let fileManager = FileManager.default
        
        do {
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
            
            if let urls = fileManager.enumerator(at: pathURL, includingPropertiesForKeys: resourceKeys) {
                for case let url as URL in urls {
                    let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))

                    if let isDirectory = resourceValues.isDirectory,
                       !isDirectory {
                        
                        if let fileSize = fileSizeInBytes(fileURL: url) {
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
    
    /// Get size of file.
    ///
    /// - Parameters:
    ///    - fileURL: url of file
    ///
    /// - Returns: file size in bytes
    public static func fileSizeInBytes(fileURL: URL) -> Int64? {
        let fileManager = FileManager.default
        
        do {
            let fileAttr = try fileManager.attributesOfItem(atPath: fileURL.path)
            return fileAttr[FileAttributeKey.size] as? Int64
        }
        catch {
            DDLogError(error.localizedDescription)
        }
        
        return nil
    }
    
    /// Get size of file for Objective C.
    /// - Parameters:
    ///    - fileURL: url of file
    /// - Returns: file size in bytes or 0
    @objc public static func fileSizeInBytesObjc(fileURL: URL) -> Int64 {
        if let fileSize = fileSizeInBytes(fileURL: fileURL) {
            return fileSize
        }
        return 0
    }
    
    @objc public static func getFileSizeDescription(for fileURL: URL) -> String? {
        guard let fileSize = fileSizeInBytes(fileURL: fileURL) else {
            return nil
        }
        return getFileSizeDescription(from: fileSize)
    }
    
    @objc public static func getFileSizeDescription(from fileSize: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .binary)
    }
    
    @objc public static func getTemporaryFileName() -> String {
        var filename = ProcessInfo().globallyUniqueString
        let url = FileManager.default.temporaryDirectory
        var fileURL = url.appendingPathComponent(filename)

        while FileUtility.isExists(fileURL: fileURL) {
            filename = ProcessInfo().globallyUniqueString
            fileURL = url.appendingPathComponent(filename)
        }
        return filename
    }
    
    @objc public static func getTemporarySendableFileName(
        base: String,
        directoryURL: URL,
        pathExtension: String? = nil
    ) -> String {
        let filename = base + "-" + DateFormatter.getDateForWeb(Date())
        
        return FileUtility.getUniqueFilename(from: filename, directoryURL: directoryURL, pathExtension: pathExtension)
    }
    
    @objc public static func getUniqueFilename(
        from filename: String,
        directoryURL: URL,
        pathExtension: String? = nil
    ) -> String {
        var newFilename = filename
        
        var fileURL = directoryURL.appendingPathComponent(filename)
        if let pathExtension = pathExtension {
            fileURL = fileURL.appendingPathExtension(pathExtension)
        }
        
        var i = 0
        while FileUtility.isExists(fileURL: fileURL) {
            newFilename = filename.appending("-\(i)")
            fileURL = directoryURL.appendingPathComponent(newFilename)
            if let pathExtension = pathExtension {
                fileURL = fileURL.appendingPathExtension(pathExtension)
            }
            i += 1
        }
        
        return newFilename
    }
    
    @objc public static func getTemporarySendableFileName(base: String) -> String {
        let url = FileManager.default.temporaryDirectory
        return getTemporarySendableFileName(base: base, directoryURL: url)
    }
    
    @objc public static func isExists(fileURL: URL?) -> Bool {
        guard let fileURL = fileURL else {
            return false
        }
        
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    @objc public static func dir(pathURL: URL?) -> [String]? {
        guard let pathURL = pathURL else {
            return nil
        }
    
        var items: [String]?
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: pathURL.path) {
            items = try? fileManager.contentsOfDirectory(atPath: pathURL.path)
        }
        return items
    }
    
    /// Delete file or directory if exists.
    ///
    /// - Parameters:
    ///    - at: URL to file or directory
    @objc public static func delete(at: URL?) {
        guard let atURL = at else {
            return
        }
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: atURL.path) {
            try? fileManager.removeItem(atPath: atURL.path)
        }
    }

    /// Create directory, but no intermediate directories.
    ///
    /// - Parameters:
    ///   - at: URL of directory
    ///
    /// - Returns: True was successfully created
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
    
    @objc public static func move(source: URL, destination: URL) -> Bool {
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

    public static func write(fileURL: URL?, text: String) -> Bool {
        guard let fileURL = fileURL else {
            return false
        }
        
        return FileUtility.write(fileURL: fileURL, contents: text.data(using: .utf8))
    }
    
    @discardableResult public static func write(fileURL: URL?, contents: Data?) -> Bool {
        guard let fileURL = fileURL else {
            return false
        }
        
        let fileManager = FileManager.default
        return fileManager.createFile(atPath: fileURL.path, contents: contents, attributes: nil)
    }
    
    public static func read(fileURL: URL?) -> Data? {
        guard let fileURL = fileURL else {
            return nil
        }
        
        var content: Data?
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            content = fileHandle.readDataToEndOfFile()
            fileHandle.closeFile()
        }
        catch {
            DDLogError(error.localizedDescription)
        }
        
        return content
    }
    
    /// Append text to the end of file.
    ///
    /// - Parameters:
    ///    - filePath: path to appending file
    ///    - text: content to addend
    public static func append(fileURL: URL?, text: String) -> Bool {
        guard let fileURL = fileURL else {
            return false
        }
        
        var result = false

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            if let data = text.data(using: .utf8) {
                do {
                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
                catch {
                    DDLogError(error.localizedDescription)
                }
            }
            result = true
        }
        else {
            result = FileUtility.write(fileURL: fileURL, text: text)
        }
        
        return result
    }

    /// Log list directories and files and write log file to application documents folder.
    ///
    /// - Parameters:
    ///    - path: Root directory to list objects
    ///    - logFileName: Name of log file stored in application documents folder
    @objc public static func logDirectoriesAndFiles(path: URL, logFileName: String?) {
        let fileManager = FileManager.default
        
        do {
            DDLogInfo("Log files form \(path.path) into \(logFileName ?? "validation_log.txt")")
            
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey, .fileSizeKey]
            
            var logFiles = ""
            
            if let urls = fileManager.enumerator(at: path, includingPropertiesForKeys: resourceKeys) {
                for case let url as URL in urls {
                    let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                    let logFile =
                        "\(url.path) \(ByteCountFormatter.string(fromByteCount: Int64(resourceValues.fileSize ?? 0), countStyle: ByteCountFormatter.CountStyle.file)) \(resourceValues.creationDate!) \(resourceValues.isDirectory!)"
                    DDLogVerbose(logFile)
                    logFiles += "\(logFile)\n"
                }
            }
            
            if let logFileName = logFileName,
               let appDocuments = appDocumentsDirectory {
                let documentsPath = URL(fileURLWithPath: appDocuments.path)
                let filePath = documentsPath.appendingPathComponent(logFileName)
                
                do {
                    if fileManager.fileExists(atPath: filePath.path) {
                        try fileManager.removeItem(at: filePath)
                    }
                    
                    if !logFiles.isEmpty {
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
    
    @objc public static func cleanTemporaryDirectory(olderThan: Date?) {
        guard let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date()) else {
            DDLogError("Could not get date for five days ago")
            return
        }
        let directoryURL = FileManager.default.temporaryDirectory
        do {
            let oldTempFiles = try
                FileManager.default.contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                )
                .filter {
                    try $0.promisedItemResourceValues(forKeys: [.contentModificationDateKey])
                        .contentModificationDate! < olderThan ?? fiveDaysAgo
                }
            
            for item in oldTempFiles {
                DDLogInfo("Removing file: \(item)")
                try FileManager.default.removeItem(at: item)
            }
        }
        catch {
            DDLogError("An error occured while cleaning the temporary directory \(error)")
        }
    }
    
    /// Remove all items in a directory
    /// - Parameter directoryURL: URL of the directory
    @objc public static func removeItemsInDirectory(directoryURL: URL) {
        if let items = FileUtility.dir(pathURL: directoryURL) {
            for item in items {
                let itemURL = URL(fileURLWithPath: String(format: "%@/%@", directoryURL.path, item))
                FileUtility.delete(at: itemURL)
            }
        }
    }
}
