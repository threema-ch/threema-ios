import CocoaLumberjackSwift
import Foundation

public protocol FileUtilityProtocol: AnyObject {
    
    /// Returns the URL to the application's documents directory.
    var appDocumentsDirectory: URL? { get }
    
    /// Returns the URL to the application's caches directory.
    var appCachesDirectory: URL? { get }
    
    /// Returns the URL to the application's temporary directory.
    var appTemporaryDirectory: URL { get }
    
    /// Returns the URL to the application's temporary directory for unencrypted files.
    var appTemporaryUnencryptedDirectory: URL { get }

    /// Returns the URL to the application's group data directory.
    /// - Parameter appGroupID: AppGroup ID
    /// - Returns: URL to the application's group data directory.
    func appDataDirectory(appGroupID: String) -> URL?

    // MARK: Disk space and calculation sizes of resources

    func freeDiskSpaceInBytes() -> Int64

    /// Get size of dictionary, including subdirectories.
    /// - Parameters:
    ///    - pathURL: root url to get size
    ///    - size: total size of directory
    func pathSizeInBytes(pathURL: URL, size: inout Int64)

    /// Retrieves the size of the file at the specified URL in bytes.
    /// - Parameter fileURL: The URL of the file to check.
    /// - Returns: The size of the file in bytes, or nil if an error occurred.
    func fileSizeInBytes(fileURL: URL) -> Int64?

    /// Retrieves a human-readable description of the file size for the file at the specified URL.
    /// - Parameter fileURL: The URL of the file to describe.
    /// - Returns: A string describing the file size, or nil if an error occurred.
    func getFileSizeDescription(for fileURL: URL) -> String?

    func getFileSizeDescription(from fileSize: Int64) -> String

    // MARK: Generate file names

    /// Generates a temporary file name.
    /// - Returns: A string representing a unique temporary file name.
    func getTemporaryFileName() -> String

    func getTemporarySendableFileName(base: String) -> String

    /// Generates a temporary file name suitable for sending, based on a base name, directory, and optional file
    /// extension.
    /// - Parameters:
    ///   - base: The base name for the temporary file.
    ///   - directoryURL: The URL of the directory where the file will be located.
    ///   - pathExtension: An optional file extension to append to the file name.
    /// - Returns: A string representing a unique temporary file name suitable for sending.
    func getTemporarySendableFileName(
        base: String,
        directoryURL: URL,
        pathExtension: String?
    ) -> String

    func getUniqueFilename(
        from filename: String,
        directoryURL: URL,
        pathExtension: String?
    ) -> String

    // MARK: Directory and file operations

    /// Checks whether a file exists at the specified URL.
    /// - Parameter fileURL: The URL of the file to check.
    /// - Returns: A Boolean value indicating whether the file exists.
    func fileExists(at fileURL: URL?) -> Bool
    
    func fileExists(atPath path: String) -> Bool
    
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool

    /// Create directory, but no intermediate directories.
    /// - Parameter url: The URL at which to create the directory.
    func mkDir(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws
    
    func mkDir(
        atPath path: String,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws

    /// Retrieves the contents of the directory at the specified URL.
    /// - Parameter sourceURL: The URL of the directory to retrieve contents from.
    /// - Returns: An array of URL's representing the names of items in the directory, or nil if an error occurred.
    func dir(at sourceURL: URL?) -> [URL]?

    /// Enumerator of resources at given path
    /// - Parameter atPath: Path
    func enumerator(atPath path: String) -> FileManager.DirectoryEnumerator?

    /// Copies a file from a source URL to a destination URL.
    /// - Parameters:
    ///   - sourceURL: The source URL of the file to copy.
    ///   - destinationURL: The destination URL where the file should be copied to.
    func copy(from sourceURL: URL, to destinationURL: URL) throws

    /// Moves a file from a source URL to a destination URL.
    /// - Parameters:
    ///   - sourceURL: The source URL of the file to move.
    ///   - destinationURL: The destination URL where the file should be moved to.
    func move(from sourceURL: URL, to destinationURL: URL) throws
    
    func move(fromPath srcPath: String, toPath dstPath: String) throws

    func mergeContentsOfPath(from sourceURL: URL, to destinationURL: URL) throws

    /// If source file exists, move to destination. Destination will be deleted before moving source.
    /// - Parameters:
    ///   - sourceURL: The source URL of the file to replace
    ///   - destinationURL: The destination that will be replaced by source
    func replaceFile(from sourceURL: URL, to destinationURL: URL) throws

    /// Deletes the file or directory at the specified URL.
    /// - Parameter sourceURL: The URL of the file to delete.
    func delete(at sourceURL: URL) throws

    /// Deletes the file or directory if exists.
    /// - Parameter sourceURL: URL to file or directory
    func deleteIfExists(at sourceURL: URL?)
    
    func isDeletableFile(atPath path: String) -> Bool
    
    func delete(atPath path: String) throws

    /// Removes all items in all directories managed by the file utility.
    /// - Parameter appGroupID: AppGroup-ID
    func removeItemsInAllDirectories(appGroupID: String)

    /// Remove all items in a directory
    /// - Parameter directoryURL: URL of the directory
    func removeItemsInDirectory(directoryURL: URL)

    /// Cleans the temporary directory by removing files older than the specified date.
    /// - Parameter olderThan: The date to compare file modification dates against, or nil to clean all files.
    func cleanTemporaryDirectory(olderThan: Date?)
    
    func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey: Any]
    
    func contentsOfDirectory(atPath path: String) throws -> [String]

    // MARK: Read and write file

    /// Reads and returns the data from the file at the specified URL.
    /// - Parameter fileURL: The URL of the file to read from.
    /// - Returns: The data read from the file, or nil if an error occurred.
    func read(fileURL: URL?) -> Data?

    /// Writes data to the file at the specified URL.
    /// - Parameters:
    ///   - fileURL: The URL of the file to write to.
    ///   - contents: The data to write to the file.
    /// - Returns: A Boolean value indicating whether the write operation was successful.
    @discardableResult
    func write(contents: Data?, to fileURL: URL?) -> Bool

    /// Logs the directories and files at the specified path to a file.
    /// - Parameters:
    ///   - pathURL: The URL of the directory to log.
    func logDirectoriesAndFiles(pathURL: URL)

    // MARK: Update file attributes

    func updateProtectionFormCompleteToCompleteUntilFirstUserAuthentication(at directoryURL: URL)

    /// Set file attribute `URLResourceKey.isExcludedFromBackupKey` of files in app documents and
    /// app group folder with name prefixes. And all files in app caches folder.
    ///
    /// - Parameters:
    /// - namePrefixes: File or directory name prefixes to set file attribute
    /// - exclude: Value of file attribute `URLResourceKey.isExcludedFromBackupKey`
    /// - appGroupID: AppGroup ID of the current App
    func backup(of namePrefixes: [String], exclude: Bool, appGroupID: String) throws
}

extension FileUtilityProtocol {
    public func cleanTemporaryDirectory() {
        cleanTemporaryDirectory(olderThan: nil)
    }
}
