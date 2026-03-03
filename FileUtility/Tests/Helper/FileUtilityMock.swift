//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import FileUtility
import Foundation

public final class FileUtilityMock: FileUtilityProtocol {
    public var content = [URL]()

    public var isExistsCalledWithFileURL = [URL]()
    public var dirCalledWithSourceURL = [URL]()
    public var deleteCalledWithSourceURL = [URL]()
    public var deleteIfExistsCalledWithSourceURL = [URL]()
    public var copyCalledWithFromTo = [(URL, URL)]()
    public var moveCalledWithFromTo = [(URL, URL)]()
    public var mergeContentsOfPathCalledWithFromTo = [(URL, URL)]()

    public init(content: [URL] = [URL]()) {
        self.content = content
    }

    // MARK: FileUtilityProtocol

    public var appDataDirectory: URL?
    public var appDocumentsDirectory: URL?
    public var appCachesDirectory: URL?
    public var appTemporaryDirectory: URL {
        URL(filePath: "/tmp")!
    }

    public var appTemporaryUnencryptedDirectory: URL {
        appTemporaryDirectory.appendingPathComponent("unencrypted")
    }
    
    public func appDataDirectory(appGroupID: String) -> URL? {
        appDataDirectory
    }
    
    // MARK: Disk space and calculation sizes of resources

    public func freeDiskSpaceInBytes() -> Int64 {
        0
    }

    public func pathSizeInBytes(pathURL: URL, size: inout Int64) {
        size = 0
    }

    public func fileSizeInBytes(fileURL: URL) -> Int64? {
        nil
    }

    public func getFileSizeDescription(for fileURL: URL) -> String? {
        nil
    }

    public func getFileSizeDescription(from fileSize: Int64) -> String {
        "0 MB"
    }

    // MARK: Generate file names

    public func getTemporaryFileName() -> String {
        "temporary-file"
    }

    public func getTemporarySendableFileName(base: String) -> String {
        "\(base)-temporary-file"
    }

    public func getTemporarySendableFileName(base: String, directoryURL: URL, pathExtension: String? = nil) -> String {
        "\(base)-\(UUID().uuidString)"
    }

    public func getUniqueFilename(
        from filename: String,
        directoryURL: URL,
        pathExtension: String? = nil
    ) -> String {
        "\(filename)-\(UUID().uuidString)"
    }

    // MARK: Directory and file operations

    public func fileExists(at fileURL: URL?) -> Bool {
        if let fileURL {
            isExistsCalledWithFileURL.append(fileURL)
            return content.contains(fileURL)
        }
        return false
    }
    
    public func createFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey: Any]?
    ) -> Bool {
        false
    }
    
    public func mkDir(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
        // no-op
    }
    
    public func mkDir(
        atPath path: String,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws {
        // no-op
    }
    
    public func dir(at sourceURL: URL?) -> [URL]? {
        if let sourceURL {
            dirCalledWithSourceURL.append(sourceURL)
        }
        return nil
    }

    public func enumerator(atPath path: String) -> FileManager.DirectoryEnumerator? {
        nil
    }

    public func copy(from sourceURL: URL, to destinationURL: URL) throws {
        copyCalledWithFromTo.append((sourceURL, destinationURL))
    }

    public func move(from sourceURL: URL, to destinationURL: URL) throws {
        moveCalledWithFromTo.append((sourceURL, destinationURL))
    }

    public func mergeContentsOfPath(from sourceURL: URL, to destinationURL: URL) throws {
        mergeContentsOfPathCalledWithFromTo.append((sourceURL, destinationURL))
    }

    public func replaceFile(from sourceURL: URL, to destinationURL: URL) throws {
        // no-op
    }

    public func delete(at sourceURL: URL) throws {
        deleteCalledWithSourceURL.append(sourceURL)
    }

    public func deleteIfExists(at sourceURL: URL?) {
        if let sourceURL {
            deleteIfExistsCalledWithSourceURL.append(sourceURL)
        }
    }

    public func removeItemsInAllDirectories(appGroupID: String) {
        // no-op
    }

    public func removeItemsInDirectory(directoryURL: URL) {
        // no-op
    }

    public func cleanTemporaryDirectory(olderThan: Date?) {
        // no-op
    }

    // MARK: Read and write file

    public func read(fileURL: URL?) -> Data? {
        nil
    }

    public func write(contents: Data?, to fileURL: URL?) -> Bool {
        true
    }

    public func write(text: String, to fileURL: URL?) -> Bool {
        true
    }

    public func logDirectoriesAndFiles(pathURL: URL) {
        // no-op
    }
    
    // MARK: Update file attributes

    public func updateProtectionFormCompleteToCompleteUntilFirstUserAuthentication(at directoryURL: URL) {
        // no-op
    }

    public func backup(of namePrefixes: [String], exclude: Bool, appGroupID: String) throws {
        // no-op
    }
    
    public func fileExists(atPath path: String) -> Bool {
        false
    }
    
    public func move(fromPath srcPath: String, toPath dstPath: String) throws {
        // no-op
    }
    
    public func isDeletableFile(atPath path: String) -> Bool {
        false
    }
    
    public func delete(atPath path: String) throws {
        // no-op
    }
    
    public func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey: Any] {
        [:]
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [String] {
        []
    }
}
