import FileUtility
import RemoteSecretProtocol

public final class FileUtilityRemoteSecretDecorator: FileUtilityProtocol {
    public var appDocumentsDirectory: URL? {
        wrapped.appDocumentsDirectory
    }
    
    public var appCachesDirectory: URL? {
        wrapped.appCachesDirectory
    }
    
    public var appTemporaryDirectory: URL {
        wrapped.appTemporaryDirectory
    }
    
    public var appTemporaryUnencryptedDirectory: URL {
        wrapped.appTemporaryUnencryptedDirectory
    }
    
    private let wrapped: FileUtilityProtocol
    private let remoteSecretManager: RemoteSecretManagerProtocol
    private let whitelist: Set<String>
    
    public init(
        wrapped: FileUtilityProtocol,
        remoteSecretManager: RemoteSecretManagerProtocol,
        whitelist: Set<String>
    ) {
        self.wrapped = wrapped
        self.remoteSecretManager = remoteSecretManager
        self.whitelist = whitelist
    }
    
    public func appDataDirectory(appGroupID: String) -> URL? {
        wrapped.appDataDirectory(appGroupID: appGroupID)
    }
    
    public func freeDiskSpaceInBytes() -> Int64 {
        wrapped.freeDiskSpaceInBytes()
    }
    
    public func pathSizeInBytes(pathURL: URL, size: inout Int64) {
        wrapped.pathSizeInBytes(pathURL: pathURL, size: &size)
    }
    
    public func fileSizeInBytes(fileURL: URL) -> Int64? {
        wrapped.fileSizeInBytes(fileURL: fileURL)
    }
    
    public func getFileSizeDescription(for fileURL: URL) -> String? {
        wrapped.getFileSizeDescription(for: fileURL)
    }
    
    public func getFileSizeDescription(from fileSize: Int64) -> String {
        wrapped.getFileSizeDescription(from: fileSize)
    }
    
    public func getTemporaryFileName() -> String {
        wrapped.getTemporaryFileName()
    }
    
    public func getTemporarySendableFileName(base: String) -> String {
        wrapped.getTemporarySendableFileName(base: base)
    }
    
    public func getTemporarySendableFileName(
        base: String,
        directoryURL: URL,
        pathExtension: String?
    ) -> String {
        wrapped.getTemporarySendableFileName(
            base: base,
            directoryURL: directoryURL,
            pathExtension: pathExtension
        )
    }
    
    public func getUniqueFilename(
        from filename: String,
        directoryURL: URL,
        pathExtension: String?
    ) -> String {
        wrapped.getUniqueFilename(
            from: filename,
            directoryURL: directoryURL,
            pathExtension: pathExtension
        )
    }
    
    public func fileExists(at fileURL: URL?) -> Bool {
        wrapped.fileExists(at: fileURL)
    }
    
    public func fileExists(atPath path: String) -> Bool {
        wrapped.fileExists(atPath: path)
    }
    
    public func createFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey: Any]?
    ) -> Bool {
        wrapped.createFile(
            atPath: path,
            contents: data,
            attributes: attr
        )
    }
    
    public func mkDir(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
        try wrapped.mkDir(
            at: url,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes
        )
    }
    
    public func mkDir(
        atPath path: String,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
        try wrapped.mkDir(
            atPath: path,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes
        )
    }
    
    public func dir(at sourceURL: URL?) -> [URL]? {
        wrapped.dir(at: sourceURL)
    }
    
    public func enumerator(atPath path: String) -> FileManager.DirectoryEnumerator? {
        wrapped.enumerator(atPath: path)
    }
    
    public func copy(from sourceURL: URL, to destinationURL: URL) throws {
        try wrapped.copy(from: sourceURL, to: destinationURL)
    }
    
    public func move(from sourceURL: URL, to destinationURL: URL) throws {
        try wrapped.move(from: sourceURL, to: destinationURL)
    }
    
    public func move(fromPath srcPath: String, toPath dstPath: String) throws {
        try wrapped.move(fromPath: srcPath, toPath: dstPath)
    }
    
    public func mergeContentsOfPath(from sourceURL: URL, to destinationURL: URL) throws {
        try wrapped.mergeContentsOfPath(from: sourceURL, to: destinationURL)
    }
    
    public func replaceFile(from sourceURL: URL, to destinationURL: URL) throws {
        try wrapped.replaceFile(from: sourceURL, to: destinationURL)
    }
    
    public func delete(at sourceURL: URL) throws {
        try wrapped.delete(at: sourceURL)
    }
    
    public func deleteIfExists(at sourceURL: URL?) {
        wrapped.deleteIfExists(at: sourceURL)
    }
    
    public func isDeletableFile(atPath path: String) -> Bool {
        wrapped.isDeletableFile(atPath: path)
    }
    
    public func delete(atPath path: String) throws {
        try wrapped.delete(atPath: path)
    }
    
    public func removeItemsInAllDirectories(appGroupID: String) {
        wrapped.removeItemsInAllDirectories(appGroupID: appGroupID)
    }
    
    public func removeItemsInDirectory(directoryURL: URL) {
        wrapped.removeItemsInDirectory(directoryURL: directoryURL)
    }
    
    public func cleanTemporaryDirectory(olderThan: Date?) {
        wrapped.cleanTemporaryDirectory(olderThan: olderThan)
    }
    
    public func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey: Any] {
        try wrapped.attributesOfFileSystem(forPath: path)
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [String] {
        try wrapped.contentsOfDirectory(atPath: path)
    }
    
    public func read(fileURL: URL?) -> Data? {
        guard let fileData = wrapped.read(fileURL: fileURL) else {
            return nil
        }
        
        guard shouldAllowEncryption(fileURL) else {
            return fileData
        }
        
        let decryptedData = remoteSecretManager.decryptDataIfNeeded(fileData)
        return decryptedData
    }
    
    public func write(contents: Data?, to fileURL: URL?) -> Bool {
        guard shouldAllowEncryption(fileURL) else {
            return wrapped.write(contents: contents, to: fileURL)
        }
        
        let fileData = remoteSecretManager.encryptDataIfNeeded(contents)
        return wrapped.write(contents: fileData, to: fileURL)
    }
    
    public func logDirectoriesAndFiles(pathURL: URL) {
        wrapped.logDirectoriesAndFiles(pathURL: pathURL)
    }
    
    public func updateProtectionFormCompleteToCompleteUntilFirstUserAuthentication(
        at directoryURL: URL
    ) {
        wrapped.updateProtectionFormCompleteToCompleteUntilFirstUserAuthentication(
            at: directoryURL
        )
    }
    
    public func backup(
        of namePrefixes: [String],
        exclude: Bool,
        appGroupID: String
    ) throws {
        try wrapped.backup(
            of: namePrefixes,
            exclude: exclude,
            appGroupID: appGroupID
        )
    }
    
    // MARK: - Helpers

    private func shouldAllowEncryption(_ url: URL?) -> Bool {
        whitelist.contains(where: {
            url?.absoluteString.contains($0) ?? false
        }) == false
    }
}
