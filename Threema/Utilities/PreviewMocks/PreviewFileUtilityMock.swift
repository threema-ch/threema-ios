#if DEBUG
    import FileUtility

    public final class PreviewFileUtilityMock: FileUtilityProtocol {

        public enum Call: Equatable, Sendable {
            case appDataDirectory(appGroupID: String)
            case freeDiskSpaceInBytes
            case pathSizeInBytes(pathURL: URL, sizeIn: Int64)
            case fileSizeInBytes(fileURL: URL)
            case getFileSizeDescriptionFor(fileURL: URL)
            case getFileSizeDescriptionFrom(fileSize: Int64)
            case getTemporaryFileName
            case getTemporarySendableFileNameBase(base: String)
            case getTemporarySendableFileName(base: String, directoryURL: URL, pathExtension: String?)
            case getUniqueFilename(filename: String, directoryURL: URL, pathExtension: String?)
            case fileExistsAtURL(URL?)
            case fileExistsAtPath(String)
            case createEmptyFile(url: URL)
            // attributes dropped: [FileAttributeKey: Any]? is not Equatable
            case createFile(path: String, contents: Data?)
            case createFileHandleForReading(url: URL)
            case createFileHandleForWriting(url: URL)
            // FileHandle is not Equatable; case carries no payload.
            case closeFileHandle
            case mkDirAtURL(url: URL, withIntermediateDirectories: Bool)
            case mkDirAtPath(path: String, withIntermediateDirectories: Bool)
            case dir(at: URL?)
            case enumerator(atPath: String)
            case copy(from: URL, to: URL)
            case moveURL(from: URL, to: URL)
            case movePath(fromPath: String, toPath: String)
            case mergeContentsOfPath(from: URL, to: URL)
            case replaceFile(from: URL, to: URL)
            case deleteAtURL(URL)
            case deleteIfExists(URL?)
            case isDeletableFile(atPath: String)
            case deleteAtPath(String)
            case removeItemsInAllDirectories(appGroupID: String)
            case removeItemsInDirectory(directoryURL: URL)
            case cleanTemporaryDirectory(olderThan: Date?)
            case attributesOfFileSystem(forPath: String)
            case contentsOfDirectoryAtPath(String)
            case contentsOfDirectoryAtURL(URL, keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions)
            case readFileURL(URL?)
            case readFromHandle(offset: UInt64?, length: UInt64?, fileURL: URL)
            case writeToHandle(contents: Data, offset: UInt64?, fileURL: URL)
            case writeToURL(contents: Data?, fileURL: URL?)
            case logDirectoriesAndFiles(pathURL: URL)
            case updateProtection(at: URL)
            case backup(namePrefixes: [String], exclude: Bool, appGroupID: String)
        }

        private struct State {
            var calls: [Call] = []

            var appDocumentsDirectory: URL?
            var appCachesDirectory: URL?
            var appTemporaryDirectory: URL = URL(fileURLWithPath: "/tmp")
            var appTemporaryUnencryptedDirectory: URL = URL(fileURLWithPath: "/tmp/unencrypted")

            var mockAppDataDirectory: (String) -> URL? = { _ in nil }
            var mockFreeDiskSpaceInBytes: () -> Int64 = { 0 }
            var mockPathSizeInBytes: (URL, inout Int64) -> Void = { _, _ in /* no-op */ }
            var mockFileSizeInBytes: (URL) -> Int64? = { _ in nil }
            var mockGetFileSizeDescriptionFor: (URL) -> String? = { _ in nil }
            var mockGetFileSizeDescriptionFrom: (Int64) -> String = { _ in "0 MB" }
            var mockGetTemporaryFileName: () -> String = { "temporary-file" }
            var mockGetTemporarySendableFileNameBase: (String) -> String = { "\($0)-temporary-file" }
            var mockGetTemporarySendableFileName: (String, URL, String?) -> String = { base, _, _ in base }
            var mockGetUniqueFilename: (String, URL, String?) -> String = { name, _, _ in name }
            var mockFileExistsAtURL: (URL?) -> Bool = { _ in false }
            var mockFileExistsAtPath: (String) -> Bool = { _ in false }
            var mockCreateEmptyFile: (URL) throws -> Void = { _ in /* no-op */ }
            var mockCreateFile: (String, Data?, [FileAttributeKey: Any]?) -> Bool = { _, _, _ in false }
            var mockCreateFileHandleForReading: (URL) throws -> FileHandle = { _ in .standardOutput }
            var mockCreateFileHandleForWriting: (URL) throws -> FileHandle = { _ in .standardOutput }
            var mockCloseFileHandle: (FileHandle) throws -> Void = { _ in /* no-op */ }
            var mockMkDirAtURL: (URL, Bool, [FileAttributeKey: Any]?) throws -> Void = { _, _, _ in /* no-op */ }
            var mockMkDirAtPath: (String, Bool, [FileAttributeKey: Any]?) throws -> Void = { _, _, _ in /* no-op */ }
            var mockDir: (URL?) -> [URL]? = { _ in nil }
            var mockEnumerator: (String) -> FileManager.DirectoryEnumerator? = { _ in nil }
            var mockCopy: (URL, URL) throws -> Void = { _, _ in /* no-op */ }
            var mockMoveURL: (URL, URL) throws -> Void = { _, _ in /* no-op */ }
            var mockMovePath: (String, String) throws -> Void = { _, _ in /* no-op */ }
            var mockMergeContentsOfPath: (URL, URL) throws -> Void = { _, _ in /* no-op */ }
            var mockReplaceFile: (URL, URL) throws -> Void = { _, _ in /* no-op */ }
            var mockDeleteAtURL: (URL) throws -> Void = { _ in /* no-op */ }
            var mockDeleteIfExists: (URL?) -> Void = { _ in /* no-op */ }
            var mockIsDeletableFile: (String) -> Bool = { _ in false }
            var mockDeleteAtPath: (String) throws -> Void = { _ in /* no-op */ }
            var mockRemoveItemsInAllDirectories: (String) -> Void = { _ in /* no-op */ }
            var mockRemoveItemsInDirectory: (URL) -> Void = { _ in /* no-op */ }
            var mockCleanTemporaryDirectory: (Date?) -> Void = { _ in /* no-op */ }
            var mockAttributesOfFileSystem: (String) throws -> [FileAttributeKey: Any] = { _ in [:] }
            var mockContentsOfDirectoryAtPath: (String) throws -> [String] = { _ in [] }
            var mockContentsOfDirectoryAtURL: (URL, [URLResourceKey]?, FileManager.DirectoryEnumerationOptions) throws -> [
                URL
            ] = { _, _, _ in [] }
            var mockReadFileURL: (URL?) -> Data? = { _ in nil }
            var mockReadFromHandle: (UInt64?, UInt64?, FileHandle, URL) throws -> Data = { _, _, _, _ in Data() }
            var mockWriteToHandle: (Data, UInt64?, FileHandle, URL) throws -> Void = { _, _, _, _ in /* no-op */ }
            var mockWriteToURL: (Data?, URL?) -> Bool = { _, _ in true }
            var mockLogDirectoriesAndFiles: (URL) -> Void = { _ in /* no-op */ }
            var mockUpdateProtection: (URL) -> Void = { _ in /* no-op */ }
            var mockBackup: ([String], Bool, String) throws -> Void = { _, _, _ in /* no-op */ }
        }

        private let state = OSAllocatedUnfairLock<State>(uncheckedState: State())

        public init() { /* no-op */ }

        // MARK: - FileUtilityProtocol properties

        public var appDocumentsDirectory: URL? {
            get { state.withLockUnchecked { $0.appDocumentsDirectory } }
            set { state.withLockUnchecked { $0.appDocumentsDirectory = newValue } }
        }

        public var appCachesDirectory: URL? {
            get { state.withLockUnchecked { $0.appCachesDirectory } }
            set { state.withLockUnchecked { $0.appCachesDirectory = newValue } }
        }

        public var appTemporaryDirectory: URL {
            get { state.withLockUnchecked { $0.appTemporaryDirectory } }
            set { state.withLockUnchecked { $0.appTemporaryDirectory = newValue } }
        }

        public var appTemporaryUnencryptedDirectory: URL {
            get { state.withLockUnchecked { $0.appTemporaryUnencryptedDirectory } }
            set { state.withLockUnchecked { $0.appTemporaryUnencryptedDirectory = newValue } }
        }

        // MARK: - FileUtilityProtocol methods

        public func appDataDirectory(appGroupID: String) -> URL? {
            let stub: (String) -> URL? = state.withLockUnchecked {
                $0.calls.append(.appDataDirectory(appGroupID: appGroupID))
                return $0.mockAppDataDirectory
            }
            return stub(appGroupID)
        }

        public func freeDiskSpaceInBytes() -> Int64 {
            let stub: () -> Int64 = state.withLockUnchecked {
                $0.calls.append(.freeDiskSpaceInBytes)
                return $0.mockFreeDiskSpaceInBytes
            }
            return stub()
        }

        public func pathSizeInBytes(pathURL: URL, size: inout Int64) {
            let stub: (URL, inout Int64) -> Void = state.withLockUnchecked {
                $0.calls.append(.pathSizeInBytes(pathURL: pathURL, sizeIn: size))
                return $0.mockPathSizeInBytes
            }
            stub(pathURL, &size)
        }

        public func fileSizeInBytes(fileURL: URL) -> Int64? {
            let stub: (URL) -> Int64? = state.withLockUnchecked {
                $0.calls.append(.fileSizeInBytes(fileURL: fileURL))
                return $0.mockFileSizeInBytes
            }
            return stub(fileURL)
        }

        public func getFileSizeDescription(for fileURL: URL) -> String? {
            let stub: (URL) -> String? = state.withLockUnchecked {
                $0.calls.append(.getFileSizeDescriptionFor(fileURL: fileURL))
                return $0.mockGetFileSizeDescriptionFor
            }
            return stub(fileURL)
        }

        public func getFileSizeDescription(from fileSize: Int64) -> String {
            let stub: (Int64) -> String = state.withLockUnchecked {
                $0.calls.append(.getFileSizeDescriptionFrom(fileSize: fileSize))
                return $0.mockGetFileSizeDescriptionFrom
            }
            return stub(fileSize)
        }

        public func getTemporaryFileName() -> String {
            let stub: () -> String = state.withLockUnchecked {
                $0.calls.append(.getTemporaryFileName)
                return $0.mockGetTemporaryFileName
            }
            return stub()
        }

        public func getTemporarySendableFileName(base: String) -> String {
            let stub: (String) -> String = state.withLockUnchecked {
                $0.calls.append(.getTemporarySendableFileNameBase(base: base))
                return $0.mockGetTemporarySendableFileNameBase
            }
            return stub(base)
        }

        public func getTemporarySendableFileName(
            base: String,
            directoryURL: URL,
            pathExtension: String?
        ) -> String {
            let stub: (String, URL, String?) -> String = state.withLockUnchecked {
                $0.calls.append(
                    .getTemporarySendableFileName(base: base, directoryURL: directoryURL, pathExtension: pathExtension)
                )
                return $0.mockGetTemporarySendableFileName
            }
            return stub(base, directoryURL, pathExtension)
        }

        public func getUniqueFilename(
            from filename: String,
            directoryURL: URL,
            pathExtension: String?
        ) -> String {
            let stub: (String, URL, String?) -> String = state.withLockUnchecked {
                $0.calls.append(
                    .getUniqueFilename(filename: filename, directoryURL: directoryURL, pathExtension: pathExtension)
                )
                return $0.mockGetUniqueFilename
            }
            return stub(filename, directoryURL, pathExtension)
        }

        public func fileExists(at fileURL: URL?) -> Bool {
            let stub: (URL?) -> Bool = state.withLockUnchecked {
                $0.calls.append(.fileExistsAtURL(fileURL))
                return $0.mockFileExistsAtURL
            }
            return stub(fileURL)
        }

        public func fileExists(atPath path: String) -> Bool {
            let stub: (String) -> Bool = state.withLockUnchecked {
                $0.calls.append(.fileExistsAtPath(path))
                return $0.mockFileExistsAtPath
            }
            return stub(path)
        }

        public func createEmptyFile(atURL url: URL) throws {
            let stub: (URL) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.createEmptyFile(url: url))
                return $0.mockCreateEmptyFile
            }
            try stub(url)
        }

        public func createFile(
            atPath path: String,
            contents data: Data?,
            attributes attr: [FileAttributeKey: Any]?
        ) -> Bool {
            let stub: (String, Data?, [FileAttributeKey: Any]?) -> Bool = state.withLockUnchecked {
                $0.calls.append(.createFile(path: path, contents: data))
                return $0.mockCreateFile
            }
            return stub(path, data, attr)
        }

        public func createFileHandle(forReadingFromURL url: URL) throws -> FileHandle {
            let stub: (URL) throws -> FileHandle = state.withLockUnchecked {
                $0.calls.append(.createFileHandleForReading(url: url))
                return $0.mockCreateFileHandleForReading
            }
            return try stub(url)
        }

        public func createFileHandle(forWritingToURL url: URL) throws -> FileHandle {
            let stub: (URL) throws -> FileHandle = state.withLockUnchecked {
                $0.calls.append(.createFileHandleForWriting(url: url))
                return $0.mockCreateFileHandleForWriting
            }
            return try stub(url)
        }

        public func closeFileHandle(_ fileHandle: FileHandle) throws {
            let stub: (FileHandle) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.closeFileHandle)
                return $0.mockCloseFileHandle
            }
            try stub(fileHandle)
        }

        public func mkDir(
            at url: URL,
            withIntermediateDirectories createIntermediates: Bool,
            attributes: [FileAttributeKey: Any]?
        ) throws {
            let stub: (URL, Bool, [FileAttributeKey: Any]?) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.mkDirAtURL(url: url, withIntermediateDirectories: createIntermediates))
                return $0.mockMkDirAtURL
            }
            try stub(url, createIntermediates, attributes)
        }

        public func mkDir(
            atPath path: String,
            withIntermediateDirectories createIntermediates: Bool,
            attributes: [FileAttributeKey: Any]?
        ) throws {
            let stub: (String, Bool, [FileAttributeKey: Any]?) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.mkDirAtPath(path: path, withIntermediateDirectories: createIntermediates))
                return $0.mockMkDirAtPath
            }
            try stub(path, createIntermediates, attributes)
        }

        public func dir(at sourceURL: URL?) -> [URL]? {
            let stub: (URL?) -> [URL]? = state.withLockUnchecked {
                $0.calls.append(.dir(at: sourceURL))
                return $0.mockDir
            }
            return stub(sourceURL)
        }

        public func enumerator(atPath path: String) -> FileManager.DirectoryEnumerator? {
            let stub: (String) -> FileManager.DirectoryEnumerator? = state.withLockUnchecked {
                $0.calls.append(.enumerator(atPath: path))
                return $0.mockEnumerator
            }
            return stub(path)
        }

        public func copy(from sourceURL: URL, to destinationURL: URL) throws {
            let stub: (URL, URL) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.copy(from: sourceURL, to: destinationURL))
                return $0.mockCopy
            }
            try stub(sourceURL, destinationURL)
        }

        public func move(from sourceURL: URL, to destinationURL: URL) throws {
            let stub: (URL, URL) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.moveURL(from: sourceURL, to: destinationURL))
                return $0.mockMoveURL
            }
            try stub(sourceURL, destinationURL)
        }

        public func move(fromPath srcPath: String, toPath dstPath: String) throws {
            let stub: (String, String) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.movePath(fromPath: srcPath, toPath: dstPath))
                return $0.mockMovePath
            }
            try stub(srcPath, dstPath)
        }

        public func mergeContentsOfPath(from sourceURL: URL, to destinationURL: URL) throws {
            let stub: (URL, URL) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.mergeContentsOfPath(from: sourceURL, to: destinationURL))
                return $0.mockMergeContentsOfPath
            }
            try stub(sourceURL, destinationURL)
        }

        public func replaceFile(from sourceURL: URL, to destinationURL: URL) throws {
            let stub: (URL, URL) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.replaceFile(from: sourceURL, to: destinationURL))
                return $0.mockReplaceFile
            }
            try stub(sourceURL, destinationURL)
        }

        public func delete(at sourceURL: URL) throws {
            let stub: (URL) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.deleteAtURL(sourceURL))
                return $0.mockDeleteAtURL
            }
            try stub(sourceURL)
        }

        public func deleteIfExists(at sourceURL: URL?) {
            let stub: (URL?) -> Void = state.withLockUnchecked {
                $0.calls.append(.deleteIfExists(sourceURL))
                return $0.mockDeleteIfExists
            }
            stub(sourceURL)
        }

        public func isDeletableFile(atPath path: String) -> Bool {
            let stub: (String) -> Bool = state.withLockUnchecked {
                $0.calls.append(.isDeletableFile(atPath: path))
                return $0.mockIsDeletableFile
            }
            return stub(path)
        }

        public func delete(atPath path: String) throws {
            let stub: (String) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.deleteAtPath(path))
                return $0.mockDeleteAtPath
            }
            try stub(path)
        }

        public func removeItemsInAllDirectories(appGroupID: String) {
            let stub: (String) -> Void = state.withLockUnchecked {
                $0.calls.append(.removeItemsInAllDirectories(appGroupID: appGroupID))
                return $0.mockRemoveItemsInAllDirectories
            }
            stub(appGroupID)
        }

        public func removeItemsInDirectory(directoryURL: URL) {
            let stub: (URL) -> Void = state.withLockUnchecked {
                $0.calls.append(.removeItemsInDirectory(directoryURL: directoryURL))
                return $0.mockRemoveItemsInDirectory
            }
            stub(directoryURL)
        }

        public func cleanTemporaryDirectory(olderThan: Date?) {
            let stub: (Date?) -> Void = state.withLockUnchecked {
                $0.calls.append(.cleanTemporaryDirectory(olderThan: olderThan))
                return $0.mockCleanTemporaryDirectory
            }
            stub(olderThan)
        }

        public func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey: Any] {
            let stub: (String) throws -> [FileAttributeKey: Any] = state.withLockUnchecked {
                $0.calls.append(.attributesOfFileSystem(forPath: path))
                return $0.mockAttributesOfFileSystem
            }
            return try stub(path)
        }

        public func contentsOfDirectory(atPath path: String) throws -> [String] {
            let stub: (String) throws -> [String] = state.withLockUnchecked {
                $0.calls.append(.contentsOfDirectoryAtPath(path))
                return $0.mockContentsOfDirectoryAtPath
            }
            return try stub(path)
        }

        public func contentsOfDirectory(
            at url: URL,
            includingPropertiesForKeys keys: [URLResourceKey]?,
            options mask: FileManager.DirectoryEnumerationOptions
        ) throws -> [URL] {
            let stub: (URL, [URLResourceKey]?, FileManager.DirectoryEnumerationOptions) throws -> [URL] = state.withLockUnchecked {
                $0.calls.append(.contentsOfDirectoryAtURL(url, keys: keys, options: mask))
                return $0.mockContentsOfDirectoryAtURL
            }
            return try stub(url, keys, mask)
        }

        public func read(fileURL: URL?) -> Data? {
            let stub: (URL?) -> Data? = state.withLockUnchecked {
                $0.calls.append(.readFileURL(fileURL))
                return $0.mockReadFileURL
            }
            return stub(fileURL)
        }

        public func read(offset: UInt64?, length: UInt64?, from fileHandle: FileHandle, fileURL: URL) throws -> Data {
            let stub: (UInt64?, UInt64?, FileHandle, URL) throws -> Data = state.withLockUnchecked {
                $0.calls.append(.readFromHandle(offset: offset, length: length, fileURL: fileURL))
                return $0.mockReadFromHandle
            }
            return try stub(offset, length, fileHandle, fileURL)
        }

        public func write(contents: Data, offset: UInt64?, to fileHandle: FileHandle, fileURL: URL) throws {
            let stub: (Data, UInt64?, FileHandle, URL) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.writeToHandle(contents: contents, offset: offset, fileURL: fileURL))
                return $0.mockWriteToHandle
            }
            try stub(contents, offset, fileHandle, fileURL)
        }

        @discardableResult
        public func write(contents: Data?, to fileURL: URL?) -> Bool {
            let stub: (Data?, URL?) -> Bool = state.withLockUnchecked {
                $0.calls.append(.writeToURL(contents: contents, fileURL: fileURL))
                return $0.mockWriteToURL
            }
            return stub(contents, fileURL)
        }

        public func logDirectoriesAndFiles(pathURL: URL) {
            let stub: (URL) -> Void = state.withLockUnchecked {
                $0.calls.append(.logDirectoriesAndFiles(pathURL: pathURL))
                return $0.mockLogDirectoriesAndFiles
            }
            stub(pathURL)
        }

        public func updateProtectionFormCompleteToCompleteUntilFirstUserAuthentication(at directoryURL: URL) {
            let stub: (URL) -> Void = state.withLockUnchecked {
                $0.calls.append(.updateProtection(at: directoryURL))
                return $0.mockUpdateProtection
            }
            stub(directoryURL)
        }

        public func backup(of namePrefixes: [String], exclude: Bool, appGroupID: String) throws {
            let stub: ([String], Bool, String) throws -> Void = state.withLockUnchecked {
                $0.calls.append(.backup(namePrefixes: namePrefixes, exclude: exclude, appGroupID: appGroupID))
                return $0.mockBackup
            }
            try stub(namePrefixes, exclude, appGroupID)
        }

        // MARK: - Inspection

        public var calls: [Call] {
            state.withLockUnchecked { $0.calls }
        }

        // MARK: - Stubs (override per test)

        public var mockAppDataDirectory: (String) -> URL? {
            get { state.withLockUnchecked { $0.mockAppDataDirectory } }
            set { state.withLockUnchecked { $0.mockAppDataDirectory = newValue } }
        }

        public var mockFreeDiskSpaceInBytes: () -> Int64 {
            get { state.withLockUnchecked { $0.mockFreeDiskSpaceInBytes } }
            set { state.withLockUnchecked { $0.mockFreeDiskSpaceInBytes = newValue } }
        }

        public var mockPathSizeInBytes: (URL, inout Int64) -> Void {
            get { state.withLockUnchecked { $0.mockPathSizeInBytes } }
            set { state.withLockUnchecked { $0.mockPathSizeInBytes = newValue } }
        }

        public var mockFileSizeInBytes: (URL) -> Int64? {
            get { state.withLockUnchecked { $0.mockFileSizeInBytes } }
            set { state.withLockUnchecked { $0.mockFileSizeInBytes = newValue } }
        }

        public var mockGetFileSizeDescriptionFor: (URL) -> String? {
            get { state.withLockUnchecked { $0.mockGetFileSizeDescriptionFor } }
            set { state.withLockUnchecked { $0.mockGetFileSizeDescriptionFor = newValue } }
        }

        public var mockGetFileSizeDescriptionFrom: (Int64) -> String {
            get { state.withLockUnchecked { $0.mockGetFileSizeDescriptionFrom } }
            set { state.withLockUnchecked { $0.mockGetFileSizeDescriptionFrom = newValue } }
        }

        public var mockGetTemporaryFileName: () -> String {
            get { state.withLockUnchecked { $0.mockGetTemporaryFileName } }
            set { state.withLockUnchecked { $0.mockGetTemporaryFileName = newValue } }
        }

        public var mockGetTemporarySendableFileNameBase: (String) -> String {
            get { state.withLockUnchecked { $0.mockGetTemporarySendableFileNameBase } }
            set { state.withLockUnchecked { $0.mockGetTemporarySendableFileNameBase = newValue } }
        }

        public var mockGetTemporarySendableFileName: (String, URL, String?) -> String {
            get { state.withLockUnchecked { $0.mockGetTemporarySendableFileName } }
            set { state.withLockUnchecked { $0.mockGetTemporarySendableFileName = newValue } }
        }

        public var mockGetUniqueFilename: (String, URL, String?) -> String {
            get { state.withLockUnchecked { $0.mockGetUniqueFilename } }
            set { state.withLockUnchecked { $0.mockGetUniqueFilename = newValue } }
        }

        public var mockFileExistsAtURL: (URL?) -> Bool {
            get { state.withLockUnchecked { $0.mockFileExistsAtURL } }
            set { state.withLockUnchecked { $0.mockFileExistsAtURL = newValue } }
        }

        public var mockFileExistsAtPath: (String) -> Bool {
            get { state.withLockUnchecked { $0.mockFileExistsAtPath } }
            set { state.withLockUnchecked { $0.mockFileExistsAtPath = newValue } }
        }

        public var mockCreateEmptyFile: (URL) throws -> Void {
            get { state.withLockUnchecked { $0.mockCreateEmptyFile } }
            set { state.withLockUnchecked { $0.mockCreateEmptyFile = newValue } }
        }

        public var mockCreateFile: (String, Data?, [FileAttributeKey: Any]?) -> Bool {
            get { state.withLockUnchecked { $0.mockCreateFile } }
            set { state.withLockUnchecked { $0.mockCreateFile = newValue } }
        }

        public var mockCreateFileHandleForReading: (URL) throws -> FileHandle {
            get { state.withLockUnchecked { $0.mockCreateFileHandleForReading } }
            set { state.withLockUnchecked { $0.mockCreateFileHandleForReading = newValue } }
        }

        public var mockCreateFileHandleForWriting: (URL) throws -> FileHandle {
            get { state.withLockUnchecked { $0.mockCreateFileHandleForWriting } }
            set { state.withLockUnchecked { $0.mockCreateFileHandleForWriting = newValue } }
        }

        public var mockCloseFileHandle: (FileHandle) throws -> Void {
            get { state.withLockUnchecked { $0.mockCloseFileHandle } }
            set { state.withLockUnchecked { $0.mockCloseFileHandle = newValue } }
        }

        public var mockMkDirAtURL: (URL, Bool, [FileAttributeKey: Any]?) throws -> Void {
            get { state.withLockUnchecked { $0.mockMkDirAtURL } }
            set { state.withLockUnchecked { $0.mockMkDirAtURL = newValue } }
        }

        public var mockMkDirAtPath: (String, Bool, [FileAttributeKey: Any]?) throws -> Void {
            get { state.withLockUnchecked { $0.mockMkDirAtPath } }
            set { state.withLockUnchecked { $0.mockMkDirAtPath = newValue } }
        }

        public var mockDir: (URL?) -> [URL]? {
            get { state.withLockUnchecked { $0.mockDir } }
            set { state.withLockUnchecked { $0.mockDir = newValue } }
        }

        public var mockEnumerator: (String) -> FileManager.DirectoryEnumerator? {
            get { state.withLockUnchecked { $0.mockEnumerator } }
            set { state.withLockUnchecked { $0.mockEnumerator = newValue } }
        }

        public var mockCopy: (URL, URL) throws -> Void {
            get { state.withLockUnchecked { $0.mockCopy } }
            set { state.withLockUnchecked { $0.mockCopy = newValue } }
        }

        public var mockMoveURL: (URL, URL) throws -> Void {
            get { state.withLockUnchecked { $0.mockMoveURL } }
            set { state.withLockUnchecked { $0.mockMoveURL = newValue } }
        }

        public var mockMovePath: (String, String) throws -> Void {
            get { state.withLockUnchecked { $0.mockMovePath } }
            set { state.withLockUnchecked { $0.mockMovePath = newValue } }
        }

        public var mockMergeContentsOfPath: (URL, URL) throws -> Void {
            get { state.withLockUnchecked { $0.mockMergeContentsOfPath } }
            set { state.withLockUnchecked { $0.mockMergeContentsOfPath = newValue } }
        }

        public var mockReplaceFile: (URL, URL) throws -> Void {
            get { state.withLockUnchecked { $0.mockReplaceFile } }
            set { state.withLockUnchecked { $0.mockReplaceFile = newValue } }
        }

        public var mockDeleteAtURL: (URL) throws -> Void {
            get { state.withLockUnchecked { $0.mockDeleteAtURL } }
            set { state.withLockUnchecked { $0.mockDeleteAtURL = newValue } }
        }

        public var mockDeleteIfExists: (URL?) -> Void {
            get { state.withLockUnchecked { $0.mockDeleteIfExists } }
            set { state.withLockUnchecked { $0.mockDeleteIfExists = newValue } }
        }

        public var mockIsDeletableFile: (String) -> Bool {
            get { state.withLockUnchecked { $0.mockIsDeletableFile } }
            set { state.withLockUnchecked { $0.mockIsDeletableFile = newValue } }
        }

        public var mockDeleteAtPath: (String) throws -> Void {
            get { state.withLockUnchecked { $0.mockDeleteAtPath } }
            set { state.withLockUnchecked { $0.mockDeleteAtPath = newValue } }
        }

        public var mockRemoveItemsInAllDirectories: (String) -> Void {
            get { state.withLockUnchecked { $0.mockRemoveItemsInAllDirectories } }
            set { state.withLockUnchecked { $0.mockRemoveItemsInAllDirectories = newValue } }
        }

        public var mockRemoveItemsInDirectory: (URL) -> Void {
            get { state.withLockUnchecked { $0.mockRemoveItemsInDirectory } }
            set { state.withLockUnchecked { $0.mockRemoveItemsInDirectory = newValue } }
        }

        public var mockCleanTemporaryDirectory: (Date?) -> Void {
            get { state.withLockUnchecked { $0.mockCleanTemporaryDirectory } }
            set { state.withLockUnchecked { $0.mockCleanTemporaryDirectory = newValue } }
        }

        public var mockAttributesOfFileSystem: (String) throws -> [FileAttributeKey: Any] {
            get { state.withLockUnchecked { $0.mockAttributesOfFileSystem } }
            set { state.withLockUnchecked { $0.mockAttributesOfFileSystem = newValue } }
        }

        public var mockContentsOfDirectoryAtPath: (String) throws -> [String] {
            get { state.withLockUnchecked { $0.mockContentsOfDirectoryAtPath } }
            set { state.withLockUnchecked { $0.mockContentsOfDirectoryAtPath = newValue } }
        }

        public var mockContentsOfDirectoryAtURL: (URL, [URLResourceKey]?, FileManager.DirectoryEnumerationOptions) throws -> [
            URL
        ] {
            get { state.withLockUnchecked { $0.mockContentsOfDirectoryAtURL } }
            set { state.withLockUnchecked { $0.mockContentsOfDirectoryAtURL = newValue } }
        }

        public var mockReadFileURL: (URL?) -> Data? {
            get { state.withLockUnchecked { $0.mockReadFileURL } }
            set { state.withLockUnchecked { $0.mockReadFileURL = newValue } }
        }

        public var mockReadFromHandle: (UInt64?, UInt64?, FileHandle, URL) throws -> Data {
            get { state.withLockUnchecked { $0.mockReadFromHandle } }
            set { state.withLockUnchecked { $0.mockReadFromHandle = newValue } }
        }

        public var mockWriteToHandle: (Data, UInt64?, FileHandle, URL) throws -> Void {
            get { state.withLockUnchecked { $0.mockWriteToHandle } }
            set { state.withLockUnchecked { $0.mockWriteToHandle = newValue } }
        }

        public var mockWriteToURL: (Data?, URL?) -> Bool {
            get { state.withLockUnchecked { $0.mockWriteToURL } }
            set { state.withLockUnchecked { $0.mockWriteToURL = newValue } }
        }

        public var mockLogDirectoriesAndFiles: (URL) -> Void {
            get { state.withLockUnchecked { $0.mockLogDirectoriesAndFiles } }
            set { state.withLockUnchecked { $0.mockLogDirectoriesAndFiles = newValue } }
        }

        public var mockUpdateProtection: (URL) -> Void {
            get { state.withLockUnchecked { $0.mockUpdateProtection } }
            set { state.withLockUnchecked { $0.mockUpdateProtection = newValue } }
        }

        public var mockBackup: ([String], Bool, String) throws -> Void {
            get { state.withLockUnchecked { $0.mockBackup } }
            set { state.withLockUnchecked { $0.mockBackup = newValue } }
        }

        public func reset() {
            state.withLockUnchecked { $0.calls.removeAll() }
        }
    }

    public enum PreviewFileUtilityMockError: Error {
        case closeFileHandleFailed
        case createEmptyFileFailed
        case createReadFileHandleFailed
        case createWriteFileHandleFailed
        case deleteAtURLFailed
        case writeFailed
    }

    extension FileUtilityProtocol where Self == PreviewFileUtilityMock {
        public static var mock: Self {
            PreviewFileUtilityMock()
        }

        public static var failingOnRead: Self {
            let instance = PreviewFileUtilityMock()
            instance.mockReadFromHandle = { _, _, _, _ in
                throw FileUtilityError.readFailed
            }
            return instance
        }

        public static var failingToOpenForReading: Self {
            let instance = PreviewFileUtilityMock()
            instance.mockCreateFileHandleForReading = { _ in
                throw PreviewFileUtilityMockError.createReadFileHandleFailed
            }
            return instance
        }

        public static var failingToOpenForWriting: Self {
            let instance = PreviewFileUtilityMock()
            instance.mockCreateFileHandleForWriting = { _ in
                throw PreviewFileUtilityMockError.createWriteFileHandleFailed
            }
            return instance
        }

        public static var failingOnClose: Self {
            let instance = PreviewFileUtilityMock()
            instance.mockCloseFileHandle = { _ in
                throw PreviewFileUtilityMockError.closeFileHandleFailed
            }
            return instance
        }
    }
#endif
