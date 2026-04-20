import FileUtility
import RemoteSecretProtocol

final class CrashingFileUtilityRemoteSecretDecorator: FileUtilityProtocol {
    var appDocumentsDirectory: URL? {
        wrapped.appDocumentsDirectory
    }
    
    var appCachesDirectory: URL? {
        wrapped.appCachesDirectory
    }
    
    var appTemporaryDirectory: URL {
        wrapped.appTemporaryDirectory
    }
    
    var appTemporaryUnencryptedDirectory: URL {
        wrapped.appTemporaryUnencryptedDirectory
    }
    
    private let wrapped: FileUtilityProtocol
    private let whitelist: Set<String>
    
    init(
        wrapped: FileUtilityProtocol,
        whitelist: Set<String>
    ) {
        self.wrapped = wrapped
        self.whitelist = whitelist
    }
    
    func appDataDirectory(appGroupID: String) -> URL? {
        wrapped.appDataDirectory(appGroupID: appGroupID)
    }
    
    func freeDiskSpaceInBytes() -> Int64 {
        wrapped.freeDiskSpaceInBytes()
    }
    
    func pathSizeInBytes(pathURL: URL, size: inout Int64) {
        wrapped.pathSizeInBytes(pathURL: pathURL, size: &size)
    }
    
    func fileSizeInBytes(fileURL: URL) -> Int64? {
        wrapped.fileSizeInBytes(fileURL: fileURL)
    }
    
    func getFileSizeDescription(for fileURL: URL) -> String? {
        wrapped.getFileSizeDescription(for: fileURL)
    }
    
    func getFileSizeDescription(from fileSize: Int64) -> String {
        wrapped.getFileSizeDescription(from: fileSize)
    }
    
    func getTemporaryFileName() -> String {
        wrapped.getTemporaryFileName()
    }
    
    func getTemporarySendableFileName(base: String) -> String {
        wrapped.getTemporarySendableFileName(base: base)
    }
    
    func getTemporarySendableFileName(
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
    
    func getUniqueFilename(
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
    
    func fileExists(at fileURL: URL?) -> Bool {
        wrapped.fileExists(at: fileURL)
    }
    
    func fileExists(atPath path: String) -> Bool {
        wrapped.fileExists(atPath: path)
    }
    
    func createFile(
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
    
    func mkDir(
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
    
    func mkDir(
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
    
    func dir(at sourceURL: URL?) -> [URL]? {
        wrapped.dir(at: sourceURL)
    }
    
    func enumerator(atPath path: String) -> FileManager.DirectoryEnumerator? {
        wrapped.enumerator(atPath: path)
    }
    
    func copy(from sourceURL: URL, to destinationURL: URL) throws {
        try wrapped.copy(from: sourceURL, to: destinationURL)
    }
    
    func move(from sourceURL: URL, to destinationURL: URL) throws {
        try wrapped.move(from: sourceURL, to: destinationURL)
    }
    
    func move(fromPath srcPath: String, toPath dstPath: String) throws {
        try wrapped.move(fromPath: srcPath, toPath: dstPath)
    }
    
    func mergeContentsOfPath(from sourceURL: URL, to destinationURL: URL) throws {
        try wrapped.mergeContentsOfPath(from: sourceURL, to: destinationURL)
    }
    
    func replaceFile(from sourceURL: URL, to destinationURL: URL) throws {
        try wrapped.replaceFile(from: sourceURL, to: destinationURL)
    }
    
    func delete(at sourceURL: URL) throws {
        try wrapped.delete(at: sourceURL)
    }
    
    func deleteIfExists(at sourceURL: URL?) {
        wrapped.deleteIfExists(at: sourceURL)
    }
    
    func isDeletableFile(atPath path: String) -> Bool {
        wrapped.isDeletableFile(atPath: path)
    }
    
    func delete(atPath path: String) throws {
        try wrapped.delete(atPath: path)
    }
    
    func removeItemsInAllDirectories(appGroupID: String) {
        wrapped.removeItemsInAllDirectories(appGroupID: appGroupID)
    }
    
    func removeItemsInDirectory(directoryURL: URL) {
        wrapped.removeItemsInDirectory(directoryURL: directoryURL)
    }
    
    func cleanTemporaryDirectory(olderThan: Date?) {
        wrapped.cleanTemporaryDirectory(olderThan: olderThan)
    }
    
    func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey: Any] {
        try wrapped.attributesOfFileSystem(forPath: path)
    }
    
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try wrapped.contentsOfDirectory(atPath: path)
    }
    
    func read(fileURL: URL?) -> Data? {
        guard shouldAllowOperation(fileURL) else {
            fatalError(
                "Correct instance of FileUtilityProtocol must be used for reading at \(String(describing: fileURL))."
            )
        }
        
        guard let fileData = wrapped.read(fileURL: fileURL) else {
            return nil
        }
        
        return fileData
    }
    
    func write(contents: Data?, to fileURL: URL?) -> Bool {
        guard shouldAllowOperation(fileURL) else {
            fatalError(
                "Correct instance of FileUtilityProtocol must be used for writing at \(String(describing: fileURL))."
            )
        }
        
        return wrapped.write(contents: contents, to: fileURL)
    }
    
    func logDirectoriesAndFiles(pathURL: URL) {
        wrapped.logDirectoriesAndFiles(pathURL: pathURL)
    }
    
    func updateProtectionFormCompleteToCompleteUntilFirstUserAuthentication(
        at directoryURL: URL
    ) {
        wrapped.updateProtectionFormCompleteToCompleteUntilFirstUserAuthentication(
            at: directoryURL
        )
    }
    
    func backup(
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

    private func shouldAllowOperation(_ url: URL?) -> Bool {
        whitelist.contains(where: {
            url?.absoluteString.contains($0) ?? false
        })
    }
}
