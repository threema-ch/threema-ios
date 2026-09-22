import CocoaLumberjackSwift
import Foundation

public final class FileUtility: NSObject, FileUtilityProtocol {
    
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
    
    /// Temporary app directory for unencrypted files.
    ///
    /// The directory is created on access if it is missing. Do not cache the returned URL: several routines wipe
    /// `tmp/` wholesale and take this directory with them, `removeItemsInDirectory(directoryURL:)` on
    /// `appTemporaryDirectory` and `cleanTemporaryDirectory(olderThan:)`, which lists top-level entries with
    /// `.skipsSubdirectoryDescendants`, among them.
    @objc public var appTemporaryUnencryptedDirectory: URL {
        createDirectoryIfNeeded(at: temporaryUnencryptedDirectory)
        return temporaryUnencryptedDirectory
    }

    /// Location of `appTemporaryUnencryptedDirectory`. Use that property, it also creates the directory.
    private let temporaryUnencryptedDirectory: URL
    
    @objc override public convenience init() {
        self.init(resolver: FileManagerResolver())
    }
    
    init(resolver: FileManagerResolverProtocol) {
        let fileManager = resolver.fileManager
        self.fileManager = fileManager
        self.appTemporaryDirectory = fileManager.temporaryDirectory
        self.temporaryUnencryptedDirectory =
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
        
        createDirectoryIfNeeded(at: temporaryUnencryptedDirectory)
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

    public func getTemporaryFileName() -> String {
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

    public func getUniqueFilename(
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

    public func createEmptyFile(atURL url: URL) throws {
        guard !fileExists(at: url) else {
            throw FileUtilityError.fileAlreadyExists
        }

        try "".write(to: url, atomically: true, encoding: .utf8)
    }

    @objc @discardableResult
    public func createFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey: Any]?
    ) -> Bool {
        fileManager.createFile(atPath: path, contents: data, attributes: attr)
    }

    public func createFileHandle(forReadingFromURL url: URL) throws -> FileHandle {
        try FileHandle(forReadingFrom: url)
    }

    public func createFileHandle(forWritingToURL url: URL) throws -> FileHandle {
        try FileHandle(forWritingTo: url)
    }

    public func closeFileHandle(_ fileHandle: FileHandle) throws {
        try fileHandle.close()
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
            attributes: attributes
        )
        DDLogInfo("Created directory at \(url.path)")
    }

    /// Create a directory unless there already is one at `url`.
    private func createDirectoryIfNeeded(at url: URL) {
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else {
                return
            }

            DDLogWarn("A file occupies the directory path \(url.path), removing it")
            deleteIfExists(at: url)
        }

        do {
            try mkDir(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        catch {
            DDLogError("Failed to create directory at \(url.path): \(error)")
        }
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
        [
            appDataDirectory(appGroupID: appGroupID),
            appDocumentsDirectory,
            appCachesDirectory,
            appTemporaryDirectory
        ]
        .compactMap(\.self)
        .forEach { removeItemsInDirectory(directoryURL: $0) }

        DDLogNotice("Deleted items in all directories.")
    }

    public func removeItemsInDirectory(directoryURL: URL) {
        if let items = dir(at: directoryURL) {
            items.forEach { deleteIfExists(at: $0) }
        }
    }

    public func cleanTemporaryDirectory(olderThan: Date?) {
        guard let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date()) else {
            DDLogError("Could not get date for two days ago")
            return
        }

        let cutOffDate = olderThan ?? twoDaysAgo

        // The unencrypted directory is a top level entry of `tmp/`, so it is a removal candidate as soon as its own
        // modification date is old enough, and removing it takes everything in it along, however recent. Clean its
        // contents instead and leave the directory in place.
        removeItems(in: appTemporaryDirectory, olderThan: cutOffDate, preserving: [temporaryUnencryptedDirectory])

        if fileExists(at: temporaryUnencryptedDirectory) {
            removeItems(in: temporaryUnencryptedDirectory, olderThan: cutOffDate)
        }
    }

    /// Remove the top level items of a directory that were last modified before a date.
    ///
    /// Subdirectories are removed as a whole, judged by their own modification date. The directory itself is kept.
    /// A failure on one item does not stop the remaining ones from being removed.
    ///
    /// - Parameters:
    ///   - directoryURL: Directory to remove items in
    ///   - date: Items last modified before this date are removed
    ///   - preserved: Items that are never removed, and whose contents are not inspected
    private func removeItems(in directoryURL: URL, olderThan date: Date, preserving preserved: [URL] = []) {
        let preservedPaths = Set(preserved.map(\.path))

        do {
            let items = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )

            for item in items where !preservedPaths.contains(item.path) {
                // Keep anything whose age cannot be established
                guard let contentModificationDate = try? item
                    .resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate,
                    contentModificationDate < date
                else {
                    continue
                }

                do {
                    try fileManager.removeItem(at: item)
                    DDLogInfo("Removed \(item.path)")
                }
                catch {
                    DDLogError("Failed to remove \(item.path): \(error)")
                }
            }
        }
        catch {
            DDLogError("An error occurred while cleaning \(directoryURL.path): \(error)")
        }
    }
    
    public func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey: Any] {
        try fileManager.attributesOfFileSystem(forPath: path)
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: path)
    }

    public func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
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

    public func read(offset: UInt64?, length: UInt64?, from fileHandle: FileHandle, fileURL: URL) throws -> Data {
        if let offset {
            try fileHandle.seek(toOffset: offset)
        }

        if let length {
            guard let data = try fileHandle.read(upToCount: Int(length)) else {
                throw FileUtilityError.readFailed
            }
            return data
        }
        else {
            guard let data = try fileHandle.readToEnd() else {
                throw FileUtilityError.readFailed
            }
            return data
        }
    }

    public func write(contents: Data, offset: UInt64?, to fileHandle: FileHandle, fileURL: URL) throws {
        if let offset {
            try fileHandle.seek(toOffset: offset)
        }
        else {
            try fileHandle.seekToEnd()
        }
        try fileHandle.write(contentsOf: contents)
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
