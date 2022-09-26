//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

class BlobDownloader: NSObject {
    
    private let blobURL: BlobURL
    private let queue: DispatchQueue
    
    enum BlobDownloaderError: Error {
        case downloadFailed(message: String)
    }

    @objc init(blobURL: BlobURL, queue: DispatchQueue = DispatchQueue.main) {
        self.blobURL = blobURL
        self.queue = queue
    }

    func download(blobID: Data) -> Promise<Data?> {
        Promise { seal in
            download(blobID: blobID) { data, error in
                if let error = error {
                    seal.reject(error)
                }
                else {
                    seal.fulfill(data)
                }
            }
        }
    }
 
    @objc func download(blobID: Data, completion: @escaping (Data?, Error?) -> Swift.Void) {
        blobURL.download(blobID: blobID) { downloadURL, error in
            guard let downloadURL = downloadURL else {
                return
            }
            
            let httpClient = HttpClient()
            httpClient.downloadData(url: downloadURL, contentType: .octetStream) { data, response, error in
                var downloadError: Error?
                
                if let error = error {
                    downloadError = error
                }
                else {
                    if response is HTTPURLResponse {
                        if let response = response as? HTTPURLResponse,
                           !(200...299).contains(response.statusCode) {
                            downloadError = BlobDownloaderError
                                .downloadFailed(message: "Response code \(response.statusCode)")
                        }
                    }
                    else {
                        downloadError = BlobDownloaderError.downloadFailed(message: "Response is missing")
                    }
                }
                self.queue.async {
                    completion(data, downloadError)
                }
            }
        }
    }
}
