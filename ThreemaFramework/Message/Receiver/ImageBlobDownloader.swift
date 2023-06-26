//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import SwiftProtobuf

@available(*, deprecated, message: "Extend or port functionalities to `BlobManager` instead of using this class.")
class ImageBlobDownloader {

    private let frameworkInjector: FrameworkInjectorProtocol

    init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    /// Download and decrypt image blob.
    /// - Parameters:
    ///    - blob: Common multi device blob
    ///    - origin: Download blob from local or public endpoint
    /// - Returns: Image blob data or nil if download failed
    func download(_ blob: Common_Blob, origin: BlobOrigin) -> Promise<Data?> {
        Promise { seal in
            let blobURL = BlobURL(
                serverConnector: self.frameworkInjector.serverConnector,
                userSettings: self.frameworkInjector.userSettings
            )
            let downloader = BlobDownloader(blobURL: blobURL)
            downloader.download(blobID: blob.id, origin: origin) { data, error in
                if let error {
                    DDLogError("An error occurred while downloading a blob: \(error.localizedDescription)")
                }

                if let data {
                    if let imageData = NaClCrypto.shared()!.symmetricDecryptData(
                        data,
                        withKey: blob.key,
                        nonce: ThreemaProtocol.nonce01
                    ) {
                        seal.fulfill(imageData)
                        return
                    }

                    DDLogError("Expected downloaded data could be NOT decrypted")
                }
                else {
                    DDLogError("Expected downloaded data is nil")
                }

                seal.fulfill(nil)
            }
        }
    }
}
