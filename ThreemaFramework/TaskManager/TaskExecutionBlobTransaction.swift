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

class TaskExecutionBlobTransaction: TaskExecutionTransaction {

    func uploadBlobs(blobs: [Data]) -> Promise<[Data]> {
        let uploadBlobItems = blobs.compactMap { data in
            UploadBlobItem(blobUploader: frameworkInjector.blobUploader, blobData: data)
        }

        return when(
            fulfilled: uploadBlobItems.compactMap { item in
                item.upload()
            }
        )
        .then { _ -> Promise<[Data]> in
            Promise { seal in seal.fulfill(uploadBlobItems.compactMap(\.blobID)) }
        }
    }

    private class UploadBlobItem {
        private let blobUploader: BlobUploaderProtocol
        let blobData: Data
        var blobID: Data?

        init(blobUploader: BlobUploaderProtocol, blobData: Data) {
            self.blobUploader = blobUploader
            self.blobData = blobData
        }

        func upload() -> Promise<Void> {
            blobUploader.upload(data: blobData, origin: .local)
                .then { blobID in
                    self.blobID = blobID
                    return Promise()
                }
        }
    }
}
