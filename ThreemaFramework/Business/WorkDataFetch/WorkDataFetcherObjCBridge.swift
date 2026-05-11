import Foundation

@objcMembers public final class WorkDataFetcherObjCBridge: NSObject {
    
    private let fetcher: WorkDataFetcherProtocol
    
    override public init() {
        self.fetcher = BusinessInjector.ui.workDataFetcher
    }
    
    public init(entityManager: EntityManager, contactStore: ContactStore) {
        self.fetcher = BusinessInjector(entityManager: entityManager).workDataFetcher
        super.init()
    }
    
    @MainActor
    public func updateWorkData(force: Bool) async throws {
        try await fetcher.checkUpdateWorkData(force: force, forceSendMDM: false)
    }
}
