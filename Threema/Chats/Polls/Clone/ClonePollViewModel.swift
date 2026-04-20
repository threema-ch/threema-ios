import ThreemaFramework
import ThreemaMacros

@MainActor
final class ClonePollViewModel: ObservableObject {
    
    // MARK: - State

    @Published var isLoading = false
    @Published var pollIDs: [NSManagedObjectID] = []
    
    // MARK: - Private properties
    
    private lazy var entityManager = BusinessInjector.ui.entityManager
    private lazy var manager = BallotManager(entityManager: entityManager)
    
    // MARK: - Public functions

    func load() async {
        defer {
            isLoading = false
        }
        
        isLoading = true
        pollIDs = await manager.getPollIDs()
    }
    
    func load(for id: NSManagedObjectID) -> Poll? {
        manager.getPoll(for: id)
    }
}
