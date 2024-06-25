//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

public protocol FileUtilityProtocol: AnyObject {
    static var shared: Self { get }
    
    /// Returns the URL to the application's data directory.
    var appDataDirectory: URL? { get }
    
    /// Returns the URL to the application's documents directory.
    var appDocumentsDirectory: URL? { get }
    
    /// Returns the URL to the application's caches directory.
    var appCachesDirectory: URL? { get }
    
    /// Returns the URL to the application's temporary directory.
    var appTemporaryDirectory: URL { get }
    
    /// Create directory, but no intermediate directories.
    /// - Parameter at: The URL at which to create the directory.
    /// - Returns: A Boolean value indicating whether the directory was successfully created.
    func mkDir(at: URL) -> Bool
    
    /// Retrieves the contents of the directory at the specified URL.
    /// - Parameter pathURL: The URL of the directory to retrieve contents from.
    /// - Returns: An array of strings representing the names of items in the directory, or nil if an error occurred.
    func dir(pathURL: URL?) -> [String]?
    
    /// Logs the directories and files at the specified path to a file.
    /// - Parameters:
    ///   - path: The URL of the directory to log.
    ///   - logFileName: The name of the file to write the log to, or nil for debug_log.txt
    func logDirectoriesAndFiles(path: URL, logFileName: String?)
    
    /// Cleans the temporary directory by removing files older than the specified date.
    /// - Parameter olderThan: The date to compare file modification dates against, or nil to clean all files.
    func cleanTemporaryDirectory(olderThan: Date?)
    
    /// Removes all items in all directories managed by the file utility.
    func removeItemsInAllDirectories()
    
    /// Remove all items in a directory
    /// - Parameter directoryURL: URL of the directory
    func removeItemsInDirectory(directoryURL: URL)
    
    /// Writes data to the file at the specified URL.
    /// - Parameters:
    ///   - fileURL: The URL of the file to write to.
    ///   - contents: The data to write to the file.
    /// - Returns: A Boolean value indicating whether the write operation was successful.
    func write(fileURL: URL?, contents: Data?) -> Bool
    
    /// Writes text to the file at the specified URL.
    /// - Parameters:
    ///   - fileURL: The URL of the file to write to.
    ///   - text: The text to write to the file.
    /// - Returns: A Boolean value indicating whether the write operation was successful.
    func write(fileURL: URL?, text: String) -> Bool
    
    /// Reads and returns the data from the file at the specified URL.
    /// - Parameter fileURL: The URL of the file to read from.
    /// - Returns: The data read from the file, or nil if an error occurred.
    func read(fileURL: URL?) -> Data?
    
    /// Copies a file from a source URL to a destination URL.
    /// - Parameters:
    ///   - source: The source URL of the file to copy.
    ///   - destination: The destination URL where the file should be copied to.
    /// - Returns: A Boolean value indicating whether the copy operation was successful.
    func copy(source: URL, destination: URL) -> Bool
    
    /// Moves a file from a source URL to a destination URL.
    /// - Parameters:
    ///   - source: The source URL of the file to move.
    ///   - destination: The destination URL where the file should be moved to.
    /// - Returns: A Boolean value indicating whether the move operation was successful.
    func move(source: URL, destination: URL) -> Bool
    
    /// Deletes the file at the specified URL.
    /// - Parameter at: The URL of the file to delete.
    func delete(at: URL?)
    
    /// Checks whether a file exists at the specified URL.
    /// - Parameter fileURL: The URL of the file to check.
    /// - Returns: A Boolean value indicating whether the file exists.
    func isExists(fileURL: URL?) -> Bool
    
    /// Appends text to the file at the specified URL.
    /// - Parameters:
    ///   - fileURL: The URL of the file to append to.
    ///   - text: The text to append to the file.
    /// - Returns: A Boolean value indicating whether the append operation was successful.
    func append(fileURL: URL?, text: String) -> Bool
    
    /// Retrieves the size of the file at the specified URL in bytes.
    /// - Parameter fileURL: The URL of the file to check.
    /// - Returns: The size of the file in bytes, or nil if an error occurred.
    func fileSizeInBytes(fileURL: URL) -> Int64?
    
    /// Retrieves a human-readable description of the file size for the file at the specified URL.
    /// - Parameter fileURL: The URL of the file to describe.
    /// - Returns: A string describing the file size, or nil if an error occurred.
    func getFileSizeDescription(for fileURL: URL) -> String?
    
    /// Generates a temporary file name.
    /// - Returns: A string representing a unique temporary file name.
    func getTemporaryFileName() -> String
    
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
}

extension FileUtilityProtocol {
    
    public func write(fileURL: URL?, text: String) -> Bool {
        guard let fileURL else {
            return false
        }
        
        return write(fileURL: fileURL, contents: Data(text.utf8))
    }
    
    public func removeItemsInDirectory(directoryURL: URL) {
        if let items = dir(pathURL: directoryURL) {
            items
                .map { URL(fileURLWithPath: "\(directoryURL.path)/\($0)") }
                .forEach(delete)
        }
    }
    
    public func removeItemsInAllDirectories() {
        appDocumentsDirectory.map(removeItemsInDirectory)
        appDataDirectory.map(removeItemsInDirectory)
        appCachesDirectory.map(removeItemsInDirectory)
        removeItemsInDirectory(directoryURL: appTemporaryDirectory)
        DDLogNotice("Deleted items in all directories.")
    }
}
