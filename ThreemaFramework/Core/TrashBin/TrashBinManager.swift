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
import FileUtility

public final class TrashBinManager: TrashBinManagerProtocol {
    private let fileUtility: FileUtilityProtocol

    public init(fileUtility: FileUtilityProtocol) {
        self.fileUtility = fileUtility
    }

    // MARK: - TrashBinManagerProtocol

    public func getTrashBinFilesData() -> (files: [String], size: Int64) {
        var binSize: Int64 = 0

        if let binFolderURL {
            fileUtility.pathSizeInBytes(pathURL: binFolderURL, size: &binSize)
        }

        if fileUtility.fileExists(at: binFolderURL),
           let files = fileUtility.dir(at: binFolderURL) {
            let paths = files.map(\.path)
            return (paths, binSize)
        }
        else {
            return ([], 0)
        }
    }

    public func moveToTrashBin(_ files: [String]) {
        guard
            let binFolderURL,
            let databaseExternalStorageURL
        else {
            DDLogError("Bin folder or database storage URL couldn't be retrieved.")
            return
        }

        if !fileUtility.fileExists(at: binFolderURL) {
            let success: Bool
            
            do {
                try fileUtility.mkDir(
                    at: binFolderURL,
                    withIntermediateDirectories: false,
                    attributes: nil
                )
                success = true
            }
            catch {
                success = false
            }
            
            if !success {
                DDLogError("Bin folder couldn't be created at the system storage.")
                return
            }
        }

        for file in files {
            let sourceURL = databaseExternalStorageURL.appendingPathComponent(file)
            let destinationURL = binFolderURL.appendingPathComponent(file)
            
            do {
                try fileUtility.move(from: sourceURL, to: destinationURL)
            }
            catch {
                DDLogError("Source file [\(sourceURL.absoluteString)] couldn't be moved to Bin.")
            }
        }
    }

    public func restoreTrashBin() {
        guard
            let binFolderURL,
            let databaseExternalStorageURL
        else {
            DDLogError("Bin folder or database storage URL couldn't be retrieved.")
            return
        }

        let fileURLs = fileUtility.dir(at: binFolderURL) ?? []

        for fileURL in fileURLs {
            let sourceURL = binFolderURL.appendingPathComponent(fileURL.lastPathComponent)
            let destinationURL = databaseExternalStorageURL.appendingPathComponent(fileURL.lastPathComponent)
            
            do {
                try fileUtility.move(from: sourceURL, to: destinationURL)
            }
            catch {
                DDLogError("Trash bin file [\(fileURL.absoluteString)] couldn't be restored.")
            }
        }

        if let folder = fileUtility.dir(at: binFolderURL), folder.isEmpty {
            fileUtility.deleteIfExists(at: binFolderURL)
        }
    }

    public func emptyTrashBin() {
        guard let binFolderURL
        else {
            DDLogError("Bin folder URL couldn't be retrieved.")
            return
        }
        fileUtility.deleteIfExists(at: binFolderURL)
    }

    // MARK: - Helpers

    private var appDataDirectoryURL: URL? {
        fileUtility.appDataDirectory(appGroupID: AppGroup.groupID())
    }

    private var binFolderURL: URL? {
        appDataDirectoryURL?.appendingPathComponent(EntityDestroyer.externalDataBinPath)
    }

    private var databaseExternalStorageURL: URL? {
        appDataDirectoryURL?.appendingPathComponent(DatabaseManager.databaseExternalStoragePath)
    }
}
