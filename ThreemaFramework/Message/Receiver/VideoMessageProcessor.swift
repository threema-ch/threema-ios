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

@objc class VideoMessageProcessor: NSObject {
    
    private let blobDownloader: BlobDownloader
    private let serverConnector: ServerConnectorProtocol
    private let entityManager: EntityManager
    
    enum VideoMessageProcessorError: Error {
        case downloadFailed(message: String)
        case messageNotFound(message: String)
    }
    
    @objc required init(
        blobDownloader: BlobDownloader,
        serverConnector: ServerConnectorProtocol,
        entityManager: EntityManager
    ) {
        self.blobDownloader = blobDownloader
        self.serverConnector = serverConnector
        self.entityManager = entityManager
    }

    @objc func downloadVideoThumbnail(
        videoMessageID: Data,
        thumbnailBlobID: Data,
        origin: BlobOrigin,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int,
        completion: @escaping (Error?) -> Void
    ) {
        if timeoutDownloadThumbnail > 0 {
            race(
                downloadVideoThumbnail(
                    videoMessageID: videoMessageID,
                    origin: origin,
                    thumbnailBlobID: thumbnailBlobID,
                    maxBytesToDecrypt: maxBytesToDecrypt
                ),
                timeout(seconds: timeoutDownloadThumbnail)
            )
            .done(on: .global(), flags: .inheritQoS) {
                completion(nil)
            }
            .catch(on: .global(), flags: .inheritQoS, policy: .allErrors) { error in
                completion(error)
            }
        }
        else {
            downloadVideoThumbnail(
                videoMessageID: videoMessageID,
                origin: origin,
                thumbnailBlobID: thumbnailBlobID,
                maxBytesToDecrypt: maxBytesToDecrypt
            )
            .done(on: .global(), flags: .inheritQoS) {
                completion(nil)
            }
            .catch(on: .global(), flags: .inheritQoS, policy: .allErrors) { error in
                completion(error)
            }
        }
    }
    
    func downloadVideoThumbnail(
        videoMessageID: Data,
        origin: BlobOrigin,
        thumbnailBlobID: Data,
        maxBytesToDecrypt: Int
    ) -> Promise<Void> {
        Promise { seal in
            // Download thumbnail
            self.blobDownloader.download(blobID: thumbnailBlobID, origin: origin) { data, error in
                if let error = error {
                    seal.reject(
                        VideoMessageProcessorError
                            .downloadFailed(message: "Download video thumbnail failed with error: \(error)")
                    )
                    return
                }

                guard let data = data else {
                    seal.reject(VideoMessageProcessorError.downloadFailed(message: "Download video thumbnail missing."))
                    return
                }

                self.entityManager.performSyncBlockAndSafe {
                    guard let msg = self.entityManager.entityFetcher
                        .message(with: videoMessageID) as? VideoMessageEntity
                    else {
                        seal.reject(
                            VideoMessageProcessorError
                                .downloadFailed(message: "message id: \(videoMessageID.hexString)")
                        )
                        return
                    }

                    if maxBytesToDecrypt > 0, data.count > maxBytesToDecrypt {
                        DDLogWarn("Video message (size:\(data.count)) to large to decrypt")
                        seal.fulfill_()
                        return
                    }

                    // Decrypt blob
                    let thumbnailData: Data? = NaClCrypto.shared()!.symmetricDecryptData(
                        data,
                        withKey: msg.encryptionKey,
                        nonce: ThreemaProtocol.nonce02
                    )

                    if let thumbnailData = thumbnailData,
                       let thumbnailImage = UIImage(data: thumbnailData) {
                        let thumbnailJpegData = thumbnailImage.jpegData(compressionQuality: 1.0)

                        let thumbnail: ImageData = msg.thumbnail == nil ? self.entityManager.entityCreator
                            .imageData() : msg.thumbnail
                        thumbnail.data = thumbnailJpegData
                        thumbnail.width = NSNumber(value: Float(thumbnailImage.size.width))
                        thumbnail.height = NSNumber(value: Float(thumbnailImage.size.height))

                        msg.thumbnail = thumbnail

                        // Mark blob as done, if is group message and Multi Device is activated then always on `local` origin
                        if !msg.conversation.isGroup() {
                            MessageSender.markBlobAsDone(blobID: thumbnailBlobID, origin: msg.blobGetOrigin())
                        }
                        else if self.serverConnector.isMultiDeviceActivated {
                            MessageSender.markBlobAsDone(blobID: thumbnailBlobID, origin: .local)
                        }

                        seal.fulfill_()
                    }
                    else {
                        seal.reject(VideoMessageProcessorError.downloadFailed(message: "Blob decryption failed"))
                    }
                }
            }
        }
    }
    
    private func timeout(seconds: Int) -> Promise<Void> {
        Promise { seal in
            after(seconds: TimeInterval(seconds))
                .done {
                    let error = VideoMessageProcessorError.downloadFailed(message: "Timeout")
                    seal.reject(error)
                }
                .catch { error in
                    seal.reject(error)
                }
        }
    }
}
