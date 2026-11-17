import CocoaLumberjackSwift
import FileUtility
import Foundation

protocol MediaBrowserMediaManagerDelegate: AnyObject {
    /// Called when the fetch request fires due to changes in the database
    /// - Parameters:
    ///   - source: `MediaBrowserMediaManager` the handled the changes
    ///   - objectIDs: All `NSManagedObjectID` in the fetch request
    ///   - reloadIDs: `NSManagedObjectID`'s to be reloaded
    ///   - reconfigureIDs: `NSManagedObjectID`'s to be reconfigured
    func mediaChanged(
        _ source: MediaBrowserMediaManager,
        didUpdateObjectIDs objectIDs: [NSManagedObjectID],
        reloadIDs: [NSManagedObjectID],
        reconfigureIDs: [NSManagedObjectID]
    )
}

/// Source of truth for the media in the browser. Handles everything regarding loading, sharing and deleting of the
/// items.
final class MediaBrowserMediaManager: NSObject, NSFetchedResultsControllerDelegate {

    // MARK: - Types

    /// Registering never keeps a delegate alive
    private struct WeakDelegate {
        weak var delegate: (any MediaBrowserMediaManagerDelegate)?
    }

    // MARK: - Private properties

    private(set) var allObjectIDs: [NSManagedObjectID] = []
    
    private var delegates = [WeakDelegate]()
    private let conversationID: NSManagedObjectID
    private let entityManager: EntityManager
    private let willDeleteMessages: ([NSManagedObjectID]) -> Void
    
    private let filtersInMemory: Bool
    
    /// Messages are only loaded once to be filtered
    private var isMediaBrowserItemCache = [NSManagedObjectID: Bool]()

    /// Used to group the media by month, fetched without loading the messages
    private var messageDates = [NSManagedObjectID: Date]()
    
    // We use `BaseMessageEntity` because we need to fetch `FileMessageEntity`, 'ImageMessageEntity` and
    // `VideoMessageEntity` in one request.
    private let mediaFetchedResultsController: NSFetchedResultsController<BaseMessageEntity>

    // MARK: - Lifecycle

    /// - Parameters:
    ///   - willDeleteMessages: Called before messages are deleted, e.g. so an open chat does not show them anymore
    init(
        conversationID: NSManagedObjectID,
        entityManager: EntityManager,
        willDeleteMessages: @escaping ([NSManagedObjectID]) -> Void
    ) {
        self.conversationID = conversationID
        self.entityManager = entityManager
        self.willDeleteMessages = willDeleteMessages
        self.mediaFetchedResultsController = entityManager.entityFetcher
            .mediaMessagesFetchResultsController(for: conversationID)
        self.filtersInMemory = entityManager.entityFetcher.mediaMessagesRequireInMemoryFiltering
        
        super.init()
        
        mediaFetchedResultsController.delegate = self
        try? mediaFetchedResultsController.performFetch()
        allObjectIDs = mediaBrowserItems(
            of: mediaFetchedResultsController.fetchedObjects?.map(\.objectID) ?? []
        )
        updateMessageDates()
    }

    // MARK: - Delegation
    
    func register(delegate: any MediaBrowserMediaManagerDelegate) {
        delegates.removeAll { $0.delegate == nil || $0.delegate === delegate }
        delegates.append(WeakDelegate(delegate: delegate))
    }
    
    func unregister(delegate: any MediaBrowserMediaManagerDelegate) {
        delegates.removeAll { $0.delegate == nil || $0.delegate === delegate }
    }
    
    // MARK: - Entity fetching
    
    func fileMessageProvider(for objectID: NSManagedObjectID) -> FileMessageProvider? {
        entityManager.performAndWait {
            self.entityManager.entityFetcher.existingObject(with: objectID) as? FileMessageProvider
        }
    }
    
    func fileMessageEntity(for objectID: NSManagedObjectID) -> FileMessageProvider? {
        entityManager.performAndWait {
            self.entityManager.entityFetcher.existingObject(with: objectID) as? FileMessageEntity
        }
    }
    
    func thumbnailDisplayMessage(for objectID: NSManagedObjectID) -> ThumbnailDisplayMessage? {
        entityManager.performAndWait {
            self.entityManager.entityFetcher.existingObject(with: objectID) as? ThumbnailDisplayMessage
        }
    }
    
    // MARK: - Page helpers
    
    func senderName(for objectID: NSManagedObjectID) -> String? {
        
        entityManager.performAndWait {
            let message = self.entityManager.entityFetcher.existingObject(with: objectID) as? BaseMessageEntity
            return message?.localizedSenderName
        }
    }
    
    // MARK: - Actions

    /// Starts downloading the data of the message, the progress is reported as change of the media
    func download(_ objectID: NSManagedObjectID) {
        Task {
            _ = await BlobManager.shared.syncBlobs(for: objectID)
        }
    }

    func cancelDownload(_ objectID: NSManagedObjectID) {
        Task {
            await BlobManager.shared.cancelBlobsSync(for: objectID)
        }
    }
    
    /// Deletes the messages of the given `NSManagedObjectID`'s
    /// - Parameter objectIDs: `NSManagedObjectID`'s to be deleted.
    func deleteMessages(with objectIDs: [NSManagedObjectID]) {
        guard !objectIDs.isEmpty else {
            return
        }

        willDeleteMessages(objectIDs)
        
        entityManager.performAndWaitSave {
            for id in objectIDs {
                guard let message = self.entityManager.entityFetcher.existingObject(with: id) as? BaseMessageEntity else {
                    continue
                }
                
                self.entityManager.entityDestroyer.delete(baseMessage: message)
            }

            // Like deleting in the chat, so it does not show a deleted message as last message
            let conversation = self.entityManager.entityFetcher.existingObject(with: self.conversationID)
            (conversation as? ConversationEntity)?.updateLastDisplayMessage(with: self.entityManager)
        }
    }
    
    /// Prepares sharing media for the passed object IDs and shows a share view using the given source and controller.
    /// - Parameters:
    ///   - objectIDs: `NSManagedObjectID`'s to be shared
    ///   - source: Origin of the `UIActivityViewController`
    ///   - presentationController: Controller to present the `UIActivityViewController` on
    @MainActor
    func shareMessages(
        with objectIDs: [NSManagedObjectID],
        source: UIBarButtonItem,
        presentationController: UIViewController
    ) async {
        let items: [Any] = await entityManager.perform {
            objectIDs.compactMap { id -> UIActivityItemSource? in
                guard let message = self.entityManager.entityFetcher.existingObject(with: id) as? BaseMessageEntity else {
                    return nil
                }
                guard let data = BaseMessageEntityMessageShareContentMapper.mapToContent(
                    from: message,
                    fileUtility: FileUtility.shared
                ) else {
                    return nil
                }
                return UIActivityHelperFactory.makeItemSource(type: .messageActivity(data))
            }
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.modalPresentationStyle = .automatic
        activityVC.popoverPresentationController?.sourceItem = source

        activityVC.completionWithItemsHandler = { _, _, _, error in
            if let error {
                DDLogError("An error has occurred while sharing media: \(error)")
            }

            for item in items {
                if let itemSource = item as? MessageUIActivityItemSource {
                    FileUtility.shared.deleteIfExists(at: itemSource.content.exportURL)
                }
            }
        }

        presentationController.present(activityVC, animated: true)
    }
    
    // MARK: - Dates

    /// Date the media is sorted and grouped by
    func date(for objectID: NSManagedObjectID) -> Date? {
        messageDates[objectID]
    }

    private func updateMessageDates() {
        // Only new media needs a fetch, not e.g. download progress
        guard allObjectIDs.contains(where: { messageDates[$0] == nil }) else {
            return
        }

        messageDates = entityManager.entityFetcher.messageDates(
            matching: mediaFetchedResultsController.fetchRequest.predicate
        )
    }

    // MARK: - Filtering

    private func mediaBrowserItems(of objectIDs: [NSManagedObjectID]) -> [NSManagedObjectID] {
        entityManager.entityFetcher.filterMediaMessages(objectIDs, cache: &isMediaBrowserItemCache)
    }
    
    // MARK: - NSFetchedResultsControllerDelegate

    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChangeContentWith snapshotReference: NSDiffableDataSourceSnapshotReference
    ) {
        let fetchedIDs = snapshotReference.itemIdentifiers.compactMap { $0 as? NSManagedObjectID }
        var reloadIDs = snapshotReference.reloadedItemIdentifiers.compactMap { $0 as? NSManagedObjectID }
        var reconfigureIDs = snapshotReference.reconfiguredItemIdentifiers.compactMap { $0 as? NSManagedObjectID }

        if filtersInMemory {
            // Changed messages might not be shown anymore
            for objectID in reloadIDs + reconfigureIDs {
                isMediaBrowserItemCache[objectID] = nil
            }
            allObjectIDs = mediaBrowserItems(of: fetchedIDs)

            // Diffable data sources must only reload or reconfigure items that are in the snapshot
            let shownIDs = Set(allObjectIDs)
            reloadIDs = reloadIDs.filter { shownIDs.contains($0) }
            reconfigureIDs = reconfigureIDs.filter { shownIDs.contains($0) }
        }
        else {
            allObjectIDs = fetchedIDs
        }
        updateMessageDates()

        for delegate in delegates.compactMap(\.delegate) {
            delegate.mediaChanged(
                self,
                didUpdateObjectIDs: allObjectIDs,
                reloadIDs: reloadIDs,
                reconfigureIDs: reconfigureIDs
            )
        }
    }
}
