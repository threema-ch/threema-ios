import CocoaLumberjackSwift
import Combine
import Foundation

class CoreDataContactListProvider<Entity: NSObject, BusinessEntity: NSObject>: NSObject,
    ContactListDataSourceProviderProtocol,
    NSFetchedResultsControllerDelegate {
    
    typealias ID = NSManagedObjectID

    // MARK: - Properties
    
    var currentSnapshot: AnyPublisher<ContactListSnapshot, Never> { snapshotSubject.eraseToAnyPublisher() }
    private var snapshotSubject: CurrentValueSubject<ContactListSnapshot, Never>
    private var subscriptions: Set<AnyCancellable> = .init()
    private let entityResolver: (Entity) -> BusinessEntity?
    private let entityFetcher: EntityFetcher
    private let makeFetchedResultsController: () -> NSFetchedResultsController<NSFetchRequestResult>
    private var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>
    
    // MARK: - Lifecycle
    
    init(
        entityFetcher: EntityFetcher = BusinessInjector.ui.entityManager.entityFetcher,
        userSettings: UserSettings = UserSettings.shared(),
        fetchedResultsController makeFetchedResultsController: @escaping () -> NSFetchedResultsController<
            NSFetchRequestResult
        >,
        entityResolver: @escaping (Entity) -> BusinessEntity?
    ) {
        self.entityFetcher = entityFetcher
        self.entityResolver = entityResolver
        self.makeFetchedResultsController = makeFetchedResultsController
        self.fetchedResultsController = makeFetchedResultsController()
        self.snapshotSubject = .init(ContactListSnapshot())
        super.init()
        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()

        Publishers.Merge(
            userSettings.publisher(for: \.hideStaleContacts).dropFirst().map { _ in () },
            userSettings.publisher(for: \.sortOrderFirstName).dropFirst().map { _ in () }
        )
        // KVO delivers on the thread of the setter while holding the subscription's lock. `UserSettings` is also
        // written off main (e.g. MDM applied by the work data fetch), and the snapshot ends up in a synchronous
        // `UITableViewDiffableDataSource.apply(_:)`, which waits for main. With the main thread writing the same
        // setting at that time (e.g. MDM applied after the license check) both threads deadlock.
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
            self?.recreateFetchedResultsController()
        }
        .store(in: &subscriptions)
    }
    
    deinit {
        subscriptions.removeAll()
    }
 
    // MARK: - Functions
    
    func entity(for id: NSManagedObjectID) -> BusinessEntity? {
        guard let entity = entityFetcher.existingObject(with: id) as? Entity else {
            DDLogNotice("[ContactList] No entity for object ID (deleted or stale): \(id)")
            return nil
        }

        return entityResolver(entity)
    }
    
    private func convert(_ snapshot: NSDiffableDataSourceSnapshotReference) -> ContactListSnapshot {
        snapshot as ContactListSnapshot
    }

    private func recreateFetchedResultsController() {
        let controller = makeFetchedResultsController()
        controller.delegate = self
        fetchedResultsController = controller

        try? controller.performFetch()

        // `performFetch()` does not call the delegate, thus the new content is published here
        snapshotSubject.send(snapshot(of: controller))
    }

    private func snapshot(of controller: NSFetchedResultsController<NSFetchRequestResult>) -> ContactListSnapshot {
        var snapshot = ContactListSnapshot()

        for section in controller.sections ?? [] {
            snapshot.appendSections([section.name])

            let objectIDs = (section.objects as? [NSManagedObject] ?? []).map(\.objectID)
            snapshot.appendItems(objectIDs, toSection: section.name)
        }

        return snapshot
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference
    ) {
        // Break the synchronous chain at the CoreData delegate boundary. Without this hop,
        // the save (and the chain of contact operations above it) cannot unwind before the
        // table view reload runs, which queries UILocalizedIndexedCollation and deadlocks.
        let converted = convert(snapshot)
        DispatchQueue.main.async { [weak self] in
            self?.snapshotSubject.send(converted)
        }
    }
}
