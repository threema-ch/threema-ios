//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import PromiseKit

/// Used to keep track of URLSessionTasks and their progress. Should not be called directly but rather through
/// BlobManager.
class BlobDownloader: NSObject {
    
    enum BlobDownloaderError: Error {
        case downloadFailed(message: String)
        case invalidDownloadURL
    }
    
    private let blobURL: BlobURL
    private let queue: DispatchQueue
    private var urlSessionManager: URLSessionManager
    
    private var progressObservers = [NSManagedObjectID: NSKeyValueObservation]()
    private var activeTasks = [NSManagedObjectID: URLSessionTask]()

    // MARK: - Lifecycle
    
    init(
        blobURL: BlobURL,
        queue: DispatchQueue = DispatchQueue.main,
        sessionManager: URLSessionManager = .shared
    ) {
        self.blobURL = blobURL
        self.queue = queue
        self.urlSessionManager = sessionManager
        super.init()
    }
    
    @objc init(blobURL: BlobURL, queue: DispatchQueue = DispatchQueue.main) {
        self.blobURL = blobURL
        self.queue = queue
        self.urlSessionManager = .shared
        super.init()
    }
    
    // MARK: - Download
    
    /// Downloads given data and provides progress updates to its delegate
    /// - Parameters:
    ///   - blobData: Data to be downloaded
    ///   - origin: Origin of the Blob
    ///   - objectID: ObjectID used to track progress
    ///   - delegate: Delegate to send progress updates to
    /// - Returns: Received data from server
    func download(
        blobID: Data,
        origin: BlobOrigin,
        objectID: NSManagedObjectID,
        delegate: BlobManagerDelegate? = nil
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            
            blobURL.download(blobID: blobID, origin: origin) { downloadURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let downloadURL else {
                    continuation.resume(throwing: BlobDownloaderError.invalidDownloadURL)
                    return
                }

                let task = self.startDownload(for: downloadURL) { data, error in
                    // Download was completed
                    if let error {
                        continuation.resume(throwing: error)
                    }
                    else if let data {
                        continuation.resume(returning: data)
                    }
                    else {
                        continuation
                            .resume(throwing: BlobDownloaderError.downloadFailed(message: "[Blob] No data downloaded"))
                    }
                    
                    // Remove completed Task
                    self.progressObservers.removeValue(forKey: objectID)
                    self.activeTasks.removeValue(forKey: objectID)
                }
                
                // Add created task to keep track
                let observer = task.progress.observe(\.fractionCompleted) { progress, _ in
                    Task {
                        await delegate?.updateProgress(for: objectID, didUpdate: progress)
                    }
                }

                self.progressObservers[objectID] = observer
                self.activeTasks[objectID] = task
            }
        }
    }
 
    @objc func download(blobID: Data, origin: BlobOrigin, completion: @escaping (Data?, Error?) -> Void) {
        blobURL.download(blobID: blobID, origin: origin) { downloadURL, _ in
            guard let downloadURL else {
                completion(nil, BlobDownloaderError.invalidDownloadURL)
                return
            }
            
            self.startDownload(for: downloadURL, completion: completion)
        }
    }

    @objc func markDownloadDone(for blobID: Data, origin: BlobOrigin) {
        blobURL.done(
            blobID: blobID,
            origin: origin
        ) { doneURL, error in
            if let error {
                DDLogError("Marking blob ID \(blobID.hexString) failed: \(error)")
                return
            }

            guard let doneURL else {
                DDLogWarn("Download done URL for blob ID \(blobID.hexString) missing")
                return
            }

            Task {
                let httpClient = HTTPClient(sessionManager: self.urlSessionManager)
                try await httpClient.sendDone(url: doneURL)
            }
        }
    }
    
    @discardableResult
    private func startDownload(for url: URL, completion: @escaping (Data?, Error?) -> Void) -> URLSessionDataTask {
        let httpClient = HTTPClient(sessionManager: urlSessionManager)
        let task = httpClient.downloadData(url: url, contentType: .octetStream) { data, response, error in
            var downloadError: Error?
            
            if let error {
                downloadError = error
            }
            else {
                if response is HTTPURLResponse {
                    if let response = response as? HTTPURLResponse,
                       !(200...299).contains(response.statusCode) {
                        downloadError = BlobDownloaderError
                            .downloadFailed(
                                message: "[BlobDownloader] Download failed with response code: \(response.statusCode)."
                            )
                    }
                }
                else {
                    downloadError = BlobDownloaderError.downloadFailed(message: "[BlobDownloader] Response is missing.")
                }
            }
            self.queue.async {
                completion(data, downloadError)
            }
        }
        return task
    }
    
    /// Cancels a download for a given objectID if it exists
    /// - Parameters:
    ///   - objectID: ObjectID of Blob
    public func cancelDownload(for objectID: NSManagedObjectID) {
        guard let task = activeTasks[objectID] else {
            return
        }
        
        task.cancel()
        activeTasks.removeValue(forKey: objectID)
        progressObservers.removeValue(forKey: objectID)
    }
}
