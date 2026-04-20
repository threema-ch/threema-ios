public final class OrphanedFilesManager: OrphanedFilesManagerProtocol {
    private let entityDestroyer: EntityDestroyer

    public init(entityDestroyer: EntityDestroyer) {
        self.entityDestroyer = entityDestroyer
    }

    public func getOrphanedFilesData() -> (orphaned: [String], totalCount: Int) {
        let (files, count) = entityDestroyer.orphanedExternalFiles(appGroupID: AppGroup.groupID())
        return (files, count)
    }
}
