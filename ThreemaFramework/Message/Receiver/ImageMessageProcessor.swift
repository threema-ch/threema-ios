import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaEssentials

@objc final class ImageMessageProcessor: NSObject {
    
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
                else if let imageBlobNonce, let senderPublicKey {
                    imageData = self.myIdentityStore.decryptData(
                        data,
                        withNonce: imageBlobNonce,
                        publicKey: senderPublicKey
                    )
                }
                
                if let imageData, let image = UIImage(data: imageData) {
                    
                    let thumbnailImage = MediaConverter.getThumbnailFor(image)

                    let thumbnailData = thumbnailImage?
                        .jpegData(compressionQuality: CGFloat(kJPEGCompressionQualityLow))
                    
                    var conversationCategory: ConversationEntity.Category?

                    self.entityManager.performAndWaitSave {
                        guard let conversation = self.entityManager.entityFetcher
                            .managedObject(with: conversationManagedObjectID) as? ConversationEntity,
                            let msg = self.entityManager.entityFetcher
                            .message(with: imageMessageID, in: conversation) as? ImageMessageEntity else {
                            seal.reject(
                                ImageMessageProcessorError
                                    .messageNotFound(message: "message id: \(imageMessageID.hexString)")
                            )
                            return
                        }
                        conversationCategory = msg.conversation.conversationCategory
                        msg.image = self.entityManager.entityCreator.imageDataEntity(
                            data: imageData,
                            size: image.size,
                            message: msg
                        )

                        if let thumbnailData, let width = thumbnailImage?.size.width,
                           let height = thumbnailImage?.size.height {
                            let thumbnail = self.entityManager.entityCreator.imageDataEntity(
                                data: thumbnailData,
                                size: CGSize(width: width, height: height),
                                message: msg
                            )
                            
                            msg.thumbnail = thumbnail
                        }
                        
                        // Mark blob as done, if is group message and Multi Device is activated then always on `local`
                        // origin
                        if !msg.isGroupMessage,
                           let id = msg.imageBlobID {
                            self.blobDownloader.markDownloadDone(for: id, origin: msg.blobOrigin)
                        }
                        else if let id = msg.imageBlobID,
                                self.userSettings.enableMultiDevice {
                            self.blobDownloader.markDownloadDone(for: id, origin: .local)
                        }

                        seal.fulfill_()
                    }

                    // Add to photo library
                    if self.userSettings.autoSaveMedia,
                       let conversationCategory, conversationCategory != .private {
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
