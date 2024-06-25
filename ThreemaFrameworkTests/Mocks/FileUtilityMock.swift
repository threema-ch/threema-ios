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

import Foundation
import ThreemaFramework

final class FileUtilityMock: FileUtilityProtocol {
    let fileSystem = SimulatedFileSystem()
    var appDataDirectory: URL? { fileSystem.data }
    var appDocumentsDirectory: URL? { fileSystem.documents }
    var appCachesDirectory: URL? { fileSystem.caches }
    var appTemporaryDirectory: URL { fileSystem.tmp }
    
    @objc public static var shared: Self { Self() }
    
    func mkDir(at: URL) -> Bool {
        fileSystem.createDirectory(at: at.path, withIntermediateDirectories: false)
    }
    
    func dir(pathURL: URL?) -> [String]? {
        guard let pathURL else {
            return nil
        }
        var result: [String] = []
        for (url, content) in fileSystem.files {
            if url.path.hasPrefix(pathURL.path), url.path != pathURL.path {
                result.append(url.lastPathComponent)
            }
        }
        return result
    }
    
    func logDirectoriesAndFiles(path: URL, logFileName: String?) {
        let logPath = appDocumentsDirectory?.appendingPathComponent(logFileName ?? "debug_log.txt")
        var logFiles = ""
        for (url, content) in fileSystem.files.sorted(by: { $0.key.path < $1.key.path }) {
            if url.path.hasPrefix(path.path), url.path != path.path,
               (url.pathComponents.count) == (path.pathComponents.count + 1) {
                let logFile = "\(url.lastPathComponent) \(url.hasDirectoryPath)"
                logFiles += logFile
                print(logFile)
            }
        }
        
        if let logPath {
            _ = write(fileURL: logPath, text: logFiles)
        }
    }
    
    func cleanTemporaryDirectory(olderThan: Date?) {
        for (url, content) in fileSystem.files {
            if url.path.hasPrefix(fileSystem.tmp.path), url.path != fileSystem.tmp.path {
                fileSystem.delete(at: url)
            }
        }
    }
    
    func write(fileURL: URL?, contents: Data?) -> Bool {
        if let fileURL, let contents {
            fileSystem.createFile(at: fileURL, content: contents)
            return true
        }
        
        return false
    }
    
    func read(fileURL: URL?) -> Data? {
        guard let fileURL else {
            return nil
        }
        return fileSystem.files[fileURL] as? Data
    }
    
    func copy(source: URL, destination: URL) -> Bool {
        fileSystem.copy(from: source, to: destination)
    }
    
    func move(source: URL, destination: URL) -> Bool {
        fileSystem.move(from: source, to: destination)
    }
    
    func delete(at url: URL?) {
        url.map(fileSystem.delete)
    }
    
    func isExists(fileURL: URL?) -> Bool {
        guard let fileURL else {
            return false
        }
        
        return fileSystem.fileExists(at: fileURL)
    }
    
    func append(fileURL: URL?, text: String) -> Bool {
        guard
            let fileURL,
            let data = fileSystem.files[fileURL] as? Data,
            var content = String(data: data, encoding: .utf8) else {
            return false
        }
        content.append(text)
        if let newContent = content.data(using: .utf8) {
            fileSystem.files[fileURL] = newContent
            return true
        }
        else {
            return false
        }
    }
    
    func fileSizeInBytes(fileURL: URL) -> Int64? {
        guard let data = fileSystem.files[fileURL] as? Data else {
            return nil
        }
        
        return Int64(data.count)
    }
    
    func getFileSizeDescription(for fileURL: URL) -> String? {
        guard let fileSize = fileSizeInBytes(fileURL: fileURL) else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .binary)
    }
    
    func getTemporaryFileName() -> String {
        var filename = ProcessInfo().globallyUniqueString
        let url = fileSystem.tmp
        var fileURL = url.appendingPathComponent(filename)

        while fileSystem.fileExists(at: fileURL) {
            filename = ProcessInfo().globallyUniqueString
            fileURL = url.appendingPathComponent(filename)
        }
        return filename
    }
    
    func getTemporarySendableFileName(base: String, directoryURL: URL, pathExtension: String?) -> String {
        let filename = base + "-" + DateFormatter.getDateForFilename(Date())
        return getUniqueFilename(from: filename, directoryURL: directoryURL, pathExtension: pathExtension)
    }
    
    func getUniqueFilename(
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
        while fileSystem.fileExists(at: fileURL) {
            newFilename = filename.appending("-\(i)")
            fileURL = directoryURL.appendingPathComponent(newFilename)
            if let pathExtension {
                fileURL = fileURL.appendingPathExtension(pathExtension)
            }
            i += 1
        }
        
        return newFilename
    }
}

// MARK: - FileUtilityMock.SimulatedFileSystem

extension FileUtilityMock {
    class SimulatedFileSystem {
        var files: [URL: Any]

        init() {
            self.files = [:]
            createDirectory(at: root)
            createDirectory(at: tmp)
            createDirectory(at: documents)
            createDirectory(at: caches)
            createDirectory(at: data)
        }

        func createFile(at url: URL, content: Any) { files[url] = content }
        func createFile(at path: String, content: Any) {
            let url = URL(fileURLWithPath: path, isDirectory: false)
            files[url] = content
        }

        func createDirectory(at url: URL) { files[url] = [] }
        func createDirectory(at path: String) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            files[url] = []
        }

        @discardableResult
        func createDirectory(at path: String, withIntermediateDirectories: Bool) -> Bool {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if withIntermediateDirectories {
                files[url] = []
                return true
            }
            else {
                let parent = url.deletingLastPathComponent()
                if fileExists(at: parent) {
                    files[url] = []
                    return true
                }
                else {
                    return false
                }
            }
        }
        
        func delete(at url: URL) { files.removeValue(forKey: url) }
        func fileExists(at url: URL) -> Bool { files.keys.contains(url) }
        func move(from: URL, to: URL) -> Bool {
            guard let content = files.removeValue(forKey: from) else {
                print("No file or directory at \(from.path)")
                return false
            }

            files[to] = content
            return true
        }
        
        func copy(from: URL, to: URL) -> Bool {
            let content = files[from]
            files[to] = content
            return true
        }

        func printFileSystem() {
            for (url, content) in files.sorted(by: { $0.key.path < $1.key.path }) {
                if url.hasDirectoryPath {
                    print("\(url.path) - Directory")
                }
                else {
                    print("\(url.path) - File: Content = \(content)")
                }
            }
        }
        
        let root = URL(fileURLWithPath: "/root", isDirectory: true)
        let tmp = URL(fileURLWithPath: "/root/tmp", isDirectory: true)
        let documents = URL(fileURLWithPath: "/root/documents", isDirectory: true)
        let caches = URL(fileURLWithPath: "/root/caches", isDirectory: true)
        let data = URL(fileURLWithPath: "/root/data", isDirectory: true)
    }
}
