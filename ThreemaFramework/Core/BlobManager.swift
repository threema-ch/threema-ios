//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

/// Central manager creating, coordinating and observing blob up- & downloads of BlobData asynchronously
public actor BlobManager: BlobManagerProtocol {
    
    /// Shared `BlobManager`, always use this, except for testing.
    /// To see its default values, look at the `init()` below.
    public static let shared = BlobManager()
    
    // MARK: - Private properties

    private static let state = BlobManagerState()
    
    private let sessionManager: URLSessionManager
    private let serverConnector: ServerConnectorProtocol
    private let serverInfoProvider: ServerInfoProvider
    private let userSettings: UserSettingsProtocol

    private let blobURL: BlobURL
    private let blobMessageSender: BlobMessageSender
    private let blobDownloader: BlobDownloader
    private let blobUploader: BlobUploader

    private let injectedEntityManager: EntityManager?
    
    /// The entityManager is implemented like this, because we needed a
    /// possibility to override it for testing.
    /// Further, to solve CoreData context syncing issues, we create a new
    /// one every time we save or fetch something.
    private lazy var entityManager: EntityManager = {
        if let entityManager = injectedEntityManager {
            return entityManager
        }
        return EntityManager(withChildContextForBackgroundProcess: true)
    }()
    
    // MARK: - Lifecycle
    
    /// Initializes a BlobManager, **only** use for testing, otherwise use `BlobManager.shared`
    /// - Parameters:
    ///   - entityManager: EntityManager to be used to fetch and save, default is `EntityManager(withChildContextForBackgroundProcess: true)`
    ///   - sessionManager: URLSessionManager, default is `URLSessionManager.shared`
    ///   - serverConnector: ServerConnector, default is `ServerConnector.shared`
    ///   - serverInfoProvider: ServerInfoProviderFactory, default is `ServerInfoProviderFactory.makeServerInfoProvider()`
    ///   - userSettings: UserSettingsProtocol, default is `UserSettings.shared()`
    ///   - blobMessageSender: BlobMessageSender, default is `BlobMessageSender.shared`
    init(
        entityManager: EntityManager? = nil,
        sessionManager: URLSessionManager = URLSessionManager.shared,
        serverConnector: ServerConnectorProtocol = ServerConnector.shared(),
        serverInfoProvider: ServerInfoProvider = ServerInfoProviderFactory.makeServerInfoProvider(),
        userSettings: UserSettingsProtocol = UserSettings.shared(),
        blobMessageSender: BlobMessageSender = BlobMessageSender.shared
    ) {
        self.injectedEntityManager = entityManager
        self.sessionManager = sessionManager
        self.serverConnector = serverConnector
        self.serverInfoProvider = serverInfoProvider
        self.userSettings = userSettings
        self.blobMessageSender = blobMessageSender

        self.blobURL = BlobURL(
            serverConnector: serverConnector,
            userSettings: userSettings,
            serverInfoProvider: serverInfoProvider
        )
        self.blobDownloader = BlobDownloader(blobURL: blobURL, sessionManager: sessionManager)
        self.blobUploader = BlobUploader(blobURL: blobURL, sessionManager: sessionManager)
    }
    
    // MARK: - Public interface
    
    // MARK: New Message
        
    /// Creates a message for a given URLSenderItem and syncs the blobs of it, and  throws if something goes wrong
    /// - Parameters:
    ///   - item: URLSenderItem
    ///   - conversationID: Conversation where message is sent
    ///   - correlationID: Optional String used to identify blobs that are sent together
    ///   - webRequestID: Optional String used to identify the web request
    public func createMessageAndSyncBlobs(
        for item: URLSenderItem,
        in conversationID: NSManagedObjectID,
        correlationID: String? = nil,
        webRequestID: String? = nil
    ) async throws {
        
        // Check if we actually have data and if it is smaller than the max file size
        guard let data = item.getData(),
              data.count < kMaxFileSize else {
            throw BlobManagerError.tooBig
        }
        
        // Check if we actually have data and if it is smaller than the max file size
        guard let data = item.getData(),
              data.count < kMaxFileSize else {
            throw BlobManagerError.tooBig
        }
        
        // Create file message
        var fileMessageEntityObjectID: NSManagedObjectID?
        var creationError: Error?
        
        let em = entityManager
        em.performBlockAndWait {
            var messageID: Data?
            // Create message
            em.performSyncBlockAndSafe {
                do {
                    let conversation = em.entityFetcher
                        .existingObject(with: conversationID) as! Conversation
                    let fileMessageEntity = try em.entityCreator.createFileMessageEntity(
                        for: item,
                        in: conversation,
                        correlationID: correlationID,
                        webRequestID: webRequestID
                    )
                    messageID = fileMessageEntity.id
                }
                catch {
                    creationError = error
                }
            }
            
            // Fetch it again to get a non temporary objectID
            guard let fileMessage = em.entityFetcher.message(with: messageID) as? FileMessageEntity else {
                creationError = BlobManagerError.messageNotFound
                return
            }
            
            fileMessageEntityObjectID = fileMessage.objectID
        }

        guard let fileMessageObjectID = fileMessageEntityObjectID, creationError == nil else {
            throw creationError!
        }
        
        // Sync blobs
        try await syncBlobsThrows(for: fileMessageObjectID)
    }
    
    // MARK: Existing Message
    
    /// Start up- or download of blobs in passed object, use to start automatic downloads
    /// - Parameter objectID: Object to sync blobs for
    public func autoSyncBlobs(for objectID: NSManagedObjectID) async {
        var shouldSync = false
        
        // We check if the message is of the right type, and if it is incoming since we do not want to automatically send failed messages again
        let em = entityManager
        em.performSyncBlockAndSafe {
            guard let message = em.entityFetcher.existingObject(with: objectID) as? FileMessage,
                  !message.isOwnMessage else {
                return
            }
            switch message.fileMessageType {
            case .image, .sticker, .animatedImage, .animatedSticker, .voice:
                shouldSync = true
            case .video, .file:
                shouldSync = false
            }
        }
        
        guard shouldSync else {
            return
        }
        
        // Then we start the sync
        do {
            try await syncBlobsThrows(for: objectID)
        }
        catch {
            DDLogNotice("[BlobManager] Auto sync failed, reason: \(error)")
        }
    }
    
    /// Start up- or download of blobs in passed object
    /// - Parameter objectID: Object to sync blobs for
    public func syncBlobs(for objectID: NSManagedObjectID) async {
        // This should not need any additional functionality. Add it below to `syncBlobsThrows(for:)` if needed.
        do {
            try await syncBlobsThrows(for: objectID)
        }
        catch {
            DDLogNotice("[BlobManager] Sync failed, reason: \(error)")
        }
    }
    
    /// Same as `syncBlobs(for:)` but throws an error if there was any
    ///
    /// Mostly used for testing
    ///
    /// - Parameter objectID: Object to sync blobs for
    public func syncBlobsThrows(for objectID: NSManagedObjectID) async throws {
        
        // We do not even attempt to sync if we are not connected
        guard serverConnector.connectionState == .loggedIn else {
            DDLogNotice("[BlobManager] Tried to sync while not connected.")
            return
        }
        
        try await BlobManager.state.addActiveObjectID(objectID)

        do {
            try await startSync(for: objectID)
            resetStatesForBlob(with: objectID)
            await BlobManager.state.removeActiveObjectIDAndProgress(for: objectID)
        }
        catch {
            setErrorStateForBlob(with: objectID)
            await BlobManager.state.removeActiveObjectIDAndProgress(for: objectID)
            throw error
        }
    }
    
    /// Cancel any active blob up- or downloads for passed object
    /// Note: This does not cancel thumbnail syncs
    /// - Parameter objectID: Managed object ID of object to cancel blob sync for
    public func cancelBlobsSync(for objectID: NSManagedObjectID) async {
                
        if await BlobManager.state.removeActiveObjectIDAndProgress(for: objectID) {
            blobDownloader.cancelDownload(for: objectID)
            blobUploader.cancelUpload(for: objectID)
            resetStatesForBlob(with: objectID)
        }
    }
    
    // MARK: - State handling and processing logic
    
    private func startSync(for objectID: NSManagedObjectID) async throws {

        // Safely load data and states concurrently
        var blobData: BlobData?
        var blobDataState: BlobState!
        var thumbnailState: BlobState!
        
        let em = entityManager
        em.performBlockAndWait {
            guard let bD = em.entityFetcher
                .existingObject(with: objectID) as? BlobData
            else {
                DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
                return
            }
            
            blobData = bD
            blobDataState = bD.dataState
            thumbnailState = bD.thumbnailState
        }
        
        guard let blobData = blobData else {
            return
        }
        
        // Differentiate between incoming and outgoing
        if case let .incoming(incomingThumbnailState) = thumbnailState,
           case let .incoming(incomingDataState) = blobDataState {
            // We don't do this in parallel for now to make everything testable
            try await syncIncomingThumbnail(for: blobData, of: objectID, with: incomingThumbnailState)
            try await syncIncomingData(for: blobData, of: objectID, with: incomingDataState)
        }
        else if case let .outgoing(outgoingThumbnailState) = thumbnailState,
                case let .outgoing(outgoingDataState) = blobDataState {
            // We don't do this in parallel for now to make everything testable
            try await syncOutgoingThumbnail(for: blobData, of: objectID, with: outgoingThumbnailState)
            try await syncOutgoingData(for: blobData, of: objectID, with: outgoingDataState)
            
            // Upload succeeded, we reset the progress
            entityManager.performSyncBlockAndSafe {
                blobData.blobUpdateProgress(nil)
            }
            
            // Send the message
            await blobMessageSender.sendBlobMessage(with: objectID)
        }
        else {
            DDLogError("[BlobManager] Thumbnail and Data have different directions.")
            throw BlobManagerError.stateMismatch
        }
    }
    
    // MARK: Incoming Thumbnail
    
    private func syncIncomingThumbnail(
        for blobData: BlobData,
        of objectID: NSManagedObjectID,
        with state: IncomingBlobState
    ) async throws {
        
        // We return directly if the thumbnail is downloaded and fully processed
        guard state != .processed else {
            return
        }
        
        var encryptionKey: Data?
        var thumbnailID: Data?
        var origin: BlobOrigin?
        
        entityManager.performBlockAndWait {
            encryptionKey = blobData.blobGetEncryptionKey()
            thumbnailID = blobData.blobGetThumbnailID()
            origin = blobData.blobGetOrigin()
        }
        
        guard let thumbnailID = thumbnailID else {
            DDLogNotice("[BlobManager] There is no thumbnailID available for given blob.")
            return
        }
        
        guard let origin = origin else {
            DDLogNotice("[BlobManager] There is no origin available for given blob.")
            return
        }
                
        switch state {
        case .remote:
            entityManager.performSyncBlockAndSafe {
                // Note: This will also reset the error of the belonging incomingDataState
                blobData.blobSetError(false)
                if blobData.blobGetProgress() == nil {
                    // If not already done, we set the progress to 0.0 to indicate work has started
                    blobData.blobUpdateProgress(0.0)
                }
            }
            
            let thumbnail = try await downloadBlob(
                for: thumbnailID,
                of: blobData,
                origin: origin,
                objectID: objectID,
                encryptionKey: encryptionKey,
                nonce: ThreemaProtocol.nonce02,
                trackProgress: false
            )
            
            // This is save. Delegate calls will not result in another update of the progress as the
            // objectID is no-more in `activeObjectIDs`.
            entityManager.performSyncBlockAndSafe {
                blobData.blobSetThumbnail?(thumbnail)
            }
            
            try await markDownloadDone(for: thumbnailID, objectID: objectID, origin: origin)
            
        default:
            DDLogNotice(
                "[BlobManager] Blob does not need any action, current state is \(state.description)."
            )
        }
    }

    // MARK: Incoming Data
    
    private func syncIncomingData(
        for blobData: BlobData,
        of objectID: NSManagedObjectID,
        with state: IncomingBlobState
    ) async throws {
        
        // We return directly if the data is already downloaded and fully processed
        guard state != .processed else {
            return
        }
        
        var encryptionKey: Data?
        var dataID: Data?
        var origin: BlobOrigin?
        
        entityManager.performBlockAndWait {
            encryptionKey = blobData.blobGetEncryptionKey()
            dataID = blobData.blobGetID()
            origin = blobData.blobGetOrigin()
        }
        
        guard let dataID = dataID else {
            DDLogNotice("[BlobManager] There is no dataID available for given blob.")
            throw BlobManagerError.noID
        }
        
        guard let origin = origin else {
            DDLogNotice("[BlobManager] There is no origin available for given blob.")
            throw BlobManagerError.noOrigin
        }
        
        switch state {
        case .remote:
            entityManager.performSyncBlockAndSafe {
                blobData.blobSetError(false)
                if blobData.blobGetProgress() == nil {
                    // If not already done, we set the progress to 0.0 to indicate work has started
                    blobData.blobUpdateProgress(0.0)
                }
            }
            
            let data = try await downloadBlob(
                for: dataID,
                of: blobData,
                origin: origin,
                objectID: objectID,
                encryptionKey: encryptionKey,
                nonce: ThreemaProtocol.nonce01,
                trackProgress: true
            )
            
            // This is save. Delegate calls will not result in another update of the progress as the
            // objectID is no-more in `activeObjectIDs`.
            entityManager.performSyncBlockAndSafe {
                blobData.blobSetData(data)
            }
            
            try await markDownloadDone(for: dataID, objectID: objectID, origin: origin)
            
            // Download succeeded, we reset the progress
            entityManager.performSyncBlockAndSafe {
                blobData.blobUpdateProgress(nil)
            }
            
        default:
            DDLogNotice("[BlobManager] Data of blob does not need any action, current state is \(state.description).")
        }
    }
    
    private func downloadBlob(
        for blobID: Data,
        of blobData: BlobData,
        origin: BlobOrigin,
        objectID: NSManagedObjectID,
        encryptionKey: Data?,
        nonce: Data,
        trackProgress: Bool
    ) async throws -> Data {
               
        // Tracking
        if trackProgress {
            await BlobManager.state.setProgress(for: objectID, to: 0.0)
        }
        
        // Download, Decrypt & Save
        let encryptedData = try await blobDownloader.download(
            blobID: blobID,
            origin: origin,
            objectID: objectID,
            delegate: self
        )
        let decryptedData: Data! = NaClCrypto.shared().symmetricDecryptData(
            encryptedData,
            withKey: encryptionKey,
            nonce: nonce
        )
        
        return decryptedData
    }
    
    private func markDownloadDone(for blobID: Data, objectID: NSManagedObjectID, origin: BlobOrigin) async throws {
        
        var isGroupMessage: Bool?
        
        let em = entityManager
        em.performSyncBlockAndSafe {
            guard let fetchedMessage = em.entityFetcher.existingObject(with: objectID) as? BaseMessage
            else {
                return
            }
            isGroupMessage = fetchedMessage.isGroupMessage
        }
        
        guard let isGroupMessage = isGroupMessage, !isGroupMessage else {
            DDLogInfo("[BlobManager] Do not mark downloads done for group messages")
            return
        }
        
        guard let url = try await blobURL.done(blobID: blobID, origin: origin) else {
            throw BlobManagerError.markDoneFailed
        }
        
        let client = HTTPClient(sessionManager: sessionManager)
        try await client.sendDone(url: url)
    }
    
    // MARK: Outgoing Thumbnail
    
    private func syncOutgoingThumbnail(
        for blobData: BlobData,
        of objectID: NSManagedObjectID,
        with state: OutgoingBlobState
    ) async throws {
        
        // We return directly if the thumbnail is already uploaded or there is no thumbnail to upload
        // TODO: (IOS-2861) Check if we failed to generate thumbnail and retry if so
        guard state != .remote, state != .noData(.noThumbnail) else {
            return
        }
        
        var thumbnailData: Data?
        var encryptionKey: Data?
        var origin: BlobOrigin?
        
        entityManager.performBlockAndWait {
            thumbnailData = blobData.blobGetThumbnail()
            encryptionKey = blobData.blobGetEncryptionKey()
            origin = blobData.blobGetOrigin()
        }
        
        guard let encryptionKey = encryptionKey else {
            DDLogNotice("[BlobManager] Encryption Key not found.")
            throw BlobManagerError.noEncryptionKey
        }
        
        guard let thumbnailData = thumbnailData else {
            DDLogNotice("[BlobManager] Thumbnail has no data.")
            // We return here to still upload data
            return
        }
        
        guard let origin = origin else {
            DDLogNotice("[BlobManager] There is no origin available for given blob.")
            throw BlobManagerError.noOrigin
        }
                       
        switch state {
        case .pendingUpload:
            entityManager.performSyncBlockAndSafe {
                // Note: This will also reset the error of the belonging outgoingDataState
                blobData.blobSetError(false)
                if blobData.blobGetProgress() == nil {
                    // If not already done, we set the progress to 0.0 to indicate work has started
                    blobData.blobUpdateProgress(0.0)
                }
            }
            
            // Upload data to get ID
            let thumbnailID = try await uploadBlob(
                for: thumbnailData,
                of: blobData,
                origin: origin,
                objectID: objectID,
                encryptionKey: encryptionKey,
                nonce: ThreemaProtocol.nonce02,
                trackProgress: false
            )
            
            guard let thumbnailID = thumbnailID else {
                throw BlobManagerError.noID
            }

            // Assign ID to message & save
            entityManager.performSyncBlockAndSafe {
                blobData.blobSetThumbnailID?(thumbnailID)
            }
            
        case .noData:
            // The local thumbnail data is missing and we can't upload anything
            // TODO: (IOS-2861) Generate thumbnail if it is missing
            return
            
        default:
            DDLogNotice("[BlobManager] Blob does not need any action, state is \(state.description).")
        }
    }
    
    // MARK: Outgoing Data

    private func syncOutgoingData(
        for blobData: BlobData,
        of objectID: NSManagedObjectID,
        with state: OutgoingBlobState
    ) async throws {
        
        // We return directly if the data is already uploaded
        guard state != .remote else {
            return
        }
        
        var data: Data?
        var encryptionKey: Data?
        var origin: BlobOrigin?
        
        entityManager.performBlockAndWait {
            data = blobData.blobGet()
            encryptionKey = blobData.blobGetEncryptionKey()
            origin = blobData.blobGetOrigin()
        }
        
        guard let encryptionKey = encryptionKey else {
            DDLogNotice("[BlobManager] Encryption Key not found.")
            throw BlobManagerError.noEncryptionKey
        }
        
        guard let data = data else {
            DDLogNotice("[BlobManager] Data has no data.")
            throw BlobManagerError.noData
        }
        
        guard let origin = origin else {
            DDLogNotice("[BlobManager] There is no origin available for given blob.")
            throw BlobManagerError.noOrigin
        }
               
        switch state {
        case .pendingUpload:
            
            // There might have been an issue where the app was terminated while uploading and we need to clean up
            await BlobManager.state.removeProgress(for: objectID)
            
            entityManager.performSyncBlockAndSafe {
                blobData.blobSetError(false)
                if blobData.blobGetProgress() == nil {
                    // If not already done, we set the progress to 0.0 to indicate work has started
                    blobData.blobUpdateProgress(0.0)
                }
            }
        
            // Upload data to get ID
            let dataID = try await uploadBlob(
                for: data,
                of: blobData,
                origin: origin,
                objectID: objectID,
                encryptionKey: encryptionKey,
                nonce: ThreemaProtocol.nonce01,
                trackProgress: true
            )
            
            guard let dataID = dataID else {
                throw BlobManagerError.noID
            }
            
            // Assign ID to message & save
            entityManager.performSyncBlockAndSafe {
                blobData.blobSetDataID(dataID)
            }
            
        default:
            DDLogNotice("[BlobManager] Blob does not need any action, state is \(state.description).")
        }
    }
    
    private func uploadBlob(
        for data: Data,
        of blobData: BlobData,
        origin: BlobOrigin,
        objectID: NSManagedObjectID,
        encryptionKey: Data?,
        nonce: Data,
        trackProgress: Bool
    ) async throws -> Data? {
        
        // Encrypt
        guard let encryptedData = NaClCrypto.shared().symmetricEncryptData(
            data,
            withKey: encryptionKey,
            nonce: nonce
        ) else {
            throw BlobManagerError.cryptographyFailed
        }
        
        // Tracking
        if trackProgress {
            await BlobManager.state.setProgress(for: objectID, to: 0.0)
        }
        
        // Upload & get returned ID
        let data = try await blobUploader.upload(
            blobData: encryptedData,
            origin: origin,
            objectID: objectID,
            delegate: self
        )
        
        return data
    }
    
    // MARK: - Helpers
    
    // Reset BlobData values, to reflect state
    private func resetStatesForBlob(with objectID: NSManagedObjectID) {
        
        let em = entityManager
        em.performSyncBlockAndSafe {
            guard let blob = em.entityFetcher
                .existingObject(with: objectID) as? BlobData
            else {
                DDLogWarn("[BlobManager] Could not reset blob progress and error because it was not found.")
                return
            }
            
            if blob.blobGetProgress() != nil {
                blob.blobUpdateProgress(nil)
            }
            
            if blob.blobGetError() {
                blob.blobSetError(false)
            }
        }
    }
    
    private func setErrorStateForBlob(with objectID: NSManagedObjectID) {
        // Reset BlobData values, to reflect state
        let em = entityManager
        em.performSyncBlockAndSafe {
            guard let blob = em.entityFetcher
                .existingObject(with: objectID) as? BlobData
            else {
                DDLogWarn("[BlobManager] Could not set blob error because it was not found.")
                return
            }
            
            blob.blobUpdateProgress(nil)
            blob.blobSetError(true)
        }
    }
}

// MARK: - BlobDownloaderDelegate

extension BlobManager: BlobDownloaderDelegate {
    
    func blobDownloader(for objectID: NSManagedObjectID, didUpdate progress: Progress) async {
        guard await BlobManager.state.isActive(objectID),
              let lastProgress = await BlobManager.state.progress(for: objectID)
        else {
            return
        }
        
        // We artificially limit the saving of the progress to at least every 1% to reduce the amount of snapshots
        // applied in the chat view
        let newProgress = Double((100 * progress.fractionCompleted).rounded(.up) / 100)
        guard abs(lastProgress - newProgress) >= 0.01 else {
            return
        }
        
        await BlobManager.state.setProgress(for: objectID, to: newProgress)
        let em = entityManager
        em.performSyncBlockAndSafe {
            guard let blobData = em.entityFetcher.existingObject(with: objectID) as? BlobData else {
                return
            }

            blobData.blobUpdateProgress(NSNumber(value: progress.fractionCompleted))
        }
    }
}

// MARK: - BlobUploaderDelegate

extension BlobManager: BlobUploaderDelegate {
    
    func blobUploader(for objectID: NSManagedObjectID, didUpdate progress: Progress) async {
        guard await BlobManager.state.isActive(objectID),
              let lastProgress = await BlobManager.state.progress(for: objectID)
        else {
            return
        }
        
        // We artificially limit the saving of the progress to at least every 1% to reduce the amount of snapshots
        // applied in the chat view
        let newProgress = Double((100 * progress.fractionCompleted).rounded(.up) / 100)
        guard abs(lastProgress - newProgress) >= 0.01 else {
            return
        }
        
        await BlobManager.state.setProgress(for: objectID, to: newProgress)
        let em = entityManager
        em.performSyncBlockAndSafe {
            guard let blobData = em.entityFetcher.existingObject(with: objectID) as? BlobData else {
                return
            }
            blobData.blobUpdateProgress(NSNumber(value: progress.fractionCompleted))
        }
    }
}
