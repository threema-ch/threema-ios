//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

protocol BlobUploaderProtocol {
    func upload(
        data: Data,
        origin: BlobOrigin,
        setPersistParam: Bool
    ) -> Promise<Data>
}

class BlobUploader: NSObject, BlobUploaderProtocol {
    
    enum BlobUploaderError: Error {
        case uploadFailed(message: String)
        case invalidUploadURL
        case idGenerationFailed
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
    
    // MARK: - Upload
    
    /// Uploads given data and provides progress updates to its delegate
    /// - Parameters:
    ///   - blobData: Data to be uploaded
    ///   - origin: Origin of the Blob
    ///   - objectID: ObjectID used to track progress
    ///   - delegate: Delegate to send progress updates to
    /// - Returns: Received data from server
    @discardableResult
    func upload(
        blobData: Data,
        origin: BlobOrigin,
        setPersistParam: Bool,
        objectID: NSManagedObjectID,
        delegate: BlobManagerDelegate? = nil
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            blobURL.upload(
                origin: origin,
                setPersistParam: setPersistParam,
                completionHandler: { uploadURL, authorization, error in
                
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                
                    guard let uploadURL else {
                        continuation.resume(throwing: BlobUploaderError.invalidUploadURL)
                        return
                    }
                
                    let task = self
                        .upload(for: uploadURL, and: blobData, authorization: authorization) { data, error in
                        
                            // Upload was completed
                            if let error {
                                continuation.resume(throwing: error)
                            }
                            else if let data {
                                // We got data, so we create the ID for it
                                guard let blobIDHex = String(bytes: data, encoding: .ascii),
                                      let blobID = BytesUtility.toBytes(hexString: blobIDHex) else {
                                    continuation.resume(throwing: BlobUploaderError.idGenerationFailed)
                                    return
                                }
                            
                                let id = Data(blobID)
                                continuation.resume(returning: id)
                            }
                            else {
                                continuation.resume(
                                    throwing: BlobUploaderError
                                        .uploadFailed(message: "[BlobUploader] Upload unsuccessful.")
                                )
                            }
                        
                            // Remove completed Task
                            self.progressObservers.removeValue(forKey: objectID)
                            self.activeTasks.removeValue(forKey: objectID)
                        }
                
                    // Add created task to keep track
                    self.activeTasks[objectID] = task
                    let observer = task.progress.observe(\.fractionCompleted) { progress, _ in
                        Task {
                            await delegate?.updateProgress(for: objectID, didUpdate: progress)
                        }
                    }
                    self.progressObservers[objectID] = observer
                }
            )
        }
    }

    func upload(
        data: Data,
        origin: BlobOrigin,
        setPersistParam: Bool
    ) -> Promise<Data> {
        Promise { seal in
            blobURL.upload(
                origin: .local,
                setPersistParam: setPersistParam,
                completionHandler: { uploadURL, authorization, error in
                    if let error {
                        seal.reject(error)
                        return
                    }

                    guard let uploadURL else {
                        seal.reject(BlobUploaderError.invalidUploadURL)
                        return
                    }

                    self.upload(for: uploadURL, and: data, authorization: authorization) { data, error in
                        if let error {
                            seal.reject(error)
                            return
                        }

                        guard let data,
                              let idHex = String(bytes: data, encoding: .ascii),
                              let id = BytesUtility.toBytes(hexString: idHex) else {
                            seal.reject(BlobUploaderError.uploadFailed(message: "[BlobUploader] Upload unsuccessful."))
                            return
                        }

                        seal.fulfill(Data(id))
                    }
                }
            )
        }
    }

    @discardableResult
    private func upload(
        for url: URL,
        and data: Data,
        authorization: String?,
        completion: @escaping (Data?, Error?) -> Void
    ) -> URLSessionDataTask {
        
        let client = HTTPClient(authorization: authorization, sessionManager: urlSessionManager)
        let task = client
            .uploadData(
                url: url,
                data: createUploadData(with: data),
                contentType: .multiPart
            ) { data, response, error in
            
                var uploadError: Error?
            
                if let error {
                    uploadError = error
                }
                else {
                    if response is HTTPURLResponse {
                        if let response = response as? HTTPURLResponse,
                           !(200...299).contains(response.statusCode) {
                            uploadError = BlobUploaderError
                                .uploadFailed(
                                    message: "[BlobUploader] Upload failed with response code: \(response.statusCode)."
                                )
                        }
                    }
                    else {
                        uploadError = BlobUploaderError.uploadFailed(message: "[BlobUploader] Response is missing")
                    }
                }
                self.queue.async {
                    completion(data, uploadError)
                }
            }
        return task
    }
    
    /// Cancels a upload for given objectID if it exists
    /// - Parameters:
    ///   - objectID: ObjectID of blob
    public func cancelUpload(for objectID: NSManagedObjectID) {
        guard let task = activeTasks[objectID] else {
            return
        }
        
        task.cancel()
        activeTasks.removeValue(forKey: objectID)
        progressObservers.removeValue(forKey: objectID)
    }
    
    // MARK: - Helpers
    
    private func createUploadData(with blobData: Data) -> Data {
        let boundary = "---------------------------Boundary_Line"
        
        var data = Data()
        data.append(contentsOf: "--\(boundary)\r\n".utf8)
        data.append(contentsOf: "Content-Disposition: form-data; name=\"blob\"; filename=\"blob.bin\"\r\n".utf8)
        data.append(contentsOf: "Content-Type: application/octet-stream\r\n\r\n".utf8)
        data.append(blobData)
        data.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)
        
        return data
    }
}
