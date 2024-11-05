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
        in conversationManagedObjectID: NSManagedObjectID,
        imageBlobID: Data,
        origin: BlobOrigin,
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
                    in: conversationManagedObjectID,
                    imageBlobID: imageBlobID,
                    origin: origin,
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
                in: conversationManagedObjectID,
                imageBlobID: imageBlobID,
                origin: origin,
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
        in conversationManagedObjectID: NSManagedObjectID,
        imageBlobID: Data,
        origin: BlobOrigin,
        imageBlobEncryptionKey: Data?,
        imageBlobNonce: Data?,
        senderPublicKey: Data?,
        maxBytesToDecrypt: Int
    ) -> Promise<Void> {
        Promise { seal in
            blobDownloader.download(blobID: imageBlobID, origin: origin) { data, error in
                if let error {
                    seal.reject(
                        ImageMessageProcessorError
                            .downloadFailed(message: "Download image failed with error: \(error)")
                    )
                    return
                }
                
                guard let data else {
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
                if let imageBlobEncryptionKey {
                    imageData = NaClCrypto.shared()!.symmetricDecryptData(
                        data,
                        withKey: imageBlobEncryptionKey,
                        nonce: ThreemaProtocol.nonce01
                    )
                }
                else if let imageBlobNonce {
                    imageData = self.myIdentityStore.decryptData(
                        data,
                        withNonce: imageBlobNonce,
                        publicKey: senderPublicKey
                    )
                }
                
                if let imageData {
                    let image = UIImage(data: imageData)
                    var thumbnailImage: UIImage?
                    if let image {
                        thumbnailImage = MediaConverter.getThumbnailFor(image)
                    }
                    
                    let thumbnailData = thumbnailImage?
                        .jpegData(compressionQuality: CGFloat(kJPEGCompressionQualityLow))
                    
                    var message: BaseMessage?
                    
                    self.entityManager.performAndWaitSave {
                        guard let conversation = self.entityManager.entityFetcher
                            .getManagedObject(by: conversationManagedObjectID) as? ConversationEntity,
                            let msg = self.entityManager.entityFetcher
                            .message(with: imageMessageID, conversation: conversation) as? ImageMessageEntity else {
                            seal.reject(
                                ImageMessageProcessorError
                                    .messageNotFound(message: "message id: \(imageMessageID.hexString)")
                            )
                            return
                        }
                        message = msg
                        msg.blobData = imageData

                        if let thumbnailData, let thumbnail = self.entityManager.entityCreator.imageDataEntity() {
                            thumbnail.data = thumbnailData
                            if let width = thumbnailImage?.size.width {
                                thumbnail.width = Int16(width)
                            }
                            if let height = thumbnailImage?.size.height {
                                thumbnail.height = Int16(height)
                            }
                            
                            msg.thumbnail = thumbnail
                        }
                        
                        // Mark blob as done, if is group message and Multi Device is activated then always on `local`
                        // origin
                        if !msg.isGroupMessage,
                           // swiftformat:disable:next acronyms
                           let id = msg.imageBlobId {
                            self.blobDownloader.markDownloadDone(for: id, origin: msg.blobOrigin)
                        }
                        // swiftformat:disable:next acronyms
                        else if let id = msg.imageBlobId,
                                self.userSettings.enableMultiDevice {
                            self.blobDownloader.markDownloadDone(for: id, origin: .local)
                        }

                        seal.fulfill_()
                    }

                    // Add to photo library
                    if let image, self.userSettings.autoSaveMedia,
                       let message,
                       message.conversation.conversationCategory != .private {
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
