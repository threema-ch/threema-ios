import FileUtility
import Foundation

final class FileUtilityNull: FileUtilityProtocol {
    init() { /* no-op */ }

    var appCachesDirectory: URL? { nil }
    var appDocumentsDirectory: URL? { nil }
    var appTemporaryDirectory: URL { .temporaryDirectory }
    var appTemporaryUnencryptedDirectory: URL { appTemporaryDirectory }

    func appDataDirectory(appGroupID: String) -> URL? { nil }
    func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey: Any] { [:] }
    func backup(of namePrefixes: [String], exclude: Bool, appGroupID: String) throws { /* no-op */ }
    func cleanTemporaryDirectory(olderThan: Date?) { /* no-op */ }
    func contentsOfDirectory(atPath path: String) throws -> [String] { [] }
    func copy(from sourceURL: URL, to destinationURL: URL) throws { /* no-op */ }
    func createFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey: Any]?
    ) -> Bool { false }
    func delete(at sourceURL: URL) throws { /* no-op */ }
    func delete(atPath path: String) throws { /* no-op */ }
    func deleteIfExists(at sourceURL: URL?) { /* no-op */ }
    func dir(at sourceURL: URL?) -> [URL]? { nil }
    func enumerator(atPath path: String) -> FileManager.DirectoryEnumerator? { nil }
    func fileExists(at fileURL: URL?) -> Bool { false }
    func fileExists(atPath path: String) -> Bool { false }
    func fileSizeInBytes(fileURL: URL) -> Int64? { nil }
    func freeDiskSpaceInBytes() -> Int64 { 0 }
    func getFileSizeDescription(for fileURL: URL) -> String? { nil }
    func getFileSizeDescription(from fileSize: Int64) -> String { "" }
    func getTemporaryFileName() -> String { "" }
    func getTemporarySendableFileName(base: String) -> String { "" }
    func getTemporarySendableFileName(base: String, directoryURL: URL, pathExtension: String?) -> String { "" }
    func getUniqueFilename(from filename: String, directoryURL: URL, pathExtension: String?) -> String { "" }
    func isDeletableFile(atPath path: String) -> Bool { false }
    func logDirectoriesAndFiles(pathURL: URL) { /* no-op */ }
    func mergeContentsOfPath(from sourceURL: URL, to destinationURL: URL) throws { /* no-op */ }
    func mkDir(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws { /* no-op */ }
    func mkDir(
        atPath path: String,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws { /* no-op */ }
    func move(from sourceURL: URL, to destinationURL: URL) throws { /* no-op */ }
    func move(fromPath srcPath: String, toPath dstPath: String) throws { /* no-op */ }
    func pathSizeInBytes(pathURL: URL, size: inout Int64) { /* no-op */ }
    func read(fileURL: URL?) -> Data? { nil }
    func removeItemsInAllDirectories(appGroupID: String) { /* no-op */ }
    func removeItemsInDirectory(directoryURL: URL) { /* no-op */ }
    func replaceFile(from sourceURL: URL, to destinationURL: URL) throws { /* no-op */ }
    func updateProtectionFormCompleteToCompleteUntilFirstUserAuthentication(at directoryURL: URL) { /* no-op */ }
    func write(contents: Data?, to fileURL: URL?) -> Bool { false }
}
