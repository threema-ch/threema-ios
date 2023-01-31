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

class TaskExecutionBlobTransaction: TaskExecutionTransaction, Old_BlobUploadDelegate {
    private let (promise, seal) = Promise<[Any]>.pending()

    func uploadShouldCancel() -> Bool {
        false
    }
    
    func uploadDidCancel() {
        seal.reject(TaskExecutionTransactionError.blobUploadFailed)
    }
    
    func uploadProgress(_ progress: NSNumber!) {
        DDLogInfo("Upload in progress \(String(describing: progress))")
    }
    
    func uploadFailed() {
        seal.reject(TaskExecutionTransactionError.blobUploadFailed)
    }
    
    func uploadSucceeded(with blobID: [Any]!) {
        DDLogInfo("Upload succeeded with \(String(describing: blobID))")
        seal.fulfill(blobID)
    }
    
    func uploadBlobs(blobs: [Data]) -> Promise<[Any]> {
        firstly { () -> Guarantee<BlobURL> in
            Guarantee { seal in
                seal(
                    BlobURL(
                        serverConnector: frameworkInjector.serverConnector,
                        userSettings: frameworkInjector.userSettings
                    )
                )
            }
        }
        .then { blobURL -> Promise<[Any]> in
            let blobUploader = Old_BlobUploader(blobURL: blobURL, delegate: self)
            blobUploader.upload(blobs: blobs, origin: .local)

            return self.promise
        }
    }
}
