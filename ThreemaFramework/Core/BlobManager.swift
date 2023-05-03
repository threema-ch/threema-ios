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

// MARK: - BlobManagerDelegate

protocol BlobManagerDelegate: AnyObject {
    func updateProgress(for objectID: NSManagedObjectID, didUpdate progress: Progress) async
}

/// Central manager creating, coordinating and observing blob up- & downloads of BlobData asynchronously
public actor BlobManager: BlobManagerProtocol {
    
    /// Shared `BlobManager`, always use this, except for testing.
    /// To see its default values, look at the `init()` below.
    public static let shared = BlobManager()
    
    // MARK: - Private properties

    private static let state = BlobManagerState()
    private static let activeState = BlobManagerActiveState()
    
    private let sessionManager: URLSessionManager
    private let serverConnector: ServerConnectorProtocol
    private let serverInfoProvider: ServerInfoProvider
    private let userSettings: UserSettingsProtocol

    private let blobURL: BlobURL
    private let blobMessageSender: BlobMessageSender
    private let blobDownloader: BlobDownloader
    private let blobUploader: BlobUploader

    private let injectedEntityManager: EntityManager?
    private let injectedGroupManager: GroupManagerProtocol?

    /// The entityManager is implemented like this, because we needed a
    /// possibility to override it for testing.
    /// Further, to solve CoreData context syncing issues, we create a new
    /// one every time we save or fetch something.
    private var entityManager: EntityManager {
        if let entityManager = injectedEntityManager {
            return entityManager
        }
        return EntityManager(withChildContextForBackgroundProcess: true)
    }
    
    private var groupManager: GroupManagerProtocol {
        if let groupManager = injectedGroupManager {
            return groupManager
        }
        return GroupManager(entityManager: entityManager)
    }
    
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
        groupManager: GroupManagerProtocol? = nil,
        sessionManager: URLSessionManager = URLSessionManager.shared,
        serverConnector: ServerConnectorProtocol = ServerConnector.shared(),
        serverInfoProvider: ServerInfoProvider = ServerInfoProviderFactory.makeServerInfoProvider(),
        userSettings: UserSettingsProtocol = UserSettings.shared(),
        blobMessageSender: BlobMessageSender = BlobMessageSender.shared
    ) {
        self.injectedEntityManager = entityManager
        self.injectedGroupManager = groupManager
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
        in conversationObjectID: NSManagedObjectID,
        correlationID: String? = nil,
        webRequestID: String? = nil
    ) async throws {
        
        // Check if we actually have data and if it is smaller than the max file size
        guard let data = item.getData(),
              data.count < kMaxFileSize else {
            NotificationPresenterWrapper.shared.present(
                type: .sendingError,
                subtitle: BundleUtil.localizedString(forKey: "notification_sending_failed_subtitle_size")
            )
            throw BlobManagerError.tooBig
        }
        
        // Create file message
        var fileMessageEntityObjectID: NSManagedObjectID?
        var creationError: Error?
        
        let em = entityManager
        em.performBlockAndWait {
            var messageID: Data?
            var conversation: Conversation!
            // Create message
            em.performSyncBlockAndSafe {
                do {
                    conversation = em.entityFetcher
                        .existingObject(with: conversationObjectID) as? Conversation
                    
                    let origin: BlobOrigin!
                    if conversation.isGroup(), let group = self.groupManager.getGroup(conversation: conversation),
                       group.isNoteGroup {
                        origin = .local
                    }
                    else {
                        origin = .public
                    }
                    
                    let fileMessageEntity = try em.entityCreator.createFileMessageEntity(
                        for: item,
                        in: conversation,
                        with: origin,
                        correlationID: correlationID,
                        webRequestID: webRequestID
                    )
                    messageID = fileMessageEntity.id
                }
                catch {
                    creationError = error
                }
            }
            
            guard let messageID else {
                creationError = BlobManagerError.noID
                return
            }
            
            em.performBlockAndWait {
                // Fetch it again to get a non temporary objectID
                guard let fileMessage = em.entityFetcher
                    .message(with: messageID, conversation: conversation) as? FileMessageEntity else {
                    creationError = BlobManagerError.messageNotFound
                    return
                }
                
                fileMessageEntityObjectID = fileMessage.objectID
            }
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
        var messageID: String?
        
        em.performSyncBlockAndSafe {
            guard let message = em.entityFetcher.existingObject(with: objectID) as? FileMessageProvider,
                  !message.blobIsOutgoing() else {
                return
            }
            messageID = message.blobGetID()?.hexString
            
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
            DDLogNotice("[BlobManager] Auto sync for message with id \(messageID ?? "nil") failed, reason: \(error)")
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
            let em = entityManager
            var messageID: String?
            
            em.performSyncBlockAndSafe {
                guard let message = em.entityFetcher.existingObject(with: objectID) as? FileMessage else {
                    return
                }
                messageID = message.id.hexString
            }
            
            DDLogNotice("[BlobManager] Auto sync for message with id \(messageID ?? "nil") failed, reason: \(error)")
        }
    }
    
    /// Same as `syncBlobs(for:)` but throws an error if there was any
    ///
    /// Used in `syncBlobs(for:)` but exposed for testing
    ///
    /// - Parameter objectID: Object to sync blobs for
    public func syncBlobsThrows(for objectID: NSManagedObjectID) async throws {
        
        // We do not even attempt to sync if blob is for note group or we are not connected
        guard !isForNoteGroup(objectID: objectID) else {
            DDLogNotice("[BlobManager] Tried to sync for note group.")
            return
        }
        
        guard serverConnector.connectionState == .loggedIn else {
            DDLogNotice("[BlobManager] Tried to sync while not connected.")
            return
        }
        
        // We filter out legacy image entities here
        let em = entityManager
        var imageMessageEntity: ImageMessageEntity?
        em.performSyncBlockAndSafe {
            if let message = em.entityFetcher.existingObject(with: objectID) as? ImageMessageEntity {
                message.blobSetError(false)
                message.blobUpdateProgress(0)
                imageMessageEntity = message
            }
        }
        
        if let imageMessageEntity,
           let identityStore = MyIdentityStore.shared(),
           imageMessageEntity.blobGetEncryptionKey() == nil,
           let contact = imageMessageEntity.conversation.contact,
           let blobID = imageMessageEntity.blobGetID() {
            
            let processor = ImageMessageProcessor(
                blobDownloader: blobDownloader,
                serverConnector: serverConnector,
                myIdentityStore: identityStore,
                userSettings: userSettings,
                entityManager: em
            )
            _ = processor.downloadImage(
                imageMessageID: imageMessageEntity.id,
                in: imageMessageEntity.conversation.objectID,
                imageBlobID: blobID,
                origin: imageMessageEntity.blobGetOrigin(),
                imageBlobEncryptionKey: imageMessageEntity.encryptionKey,
                imageBlobNonce: imageMessageEntity.imageNonce,
                senderPublicKey: contact.publicKey,
                maxBytesToDecrypt: Int.max
            )
            return
        }
        
        // Was not legacy image message
        
        try await BlobManager.state.addActiveObjectID(objectID)
        BlobManager.activeState.hasActiveSyncs = true
        
        do {
            try await startSync(for: objectID)
            resetStatesForBlob(with: objectID)
            await BlobManager.state.removeActiveObjectIDAndProgress(for: objectID)
           
            // Update non isolated state tracker
            if !(await BlobManager.state.hasActiveObjectIDs()) {
                BlobManager.activeState.hasActiveSyncs = false
            }
        }
        catch {
            setErrorStateForBlob(with: objectID)
            await BlobManager.state.removeActiveObjectIDAndProgress(for: objectID)
            
            // Update non isolated state tracker
            if !(await BlobManager.state.hasActiveObjectIDs()) {
                BlobManager.activeState.hasActiveSyncs = false
            }
            
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
        
        // Update non isolated state tracker
        if !(await BlobManager.state.hasActiveObjectIDs()) {
            BlobManager.activeState.hasActiveSyncs = false
        }
    }
    
    /// Checks the non isolated state tracker if there are any active blob syncs. Might not return the correct value since it is not handled in actor isolation.
    /// - Returns: `True` if there are probably some active syncs.
    public nonisolated func hasActiveSyncs() -> Bool {
        BlobManager.activeState.hasActiveSyncs
    }
    
    // MARK: - State handling and processing logic
    
    private func startSync(for objectID: NSManagedObjectID) async throws {

        // Safely load data and states concurrently
        var blobDataState: BlobState!
        var thumbnailState: BlobState!
        
        var em = entityManager
        em.performBlockAndWait {
            guard let blobData = em.entityFetcher
                .existingObject(with: objectID) as? BlobData
            else {
                DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
                return
            }
            
            blobDataState = blobData.dataState
            thumbnailState = blobData.thumbnailState
        }
        
        // Differentiate between incoming and outgoing
        if case let .incoming(incomingThumbnailState) = thumbnailState,
           case let .incoming(incomingDataState) = blobDataState {
            // We don't do this in parallel for now to make everything testable
            try await syncIncomingThumbnail(of: objectID, with: incomingThumbnailState)
            try await syncIncomingData(of: objectID, with: incomingDataState)
        }
        else if case let .outgoing(outgoingThumbnailState) = thumbnailState,
                case let .outgoing(outgoingDataState) = blobDataState {
            
            // We directly return if blob is for note group
            guard !isForNoteGroup(objectID: objectID) else {
                DDLogNotice("[BlobManager] Tried to sync for note group.")
                return
            }
            
            // We don't do this in parallel for now to make everything testable
            try await syncOutgoingThumbnail(of: objectID, with: outgoingThumbnailState)
            try await syncOutgoingData(of: objectID, with: outgoingDataState)

            // Upload succeeded, we reset the progress
            em = entityManager
            em.performSyncBlockAndSafe {
                guard let blobData = em.entityFetcher
                    .existingObject(with: objectID) as? BlobData
                else {
                    DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
                    return
                }
                
                blobData.blobUpdateProgress(nil)
            }
            
            // Send the message
            try await blobMessageSender.sendBlobMessage(with: objectID)
        }
        else {
            DDLogError("[BlobManager] Thumbnail and Data have different directions.")
            throw BlobManagerError.stateMismatch
        }
    }
    
    // MARK: Incoming Thumbnail
    
    private func syncIncomingThumbnail(
        of objectID: NSManagedObjectID,
        with state: IncomingBlobState
    ) async throws {
        
        // We return directly if the thumbnail is downloaded and fully processed
        guard state != .processed else {
            return
        }
        
        var blobData: BlobData?
        var encryptionKey: Data?
        var thumbnailID: Data?
        var origin: BlobOrigin?
        
        let em = entityManager
        em.performBlockAndWait {
            guard let bd = em.entityFetcher
                .existingObject(with: objectID) as? BlobData
            else {
                DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
                return
            }
            blobData = bd
            encryptionKey = bd.blobGetEncryptionKey()
            thumbnailID = bd.blobGetThumbnailID()
            origin = bd.blobGetOrigin()
        }
        
        guard let blobData else {
            DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
            return
        }
        
        guard let thumbnailID else {
            DDLogNotice("[BlobManager] There is no thumbnailID available for given blob.")
            return
        }
        
        guard let origin else {
            DDLogNotice("[BlobManager] There is no origin available for given blob.")
            return
        }
                
        switch state {
        case .remote:
            em.performSyncBlockAndSafe {
                // Note: This will also reset the error of the belonging incomingDataState
                blobData.blobSetError(false)
                if blobData.blobGetProgress() == nil {
                    // If not already done, we set the progress to 0.0 to indicate work has started
                    blobData.blobUpdateProgress(0.0)
                }
            }
            
            let thumbnail = try await downloadBlob(
                for: thumbnailID,
                origin: origin,
                objectID: objectID,
                encryptionKey: encryptionKey,
                nonce: ThreemaProtocol.nonce02,
                trackProgress: false
            )
            
            // This is save. Delegate calls will not result in another update of the progress as the
            // objectID is no-more in `activeObjectIDs`.
            em.performSyncBlockAndSafe {
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
        of objectID: NSManagedObjectID,
        with state: IncomingBlobState
    ) async throws {
        
        // We return directly if the data is already downloaded and fully processed
        guard state != .processed else {
            return
        }
        
        var blobData: BlobData?
        var encryptionKey: Data?
        var dataID: Data?
        var origin: BlobOrigin?
        
        let em = entityManager
        em.performBlockAndWait {
            guard let bd = em.entityFetcher
                .existingObject(with: objectID) as? BlobData
            else {
                DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
                return
            }
            
            blobData = bd
            encryptionKey = bd.blobGetEncryptionKey()
            dataID = bd.blobGetID()
            origin = bd.blobGetOrigin()
        }
        
        guard let blobData else {
            DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
            return
        }
        
        guard let dataID else {
            DDLogNotice("[BlobManager] There is no dataID available for given blob.")
            throw BlobManagerError.noID
        }
        
        guard let origin else {
            DDLogNotice("[BlobManager] There is no origin available for given blob.")
            throw BlobManagerError.noOrigin
        }
        
        switch state {
        case .remote:
            em.performSyncBlockAndSafe {
                blobData.blobSetError(false)
                if blobData.blobGetProgress() == nil {
                    // If not already done, we set the progress to 0.0 to indicate work has started
                    blobData.blobUpdateProgress(0.0)
                }
            }
            
            let data = try await downloadBlob(
                for: dataID,
                origin: origin,
                objectID: objectID,
                encryptionKey: encryptionKey,
                nonce: ThreemaProtocol.nonce01,
                trackProgress: true
            )
            
            // This is save. Delegate calls will not result in another update of the progress as the
            // objectID is no-more in `activeObjectIDs`.
            em.performSyncBlockAndSafe {
                blobData.blobSetData(data)
            }
            
            try await markDownloadDone(for: dataID, objectID: objectID, origin: origin)
            
            // Download succeeded, we reset the progress
            em.performSyncBlockAndSafe {
                blobData.blobUpdateProgress(nil)
            }
            
            autoSaveMedia(objectID: objectID)
            
        default:
            DDLogNotice("[BlobManager] Data of blob does not need any action, current state is \(state.description).")
        }
    }
    
    private func downloadBlob(
        for blobID: Data,
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
        
        guard let decryptedData = NaClCrypto.shared().symmetricDecryptData(
            encryptedData,
            withKey: encryptionKey,
            nonce: nonce
        ) else {
            DDLogNotice("[BlobManager] Data of blob could not be decrypted.")
            throw BlobManagerError.cryptographyFailed
        }
        
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
    
    private func autoSaveMedia(objectID: NSManagedObjectID) {
        guard UserSettings.shared().autoSaveMedia else {
            return
        }
    
        Task {
            let em = entityManager
            
            em.performBlockAndWait {
                guard let fetchedMessage = em.entityFetcher.existingObject(with: objectID) as? ThumbnailDisplayMessage
                else {
                    DDLogInfo("[BlobManager] ThumbnailDisplayMessage of media to be autosaved not found.")
                    return
                }
                
                guard fetchedMessage.conversation.conversationCategory != .private else {
                    DDLogInfo("[BlobManager] Skip autosave, because message is from private chat.")
                    return
                }
                
                guard let saveMediaItem = fetchedMessage.createSaveMediaItem(forAutosave: true) else {
                    DDLogInfo("[BlobManager] Getting SaveMediaItem to auto-save failed.")
                    return
                }
                
                AlbumManager.shared.save(saveMediaItem, showNotifications: false)
            }
        }
    }
    
    // MARK: Outgoing Thumbnail
    
    private func syncOutgoingThumbnail(
        of objectID: NSManagedObjectID,
        with state: OutgoingBlobState
    ) async throws {
        
        // We return directly if the thumbnail is already uploaded or there is no thumbnail to upload
        // TODO: (IOS-2861) Check if we failed to generate thumbnail and retry if so
        guard state != .remote, state != .noData(.noThumbnail) else {
            return
        }

        var blobData: BlobData?
        var thumbnailID: Data?
        var thumbnailData: Data?
        var encryptionKey: Data?
        var origin: BlobOrigin?
        
        let em = entityManager
        em.performBlockAndWait {
            guard let bd = em.entityFetcher
                .existingObject(with: objectID) as? BlobData
            else {
                DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
                return
            }
            
            blobData = bd
            thumbnailID = bd.blobGetThumbnailID()
            thumbnailData = bd.blobGetThumbnail()
            encryptionKey = bd.blobGetEncryptionKey()
            origin = bd.blobGetOrigin()
        }
        
        guard let blobData else {
            DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
            return
        }
        
        guard let encryptionKey = encryptionKey else {
            DDLogNotice("[BlobManager] Encryption Key not found.")
            throw BlobManagerError.noEncryptionKey
        }
        
        guard let origin = origin else {
            DDLogNotice("[BlobManager] There is no origin available for given blob.")
            throw BlobManagerError.noOrigin
        }
                       
        switch state {
        case .pendingDownload:
            guard let thumbnailID else {
                throw BlobManagerError.noID
            }

            em.performSyncBlockAndSafe {
                // Note: This will also reset the error of the belonging incomingDataState
                blobData.blobSetError(false)
                if blobData.blobGetProgress() == nil {
                    // If not already done, we set the progress to 0.0 to indicate work has started
                    blobData.blobUpdateProgress(0.0)
                }
            }

            let thumbnail = try await downloadBlob(
                for: thumbnailID,
                origin: origin,
                objectID: objectID,
                encryptionKey: encryptionKey,
                nonce: ThreemaProtocol.nonce02,
                trackProgress: false
            )

            // This is save. Delegate calls will not result in another update of the progress as the
            // objectID is no-more in `activeObjectIDs`.
            em.performSyncBlockAndSafe {
                blobData.blobSetThumbnail?(thumbnail)
            }

            try await markDownloadDone(for: thumbnailID, objectID: objectID, origin: origin)

        case .pendingUpload:
            guard let thumbnailData = thumbnailData else {
                DDLogNotice("[BlobManager] Thumbnail has no data.")
                // We return here to still upload data
                return
            }

            em.performSyncBlockAndSafe {
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
            em.performSyncBlockAndSafe {
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
        of objectID: NSManagedObjectID,
        with state: OutgoingBlobState
    ) async throws {
        
        // If the data was uploaded successfully and we still reach this point, the message sending failed and we try to resend it, and return
        guard state != .remote else {
            return
        }
        
        var blobID: Data?
        var blobData: BlobData?
        var data: Data?
        var encryptionKey: Data?
        var origin: BlobOrigin?
        
        let em = entityManager
        em.performBlockAndWait {
            guard let bd = em.entityFetcher
                .existingObject(with: objectID) as? BlobData
            else {
                DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
                return
            }

            blobID = bd.blobGetID()
            blobData = bd
            data = bd.blobGet()
            encryptionKey = bd.blobGetEncryptionKey()
            origin = bd.blobGetOrigin()
        }
        
        guard let blobData else {
            DDLogError("[BlobManager] Unable to load message as BlobData for object ID: \(objectID)")
            return
        }
        
        guard let encryptionKey = encryptionKey else {
            DDLogNotice("[BlobManager] Encryption Key not found.")
            throw BlobManagerError.noEncryptionKey
        }

        guard let origin = origin else {
            DDLogNotice("[BlobManager] There is no origin available for given blob.")
            throw BlobManagerError.noOrigin
        }
               
        switch state {
        case .pendingDownload:
            guard let blobID else {
                throw BlobManagerError.noID
            }

            em.performSyncBlockAndSafe {
                blobData.blobSetError(false)
                if blobData.blobGetProgress() == nil {
                    // If not already done, we set the progress to 0.0 to indicate work has started
                    blobData.blobUpdateProgress(0.0)
                }
            }

            let data = try await downloadBlob(
                for: blobID,
                origin: origin,
                objectID: objectID,
                encryptionKey: encryptionKey,
                nonce: ThreemaProtocol.nonce01,
                trackProgress: true
            )

            // This is save. Delegate calls will not result in another update of the progress as the
            // objectID is no-more in `activeObjectIDs`.
            em.performSyncBlockAndSafe {
                blobData.blobSetData(data)
            }

            try await markDownloadDone(for: blobID, objectID: objectID, origin: origin)

            // Download succeeded, we reset the progress
            em.performSyncBlockAndSafe {
                blobData.blobUpdateProgress(nil)
            }
        case .pendingUpload:
            guard let data = data else {
                DDLogNotice("[BlobManager] Data has no data.")
                throw BlobManagerError.noData
            }

            // There might have been an issue where the app was terminated while uploading and we need to clean up
            await BlobManager.state.removeProgress(for: objectID)
            
            em.performSyncBlockAndSafe {
                blobData.blobSetError(false)
                if blobData.blobGetProgress() == nil {
                    // If not already done, we set the progress to 0.0 to indicate work has started
                    blobData.blobUpdateProgress(0.0)
                }
            }
        
            // Upload data to get ID
            let dataID = try await uploadBlob(
                for: data,
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
            em.performSyncBlockAndSafe {
                blobData.blobSetDataID(dataID)
            }
        case .noData:
            throw BlobManagerError.noData
        default:
            DDLogNotice("[BlobManager] Blob does not need any action, state is \(state.description).")
        }
    }
    
    private func uploadBlob(
        for data: Data,
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
            guard let blob = em.entityFetcher.existingObject(with: objectID) as? BlobData else {
                DDLogWarn("[BlobManager] Could not set blob error because it was not found.")
                return
            }
            
            blob.blobUpdateProgress(nil)
            blob.blobSetError(true)
        }
    }
    
    private func isForNoteGroup(objectID: NSManagedObjectID) -> Bool {
        
        // We upload anyways if MD is activated
        if serverConnector.isMultiDeviceActivated {
            return false
        }
        
        let em = entityManager
        
        var isNoteGroup = false
        
        em.performSyncBlockAndSafe {
            guard let message = em.entityFetcher.existingObject(with: objectID) as? FileMessageEntity,
                  message.conversation.isGroup(),
                  let group = self.groupManager.getGroup(conversation: message.conversation),
                  group.isNoteGroup else {
                return
            }
            message.sent = true
            message.blobSetError(false)
            message.progress = nil
            message.blobSetDataID(ThreemaProtocol.nonUploadedBlobID)
            
            if message.blobGetThumbnail() != nil {
                message.blobSetThumbnailID(ThreemaProtocol.nonUploadedBlobID)
            }
            
            isNoteGroup = true
        }
        return isNoteGroup
    }
}

// MARK: - BlobManagerDelegate

extension BlobManager: BlobManagerDelegate {
    
    func updateProgress(for objectID: NSManagedObjectID, didUpdate progress: Progress) async {
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
