//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

class Old_BlobUploader: NSObject {
    
    private let blobURL: BlobURL
    private let delegate: Old_BlobUploadDelegate
    
    class BlobUploadItem {
        let description: String
        var totalBytesSent: Int64 = 0
        var totalBytesExpectedToSend: Int64 = 0
        var isCanceled = false
        var blobID: Data?

        init(_ taskDescription: String) {
            self.description = taskDescription
        }
    }
    
    private var blobUploadItems: [BlobUploadItem]
    
    private var blobItemIndex = 0
    
    @objc init(blobURL: BlobURL, delegate: Old_BlobUploadDelegate) {
        self.blobURL = blobURL
        self.delegate = delegate
        
        self.blobUploadItems = [BlobUploadItem]()
    }
    
    @objc func upload(blobs: [Data], origin: BlobOrigin) {
        guard !blobs.isEmpty else {
            return
        }
        
        // Start all upload tasks
        for blob in blobs {
            blobUploadItems.append(startUpload(blob, origin: origin))
        }
    }

    /// Cancel all upload tasks.
    @objc func cancel() {
        HTTPClient.invalidateAndCancelSession(for: self)
    }
    
    private func startUpload(_ blob: Data, origin: BlobOrigin) -> BlobUploadItem {
        let boundary = "---------------------------Boundary_Line"
        let contentType = String(format: "multipart/form-data; boundary=%@", boundary)

        var data = Data()
        data.append(contentsOf: String(format: "--%@\r\n", boundary).utf8)
        data.append(contentsOf: "Content-Disposition: form-data; name=\"blob\"; filename=\"blob.bin\"\r\n".utf8)
        data.append(contentsOf: "Content-Type: application/octet-stream\r\n\r\n".utf8)
        data.append(blob)
        data.append(contentsOf: String(format: "\r\n--%@--\r\n", boundary).utf8)
        
        blobItemIndex += 1
        let blobUploadItem = BlobUploadItem(String(blobItemIndex))
        
        blobURL.upload(origin: origin) { uploadURL, authorization, error in
            if uploadURL == nil {
                DDLogError(String(format: "Upload failed with error: %@", error!.localizedDescription))
                self.delegate.uploadFailed()
                return
            }
            
            let client = HTTPClient(authorization: authorization)
            client.uploadDataMultipart(
                taskDescription: blobUploadItem.description,
                url: uploadURL!,
                contentType: contentType,
                data: data,
                delegate: self
            ) { task, data, response, error in
                if let error = error {
                    DDLogError(String(format: "Upload failed with error: %@", error.localizedDescription))
                    self.delegate.uploadFailed()
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    
                    var logMessage = "Upload not succeeded"
                    if let response = response as? HTTPURLResponse {
                        logMessage += " \(response.statusCode)"
                    }
                    DDLogWarn("\(logMessage).")
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                        AuthTokenManager.shared().clearCache()
                    }
                    
                    self.delegate.uploadFailed()
                    return
                }
                            
                if let item = self.blobUploadItems.first(where: { $0.description == task?.taskDescription }),
                   let receivedData = data {
                    
                    if let blobIDHex = String(bytes: receivedData, encoding: .ascii),
                       let blobID = BytesUtility.toBytes(hexString: blobIDHex),
                       blobID.count == ThreemaProtocol.blobIDLength {
                        
                        item.blobID = Data(blobID)
                        
                        if self.blobUploadItems.filter({ $0.blobID == nil }).isEmpty {
                            self.delegate.uploadSucceeded(with: self.blobUploadItems.map { $0.blobID! })
                        }
                    }
                    else {
                        DDLogError("Could not evaluate received blob ID.")
                        self.delegate.uploadFailed()
                    }
                }
                else {
                    DDLogError("No data received for this upload task.")
                    self.delegate.uploadFailed()
                }
            }
        }
                
        return blobUploadItem
    }

    /// Progress of all upload tasks.
    /// - Returns: Progress, represented by a floating-point value between 0.0 and 1.0
    var progressPrecent: Double {
        guard !blobUploadItems.isEmpty else {
            return 0
        }
            
        var sumTotalBytesSent: Double = 0
        var sumTotalBytesExpectedToSend: Double = 0
            
        for item in blobUploadItems {
            sumTotalBytesSent += Double(item.totalBytesSent)
            sumTotalBytesExpectedToSend += Double(item.totalBytesExpectedToSend)
        }
            
        return sumTotalBytesSent / sumTotalBytesExpectedToSend
    }
}

// MARK: - URLSessionTaskDelegate

extension Old_BlobUploader: URLSessionTaskDelegate {

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        if let item = blobUploadItems.first(where: { $0.description == task.taskDescription }) {
            if !delegate.uploadShouldCancel() {
                item.totalBytesSent = totalBytesSent
                item.totalBytesExpectedToSend = totalBytesExpectedToSend
                
                delegate.uploadProgress(NSNumber(value: progressPrecent))
            }
            else {
                task.cancel()
                
                item.isCanceled = true
                if blobUploadItems.filter({ !$0.isCanceled }).isEmpty {
                    delegate.uploadDidCancel()
                }
            }
        }
        else {
            DDLogWarn("No internal data found for this upload task.")
        }
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            DDLogError(String(format: "Upload session invalid with error: %@", error.localizedDescription))
        }

        if !delegate.uploadShouldCancel() {
            delegate.uploadFailed()
        }
        else {
            session.getAllTasks { tasks in
                for task in tasks {
                    if let item = self.blobUploadItems.first(where: { $0.description == task.taskDescription }) {
                        item.isCanceled = true
                    }
                }
                self.delegate.uploadDidCancel()
            }
        }
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        SSLCAHelper.session(session, didReceive: challenge, completion: completionHandler)
    }
}
