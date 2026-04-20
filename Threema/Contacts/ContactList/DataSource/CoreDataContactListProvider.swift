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
    private var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>
    
    // MARK: - Lifecycle
    
    init(
        entityFetcher: EntityFetcher = BusinessInjector.ui.entityManager.entityFetcher,
        fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>,
        entityResolver: @escaping (Entity) -> BusinessEntity?
    ) {
        self.entityFetcher = entityFetcher
        self.entityResolver = entityResolver
        self.fetchedResultsController = fetchedResultsController
        self.snapshotSubject = .init(ContactListSnapshot())
        super.init()
        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()
        
        BusinessInjector.ui
            .settingsStore
            .blacklist
            .publisher
            .sink(receiveValue: { [weak self] _ in
                guard let self else {
                    return
                }
                try? fetchedResultsController.performFetch()
            })
            .store(in: &subscriptions)
        
        UserSettings.shared()
            .publisher(for: \.hideStaleContacts)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                self.fetchedResultsController = fetchedResultsController
                fetchedResultsController.delegate = self
                try? fetchedResultsController.performFetch()
            }
            .store(in: &subscriptions)
    }
    
    deinit {
        subscriptions.removeAll()
    }
 
    // MARK: - Functions
    
    func entity(for id: NSManagedObjectID) -> BusinessEntity? {
        guard let entity = entityFetcher.managedObject(with: id) as? Entity else {
            return nil
        }
        
        return entityResolver(entity)
    }
    
    private func convert(_ snapshot: NSDiffableDataSourceSnapshotReference) -> ContactListSnapshot {
        snapshot as ContactListSnapshot
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference
    ) {
        snapshotSubject.send(convert(snapshot))
    }
}
