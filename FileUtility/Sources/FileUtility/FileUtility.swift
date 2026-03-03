//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
    
    public private(set) nonisolated(unsafe) static var shared: FileUtilityProtocol!
    
    public static func updateSharedInstance(with fileUtility: FileUtilityProtocol) {
        shared = fileUtility
    }

    private let fileManager: FileManager

    private lazy var filenameDateFormatter: DateFormatter = {
        let filenameDateFormatter = DateFormatter()
        // Always use this locale for locale independent formats (see https://nsdateformatter.com)
        filenameDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        filenameDateFormatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return filenameDateFormatter
    }()
    
    @objc public let appDocumentsDirectory: URL?

    public let appCachesDirectory: URL?

    /// Temporary app directory
    ///
    /// Please remove data stored here that is no longer needed: https://stackoverflow.com/a/25067497
    public let appTemporaryDirectory: URL
    
    @objc public let appTemporaryUnencryptedDirectory: URL
    
    @objc override public convenience init() {
        self.init(resolver: FileManagerResolver())
    }
    
    init(resolver: FileManagerResolverProtocol) {
        let fileManager = resolver.fileManager
        self.fileManager = fileManager
        self.appTemporaryDirectory = fileManager.temporaryDirectory
        self.appTemporaryUnencryptedDirectory =
            fileManager.temporaryDirectory.appendingPathComponent("unencrypted")
        self.appDocumentsDirectory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).last
        self.appCachesDirectory = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).last
        
        super.init()
        
        try? mkDir(
            at: appTemporaryUnencryptedDirectory,
            withIntermediateDirectories: false,
            attributes: nil
        )
    }

    public func appDataDirectory(appGroupID: String) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    
    // MARK: Disk space and calculation sizes of resources

    public func freeDiskSpaceInBytes() -> Int64 {
        var capacityInBytes: Int64?

        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            capacityInBytes = values.volumeAvailableCapacityForImportantUsage
        }
        catch {
            DDLogError("Cannot retrieve free disk space: \(error)")
        }

        return capacityInBytes ?? 0
    }

    public func pathSizeInBytes(pathURL: URL, size: inout Int64) {
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
            DDLogError("Failed to calculate size of \(pathURL.path): \(error)")
        }
    }

    public func fileSizeInBytes(fileURL: URL) -> Int64? {
        do {
            let fileAttr = try fileManager.attributesOfItem(atPath: fileURL.path)
            return fileAttr[FileAttributeKey.size] as? Int64
        }
        catch {
            DDLogError("\(error)")
        }

        return nil
    }

    public func getFileSizeDescription(for fileURL: URL) -> String? {
        guard let fileSize = fileSizeInBytes(fileURL: fileURL) else {
            return nil
        }
        return getFileSizeDescription(from: fileSize)
    }

    @objc public func getFileSizeDescription(from fileSize: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .binary)
    }

    // MARK: Generate file names

    @objc public func getTemporaryFileName() -> String {
        var filename = ProcessInfo().globallyUniqueString
        let url = fileManager.temporaryDirectory
        var fileURL = url.appendingPathComponent(filename)

        while fileExists(at: fileURL) {
            filename = ProcessInfo().globallyUniqueString
            fileURL = url.appendingPathComponent(filename)
        }
        return filename
    }

    @objc public func getTemporarySendableFileName(base: String) -> String {
        let url = fileManager.temporaryDirectory
        return getTemporarySendableFileName(base: base, directoryURL: url)
    }

    @objc public func getTemporarySendableFileName(
        base: String,
        directoryURL: URL,
        pathExtension: String? = nil
    ) -> String {
        let filename = base + "-" + filenameDateFormatter.string(from: Date())

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
        while fileExists(at: fileURL) {
            newFilename = filename.appending("-\(i)")
            fileURL = directoryURL.appendingPathComponent(newFilename)
            if let pathExtension {
                fileURL = fileURL.appendingPathExtension(pathExtension)
            }
            i += 1
        }

        return newFilename
    }

    // MARK: Directory and file operations

    @objc public func fileExists(at fileURL: URL?) -> Bool {
        guard let fileURL else {
            return false
        }

        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    @objc @discardableResult
    public func createFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey: Any]?
    ) -> Bool {
        fileManager.createFile(atPath: path, contents: data, attributes: attr)
    }
    
    @objc public func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    public func mkDir(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates,
            attributes: nil
        )
        DDLogInfo("Created directory at \(url.path)")
    }
    
    public func mkDir(
        atPath path: String,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
        try fileManager.createDirectory(
            atPath: path,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes
        )
    }

    public func dir(at sourceURL: URL?) -> [URL]? {
        guard let sourceURL else {
            return nil
        }

        var items: [URL]?
        if fileManager.fileExists(atPath: sourceURL.path) {
            items = try? fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil, options: [])
        }
        return items
    }

    public func enumerator(atPath path: String) -> FileManager.DirectoryEnumerator? {
        fileManager.enumerator(atPath: path)
    }

    public func copy(from source: URL, to destination: URL) throws {
        try fileManager.copyItem(at: source, to: destination)
        DDLogInfo("Copied file from: \(source.path) to: \(destination.path)")
    }

    public func move(from sourceURL: URL, to destinationURL: URL) throws {
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        DDLogInfo("Moved file from: \(sourceURL.path) to: \(destinationURL.path)")
    }
    
    public func move(fromPath srcPath: String, toPath dstPath: String) throws {
        try fileManager.moveItem(atPath: srcPath, toPath: dstPath)
    }

    public func mergeContentsOfPath(from sourceURL: URL, to destinationURL: URL) throws {
        guard fileExists(at: sourceURL) else {
            return
        }

        guard fileExists(at: destinationURL) else {
            try move(from: sourceURL, to: destinationURL)
            return
        }

        let fileEnumerator = enumerator(atPath: sourceURL.path)

        while let fileName = fileEnumerator?.nextObject() as? String {
            let sourceFilePath = sourceURL.appendingPathComponent(fileName)
            let destinationFilePath = destinationURL.appendingPathComponent(fileName)

            if !fileExists(at: destinationFilePath) {
                try move(from: sourceFilePath, to: destinationFilePath)
            }
        }
    }

    public func replaceFile(from sourceURL: URL, to destinationURL: URL) throws {
        guard fileExists(at: sourceURL) else {
            return
        }

        if fileExists(at: destinationURL) {
            try delete(at: destinationURL)
        }
        try move(from: sourceURL, to: destinationURL)
    }

    @objc public func delete(at sourceURL: URL) throws {
        try fileManager.removeItem(atPath: sourceURL.path)
        DDLogInfo("Deleted files or directory at \(sourceURL.path)")
    }

    @objc public func deleteIfExists(at sourceURL: URL?) {
        guard let sourceURL else {
            return
        }

        if fileManager.fileExists(atPath: sourceURL.path) {
            do {
                try delete(at: sourceURL)
            }
            catch {
                DDLogError("Failed to delete file or directory at \(sourceURL.path): \(error)")
            }
        }
    }
    
    public func isDeletableFile(atPath path: String) -> Bool {
        fileManager.isDeletableFile(atPath: path)
    }
    
    @objc public func delete(atPath path: String) throws {
        try fileManager.removeItem(atPath: path)
    }

    public func removeItemsInAllDirectories(appGroupID: String) {
        appDocumentsDirectory.map(removeItemsInDirectory)
        appDataDirectory(appGroupID: appGroupID).map(removeItemsInDirectory)
        appCachesDirectory.map(removeItemsInDirectory)
        removeItemsInDirectory(directoryURL: appTemporaryDirectory)
        DDLogNotice("Deleted items in all directories.")
    }

    public func removeItemsInDirectory(directoryURL: URL) {
        if let items = dir(at: directoryURL) {
            items.forEach { deleteIfExists(at: $0) }
        }
    }

    @objc public func cleanTemporaryDirectory(olderThan: Date?) {
        guard let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date()) else {
            DDLogError("Could not get date for five days ago")
            return
        }
        let directoryURL = fileManager.temporaryDirectory
        do {
            let oldTempFiles = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
            .filter {
                guard let contentModificationDate = try $0
                    .promisedItemResourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate else {
                    return false
                }

                return contentModificationDate < olderThan ?? twoDaysAgo
            }

            for item in oldTempFiles {
                DDLogInfo("Removing file: \(item)")
                try fileManager.removeItem(at: item)
            }
        }
        catch {
            DDLogError("An error occurred while cleaning the temporary directory \(error)")
        }
    }
    
    public func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey: Any] {
        try fileManager.attributesOfFileSystem(forPath: path)
    }
    
    @objc public func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: path)
    }

    // MARK: Read and write file

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
            DDLogError("\(error)")
        }

        return content
    }

    @discardableResult
    public func write(contents: Data?, to fileURL: URL?) -> Bool {
        guard let fileURL else {
            return false
        }

        return fileManager.createFile(atPath: fileURL.path, contents: contents, attributes: nil)
    }

    public func logDirectoriesAndFiles(pathURL: URL) {
        do {
            DDLogNotice("Log files form \(pathURL.path) into debug_log.txt")

            let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey, .fileSizeKey]

            var logFiles = ""

            if let urls = fileManager.enumerator(at: pathURL, includingPropertiesForKeys: resourceKeys) {
                for case let url as URL in urls {
                    let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                    let logFile =
                        "\(url.path) \(ByteCountFormatter.string(fromByteCount: Int64(resourceValues.fileSize ?? 0), countStyle: ByteCountFormatter.CountStyle.file)) \(resourceValues.creationDate!) \(resourceValues.isDirectory!)"
                    DDLogNotice("\(logFile)")
                    logFiles += "\(logFile)\n"
                }
            }
        }
        catch {
            DDLogError("\(error)")
        }
    }

    // MARK: Update file attributes

    public func updateProtectionFormCompleteToCompleteUntilFirstUserAuthentication(at directoryURL: URL) {
        guard let directoryEnumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.fileProtectionKey],
            options: [],
            errorHandler: { url, error -> Bool in

                DDLogError("Error while enumerating directory \(url.path): \(error)")
                return false
            }
        ) else {
            DDLogError("Could not create directory enumerator at \(directoryURL.path)")
            return
        }

        for file in directoryEnumerator {
            guard let fileURL = file as? URL else {
                continue
            }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileProtectionKey])
                guard resourceValues.fileProtection == .complete else {
                    continue
                }

                try (fileURL as NSURL).setResourceValue(
                    URLFileProtection.completeUntilFirstUserAuthentication,
                    forKey: URLResourceKey.fileProtectionKey
                )
            }
            catch {
                DDLogError("Failed to set protection level for file \(fileURL.path): \(error)")
            }
        }
    }

    public func backup(of namePrefixes: [String], exclude: Bool, appGroupID: String) throws {
        func setIsExcludedFromBackup(_ sourceURL: URL?, namePrefixes: [String]?, exclude: Bool) {
            guard let sourceURL else {
                return
            }
            
            guard let resources = dir(at: sourceURL) else {
                return
            }

            for resource in resources {
                if let namePrefixes {
                    guard namePrefixes.contains(where: { name in
                        resource.lastPathComponent.hasPrefix(name)
                    }) else {
                        continue
                    }
                }

                do {
                    try resource.setResourceValue(exclude, forKey: .isExcludedFromBackupKey)
                    DDLogInfo("Excluded from backup attribute set for \(sourceURL.path)")
                }
                catch {
                    DDLogError("Failed to set is excluded from backup attribute for \(sourceURL.path): \(error)")
                }
            }
        }

        setIsExcludedFromBackup(
            appDocumentsDirectory,
            namePrefixes: namePrefixes,
            exclude: exclude
        )

        setIsExcludedFromBackup(
            appDataDirectory(appGroupID: appGroupID),
            namePrefixes: namePrefixes,
            exclude: exclude
        )

        setIsExcludedFromBackup(
            appCachesDirectory,
            namePrefixes: nil,
            exclude: exclude
        )
    }
}

extension URL {
    func setResourceValue(_ value: Any, forKey key: URLResourceKey) throws {
        try (self as NSURL).setResourceValue(value, forKey: key)
    }

    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
