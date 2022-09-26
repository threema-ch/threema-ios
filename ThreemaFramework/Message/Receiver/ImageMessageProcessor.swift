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

@objc class ImageMessageProcessor: NSObject {
    
    private let blobDownloader: BlobDownloader
    private let myIdentityStore: MyIdentityStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let entityManager: EntityManager
    
    enum ImageMessageProcessorError: Error {
        case downloadFailed(message: String)
        case messageNotFound(message: String)
    }
    
    @objc required init(
        blobDownloader: BlobDownloader,
        myIdentityStore: MyIdentityStoreProtocol,
        userSettings: UserSettingsProtocol,
        entityManager: EntityManager
    ) {
        
        self.blobDownloader = blobDownloader
        self.myIdentityStore = myIdentityStore
        self.userSettings = userSettings
        self.entityManager = entityManager
    }
    
    @objc func downloadImage(
        imageMessageID: Data,
        imageBlobID: Data,
        imageBlobEncryptionKey: Data?,
        imageBlobNonce: Data?,
        senderPublicKey: Data,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int,
        completion: @escaping (Error?) -> Void
    ) {
        if timeoutDownloadThumbnail > 0 {
            race(
                downloadImage(
                    imageMessageID: imageMessageID,
                    imageBlobID: imageBlobID,
                    imageBlobEncryptionKey: imageBlobEncryptionKey,
                    imageBlobNonce: imageBlobNonce,
                    senderPublicKey: senderPublicKey,
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
            downloadImage(
                imageMessageID: imageMessageID,
                imageBlobID: imageBlobID,
                imageBlobEncryptionKey: imageBlobEncryptionKey,
                imageBlobNonce: imageBlobNonce,
                senderPublicKey: senderPublicKey,
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
    
    func downloadImage(
        imageMessageID: Data,
        imageBlobID: Data,
        imageBlobEncryptionKey: Data?,
        imageBlobNonce: Data?,
        senderPublicKey: Data?,
        maxBytesToDecrypt: Int
    ) -> Promise<Void> {
        Promise { seal in
            blobDownloader.download(blobID: imageBlobID) { data, error in
                if let error = error {
                    seal.reject(
                        ImageMessageProcessorError
                            .downloadFailed(message: "Download image failed with error: \(error)")
                    )
                    return
                }
                
                guard let data = data else {
                    seal.reject(ImageMessageProcessorError.downloadFailed(message: "Download image missing"))
                    return
                }
                
                if maxBytesToDecrypt > 0, data.count > maxBytesToDecrypt {
                    DDLogWarn("Image message (size:\(data.count)) to large to decrypt")
                    seal.fulfill_()
                    return
                }
                        
                // Decrypt blob
                var imageData: Data?
                if let imageBlobEncryptionKey = imageBlobEncryptionKey {
                    // swiftformat:disable:next wrap wrapArguments
                    let nonce = Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]) // kNonce_1
                    imageData = NaClCrypto.shared()!
                        .symmetricDecryptData(data, withKey: imageBlobEncryptionKey, nonce: nonce)
                }
                else if let imageBlobNonce = imageBlobNonce {
                    imageData = self.myIdentityStore.decryptData(
                        data,
                        withNonce: imageBlobNonce,
                        publicKey: senderPublicKey
                    )
                }
                
                if let imageData = imageData {
                    let image = UIImage(data: imageData)
                    var thumbnailImage: UIImage?
                    if let image = image {
                        thumbnailImage = MediaConverter.getThumbnailFor(image)
                    }
                    
                    let thumbnailData = thumbnailImage?
                        .jpegData(compressionQuality: CGFloat(kJPEGCompressionQualityLow))
                    
                    self.entityManager.performSyncBlockAndSafe {
                        guard let msg = self.entityManager.entityFetcher
                            .message(with: imageMessageID) as? ImageMessageEntity else {
                            seal.reject(
                                ImageMessageProcessorError
                                    .messageNotFound(message: "message id: \(imageMessageID.hexString)")
                            )
                            return
                        }

                        msg.blobSetData(imageData)

                        let thumbnail = self.entityManager.entityCreator.imageData()
                        thumbnail?.data = thumbnailData
                        if let width = thumbnailImage?.size.width {
                            thumbnail?.width = NSNumber(value: Float(width))
                        }
                        if let height = thumbnailImage?.size.height {
                            thumbnail?.height = NSNumber(value: Float(height))
                        }
                        
                        msg.thumbnail = thumbnail

                        // Mark blob as done, is not a group message
                        if !msg.conversation.isGroup() {
                            MessageSender.markBlob(asDone: msg.imageBlobID, localOrigin: false)
                        }

                        seal.fulfill_()
                    }

                    // Add to photo library
                    if let image = image, self.userSettings.autoSaveMedia {
                        AlbumManager.shared.save(image: image)
                    }
                }
                else {
                    seal.reject(ImageMessageProcessorError.downloadFailed(message: "Blob decryption failed"))
                }
            }
        }
    }

    private func timeout(seconds: Int) -> Promise<Void> {
        Promise { seal in
            after(seconds: TimeInterval(seconds))
                .done {
                    let error = ImageMessageProcessorError.downloadFailed(message: "Timeout")
                    seal.reject(error)
                }
                .catch { error in
                    seal.reject(error)
                }
        }
    }
}
