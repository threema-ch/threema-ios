//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

@objc public final class FileUtility: NSObject, FileUtilityProtocol {
    
    @objc public let appDataDirectory: URL? = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: AppGroup.groupID()
    )
    
    @objc public let appDocumentsDirectory: URL? = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).last
    
    @objc public let appCachesDirectory: URL? = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
    ).last
    
    /// Temporary app directory
    ///
    /// Please remove data stored here that is no longer needed: https://stackoverflow.com/a/25067497
    @objc public let appTemporaryDirectory: URL = FileManager.default.temporaryDirectory
    
    @objc public static let shared = FileUtility()
    
    /// Get size of dictionary, including subdirectries.
    ///
    /// - Parameters:
    ///    - pathURL: root url to get size
    ///    - size: total size of directory
    public func pathSizeInBytes(pathURL: URL, size: inout Int64) {
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
            DDLogError("\(error.localizedDescription)")
        }
    }
    
    /// Get size of file.
    ///
    /// - Parameters:
    ///    - fileURL: url of file
    ///
    /// - Returns: file size in bytes
    public func fileSizeInBytes(fileURL: URL) -> Int64? {
        let fileManager = FileManager.default
        
        do {
            let fileAttr = try fileManager.attributesOfItem(atPath: fileURL.path)
            return fileAttr[FileAttributeKey.size] as? Int64
        }
        catch {
            DDLogError("\(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Get size of file for Objective C.
    /// - Parameters:
    ///    - fileURL: url of file
    /// - Returns: file size in bytes or 0
    @objc public func fileSizeInBytesObjc(fileURL: URL) -> Int64 {
        if let fileSize = fileSizeInBytes(fileURL: fileURL) {
            return fileSize
        }
        return 0
    }
    
    @objc public func getFileSizeDescription(for fileURL: URL) -> String? {
        guard let fileSize = fileSizeInBytes(fileURL: fileURL) else {
            return nil
        }
        return getFileSizeDescription(from: fileSize)
    }
    
    @objc public func getFileSizeDescription(from fileSize: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .binary)
    }
    
    @objc public func getTemporaryFileName() -> String {
        var filename = ProcessInfo().globallyUniqueString
        let url = FileManager.default.temporaryDirectory
        var fileURL = url.appendingPathComponent(filename)

        while isExists(fileURL: fileURL) {
            filename = ProcessInfo().globallyUniqueString
            fileURL = url.appendingPathComponent(filename)
        }
        return filename
    }
    
    @objc public func getTemporarySendableFileName(
        base: String,
        directoryURL: URL,
        pathExtension: String? = nil
    ) -> String {
        let filename = base + "-" + DateFormatter.getDateForFilename(Date())
        
        return getUniqueFilename(from: filename, directoryURL: directoryURL, pathExtension: pathExtension)
    }
    
    @objc public func getUniqueFilename(
        from filename: String,
        directoryURL: URL,
        pathExtension: String? = nil
    ) -> String {
        var newFilename = filename
        
        var fileURL = directoryURL.appendingPathComponent(filename)
        if let pathExtension {
            fileURL = fileURL.appendingPathExtension(pathExtension)
        }
        
        var i = 0
        while isExists(fileURL: fileURL) {
            newFilename = filename.appending("-\(i)")
            fileURL = directoryURL.appendingPathComponent(newFilename)
            if let pathExtension {
                fileURL = fileURL.appendingPathExtension(pathExtension)
            }
            i += 1
        }
        
        return newFilename
    }
    
    @objc public func getTemporarySendableFileName(base: String) -> String {
        let url = FileManager.default.temporaryDirectory
        return getTemporarySendableFileName(base: base, directoryURL: url)
    }
    
    @objc public func isExists(fileURL: URL?) -> Bool {
        guard let fileURL else {
            return false
        }
        
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    @objc public func dir(pathURL: URL?) -> [String]? {
        guard let pathURL else {
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
    @objc public func delete(at: URL?) {
        guard let atURL = at else {
            return
        }
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: atURL.path) {
            try? fileManager.removeItem(atPath: atURL.path)
        }
    }

    public func mkDir(at: URL) -> Bool {
        let fileManager = FileManager.default
        
        do {
            try fileManager.createDirectory(at: at, withIntermediateDirectories: false, attributes: nil)
            
            return true
        }
        catch {
            DDLogError("\(error.localizedDescription)")
        }
        
        return false
    }
    
    @objc public func move(source: URL, destination: URL) -> Bool {
        let fileManager = FileManager.default
        
        do {
            try fileManager.moveItem(at: source, to: destination)
            DDLogInfo("Moved file from: \(source.path) to: \(destination.path)")
            return true
        }
        catch {
            DDLogError("\(error.localizedDescription)")
        }
        
        return false
    }
    
    @objc public func copy(source: URL, destination: URL) -> Bool {
        let fileManager = FileManager.default
        
        do {
            try fileManager.copyItem(at: source, to: destination)
            DDLogInfo("Copied file from: \(source.path) to: \(destination.path)")
            return true
        }
        catch {
            DDLogError("\(error.localizedDescription)")
        }
        
        return false
    }
    
    @discardableResult public func write(fileURL: URL?, contents: Data?) -> Bool {
        guard let fileURL else {
            return false
        }
        
        let fileManager = FileManager.default
        return fileManager.createFile(atPath: fileURL.path, contents: contents, attributes: nil)
    }
    
    public func read(fileURL: URL?) -> Data? {
        guard let fileURL else {
            return nil
        }
        
        var content: Data?
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            content = fileHandle.readDataToEndOfFile()
            fileHandle.closeFile()
        }
        catch {
            DDLogError("\(error.localizedDescription)")
        }
        
        return content
    }
    
    /// Append text to the end of file.
    ///
    /// - Parameters:
    ///    - filePath: path to appending file
    ///    - text: content to addend
    public func append(fileURL: URL?, text: String) -> Bool {
        guard let fileURL else {
            return false
        }
        
        var result = false

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = Data(text.utf8)
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
            catch {
                DDLogError("\(error.localizedDescription)")
            }
            
            result = true
        }
        else {
            result = write(fileURL: fileURL, text: text)
        }
        
        return result
    }

    @objc public func logDirectoriesAndFiles(path: URL, logFileName: String?) {
        let fileManager = FileManager.default
        
        do {
            DDLogNotice("Log files form \(path.path) into \(logFileName ?? "debug_log.txt")")
            
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey, .fileSizeKey]
            
            var logFiles = ""
            
            if let urls = fileManager.enumerator(at: path, includingPropertiesForKeys: resourceKeys) {
                for case let url as URL in urls {
                    let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                    let logFile =
                        "\(url.path) \(ByteCountFormatter.string(fromByteCount: Int64(resourceValues.fileSize ?? 0), countStyle: ByteCountFormatter.CountStyle.file)) \(resourceValues.creationDate!) \(resourceValues.isDirectory!)"
                    DDLogNotice(logFile)
                    logFiles += "\(logFile)\n"
                }
            }
            
            if let logFileName,
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
                    DDLogError("\(error.localizedDescription)")
                }
            }
        }
        catch {
            DDLogError("\(error.localizedDescription)")
        }
    }
    
    @objc public func cleanTemporaryDirectory(olderThan: Date? = nil) {
        guard let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date()) else {
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
                        .contentModificationDate! < olderThan ?? twoDaysAgo
                }
            
            for item in oldTempFiles {
                DDLogInfo("Removing file: \(item)")
                try FileManager.default.removeItem(at: item)
            }
        }
        catch {
            DDLogError("An error occurred while cleaning the temporary directory \(error)")
        }
    }
}
